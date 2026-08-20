"""`/auth/*` end to end, with Firebase Auth / Identity Toolkit stubbed out.

The stub is an in-memory `{email: (uid, password)}` store wired into
`app.services.firebase_users` and `app.services.identity_toolkit`, plus a
matching `firebase.verify_id_token` fake that decodes the stub's own fake ID
tokens. Everything else (OTPs, rate limits, reset sessions, Postgres profiles)
runs for real against the test database.
"""

from __future__ import annotations

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient

from app.core import firebase
from app.core.config import get_settings
from app.core.errors import ConflictError, NotFoundError, UnauthorizedError
from app.core.firebase import FirebaseIdentity
from app.db.models.auth_otp import OtpPurpose
from app.main import create_app
from app.services import firebase_users, identity_toolkit, otp, user_profile
from tests.conftest import run_isolated


class FakeFirebaseBackend:
    """Stands in for both the Admin SDK and the Identity Toolkit REST API."""

    def __init__(self) -> None:
        self.accounts: dict[str, dict[str, str]] = {}
        self.claims: dict[str, dict[str, object]] = {}
        self.revoked: set[str] = set()

    def _uid_for(self, email: str) -> str:
        return f"uid-{abs(hash(email)) % 10**10}"

    async def get_by_email(self, email: str) -> firebase_users.FirebaseUser | None:
        account = self.accounts.get(email)
        if account is None:
            return None
        return firebase_users.FirebaseUser(
            uid=account["uid"], email=email, email_verified=True, disabled=False
        )

    async def create_user(
        self, *, email: str, password: str
    ) -> firebase_users.FirebaseUser:
        if email in self.accounts:
            raise ConflictError("This email is already in use.", code="email_exists")
        uid = self._uid_for(email)
        self.accounts[email] = {"uid": uid, "password": password}
        return firebase_users.FirebaseUser(
            uid=uid, email=email, email_verified=True, disabled=False
        )

    async def set_custom_claims(self, uid: str, claims: dict[str, object]) -> None:
        self.claims[uid] = claims

    async def update_password(self, uid: str, new_password: str) -> None:
        for account in self.accounts.values():
            if account["uid"] == uid:
                account["password"] = new_password
                return
        raise NotFoundError("Account not found.", code="user_not_found")

    async def revoke_refresh_tokens(self, uid: str) -> None:
        self.revoked.add(uid)

    async def sign_in_with_password(
        self, settings: object, *, email: str, password: str
    ) -> identity_toolkit.SignInResult:
        account = self.accounts.get(email)
        if account is None or account["password"] != password:
            raise UnauthorizedError(
                "Invalid email or password.", code="invalid_credentials"
            )
        token = f"{account['uid']}::{email}"
        return identity_toolkit.SignInResult(
            uid=account["uid"],
            id_token=token,
            refresh_token=f"refresh-{token}",
            expires_in=3600,
        )

    def verify_id_token(self, token: str, *, check_revoked: bool) -> FirebaseIdentity:
        uid, email = token.split("::", 1)
        if check_revoked and uid in self.revoked:
            raise UnauthorizedError(
                "Session was revoked. Sign in again.", code="token_revoked"
            )
        return FirebaseIdentity(uid=uid, email=email, email_verified=True, claims={})

    def register(self, email: str, password: str) -> str:
        """Test helper: seed an account without going through `/auth/signup`."""
        uid = self._uid_for(email)
        self.accounts[email] = {"uid": uid, "password": password}
        return uid

    def bearer_for(self, email: str) -> str:
        return f"Bearer {self.accounts[email]['uid']}::{email}"


@pytest.fixture
def auth_client(
    monkeypatch: pytest.MonkeyPatch,
) -> Generator[tuple[TestClient, FakeFirebaseBackend], None, None]:
    backend = FakeFirebaseBackend()
    monkeypatch.setattr(firebase_users, "get_by_email", backend.get_by_email)
    monkeypatch.setattr(firebase_users, "create_user", backend.create_user)
    monkeypatch.setattr(firebase_users, "set_custom_claims", backend.set_custom_claims)
    monkeypatch.setattr(firebase_users, "update_password", backend.update_password)
    monkeypatch.setattr(
        firebase_users, "revoke_refresh_tokens", backend.revoke_refresh_tokens
    )
    monkeypatch.setattr(
        identity_toolkit, "sign_in_with_password", backend.sign_in_with_password
    )
    monkeypatch.setattr(firebase, "verify_id_token", backend.verify_id_token)

    with TestClient(create_app()) as client:
        yield client, backend


def _email() -> str:
    return f"auth-{uuid.uuid4().hex[:12]}@example.com"


def _ip() -> dict[str, str]:
    return {"X-Forwarded-For": f"203.0.113.{uuid.uuid4().int % 250}"}


def _seed_otp(*, email: str, purpose: OtpPurpose) -> str:
    """Issues an OTP outside the app's request cycle, via `run_isolated` — the
    `TestClient` in `auth_client` serves requests on its own portal thread and
    event loop, so this must not touch the app's shared engine/loop."""
    settings = get_settings()
    return run_isolated(
        lambda db: otp.issue_otp(db, settings, email=email, purpose=purpose)
    )


def _seed_profile(*, firebase_uid: str, email: str) -> None:
    """Creates the Postgres row a real `/auth/signup` would already have
    created — needed whenever a test seeds a Firebase-only fake account and
    then exercises a route that looks the profile up (e.g. password reset)."""
    run_isolated(
        lambda db: user_profile.create_profile(
            db,
            firebase_uid=firebase_uid,
            email=email,
            email_verified=True,
            display_name=email.split("@")[0],
        )
    )


# --- signup ---------------------------------------------------------------


def test_start_signup_otp_ok_for_a_new_email(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, _ = auth_client
    response = client.post("/auth/signup/otp", json={"email": _email()}, headers=_ip())
    assert response.status_code == 200
    assert response.json() == {"ok": True}


def test_start_signup_otp_conflicts_for_an_existing_email(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    backend.register(email, "irrelevant")

    response = client.post("/auth/signup/otp", json={"email": email}, headers=_ip())

    assert response.status_code == 409
    assert response.json()["code"] == "email_exists"


def test_start_signup_otp_is_rate_limited_per_email(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, _ = auth_client
    email = _email()
    ip = _ip()

    for _ in range(5):
        ok = client.post("/auth/signup/otp", json={"email": email}, headers=ip)
        assert ok.status_code == 200

    response = client.post("/auth/signup/otp", json={"email": email}, headers=ip)
    assert response.status_code == 429


def test_complete_signup_creates_account_and_returns_tokens(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    code = _seed_otp(email=email, purpose=OtpPurpose.email_verification)

    response = client.post(
        "/auth/signup", json={"email": email, "password": "supersecret", "code": code}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == email
    assert body["tokens"]["id_token"]
    assert body["tokens"]["refresh_token"]
    assert email in backend.accounts
    assert backend.claims[backend.accounts[email]["uid"]] == {"emailOtpVerified": True}


def test_complete_signup_rejects_a_short_password(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, _ = auth_client
    response = client.post(
        "/auth/signup", json={"email": _email(), "password": "short", "code": "000000"}
    )
    assert response.status_code == 400
    assert response.json()["code"] == "password_too_short"


def test_complete_signup_rejects_a_wrong_code(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, _ = auth_client
    email = _email()
    _seed_otp(email=email, purpose=OtpPurpose.email_verification)

    response = client.post(
        "/auth/signup",
        json={"email": email, "password": "supersecret", "code": "000000"},
    )
    assert response.status_code == 400
    assert response.json()["code"] == "otp_invalid"


def test_signup_rejects_a_malformed_email(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, _ = auth_client
    response = client.post("/auth/signup/otp", json={"email": "not-an-email"})
    assert response.status_code == 422


# --- login -----------------------------------------------------------------


def test_login_success_self_heals_the_postgres_profile(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    backend.register(email, "correct-password")

    response = client.post(
        "/auth/login",
        json={"email": email, "password": "correct-password"},
        headers=_ip(),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == email
    assert body["tokens"]["id_token"]


def test_login_rejects_a_wrong_password(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    backend.register(email, "correct-password")

    response = client.post(
        "/auth/login", json={"email": email, "password": "nope"}, headers=_ip()
    )

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


def test_login_is_rate_limited_per_email(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    backend.register(email, "correct-password")
    ip = _ip()

    for _ in range(10):
        client.post(
            "/auth/login", json={"email": email, "password": "nope"}, headers=ip
        )

    response = client.post(
        "/auth/login", json={"email": email, "password": "correct-password"}, headers=ip
    )
    assert response.status_code == 429


# --- forgot / reset password ------------------------------------------------


def test_forgot_password_for_an_unknown_email_still_looks_successful(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, _ = auth_client
    response = client.post(
        "/auth/forgot-password", json={"email": _email()}, headers=_ip()
    )
    assert response.status_code == 200
    assert response.json() == {"ok": True}


def test_full_password_reset_flow(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    uid = backend.register(email, "old-password")
    _seed_profile(firebase_uid=uid, email=email)

    forgot = client.post("/auth/forgot-password", json={"email": email}, headers=_ip())
    assert forgot.status_code == 200

    code = _seed_otp(email=email, purpose=OtpPurpose.password_reset)
    verify = client.post("/auth/verify-reset-otp", json={"email": email, "code": code})
    assert verify.status_code == 200
    reset_token = verify.json()["reset_token"]

    reset = client.post(
        "/auth/reset-password",
        json={"reset_token": reset_token, "new_password": "brand-new-password"},
    )
    assert reset.status_code == 200
    assert backend.accounts[email]["password"] == "brand-new-password"
    assert backend.accounts[email]["uid"] in backend.revoked

    # Single use: the same token cannot reset the password twice.
    reuse = client.post(
        "/auth/reset-password",
        json={"reset_token": reset_token, "new_password": "another-password"},
    )
    assert reuse.status_code == 404


# --- change password / logout ----------------------------------------------


def test_change_password_success(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    backend.register(email, "old-password")

    response = client.post(
        "/auth/change-password",
        json={"old_password": "old-password", "new_password": "new-password-123"},
        headers={"Authorization": backend.bearer_for(email)},
    )

    assert response.status_code == 200
    assert backend.accounts[email]["password"] == "new-password-123"
    assert backend.accounts[email]["uid"] in backend.revoked


def test_change_password_rejects_a_wrong_old_password(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    backend.register(email, "old-password")

    response = client.post(
        "/auth/change-password",
        json={"old_password": "not-it", "new_password": "new-password-123"},
        headers={"Authorization": backend.bearer_for(email)},
    )

    assert response.status_code == 401


def test_logout_revokes_refresh_tokens(
    auth_client: tuple[TestClient, FakeFirebaseBackend],
) -> None:
    client, backend = auth_client
    email = _email()
    uid = backend.register(email, "password123")

    response = client.post(
        "/auth/logout", headers={"Authorization": backend.bearer_for(email)}
    )

    assert response.status_code == 200
    assert uid in backend.revoked
