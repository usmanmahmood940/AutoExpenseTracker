"""`/me` and `/me/devices` — Firebase verification is stubbed via a dependency
override; the Postgres side (profile creation, updates, device rows) is real.
"""

from __future__ import annotations

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient

from app.api import deps
from app.core.firebase import FirebaseIdentity
from app.main import create_app


def _identity(uid: str, email: str) -> FirebaseIdentity:
    return FirebaseIdentity(uid=uid, email=email, email_verified=True, claims={})


def _client_for(uid: str, email: str) -> TestClient:
    app = create_app()
    app.dependency_overrides[deps.get_current_identity] = lambda: _identity(uid, email)
    return TestClient(app)


@pytest.fixture
def me_client() -> Generator[tuple[TestClient, str], None, None]:
    uid = f"uid-{uuid.uuid4().hex[:12]}"
    email = f"{uid}@example.com"
    with _client_for(uid, email) as client:
        yield client, email


def test_me_requires_a_bearer_token(client: TestClient) -> None:
    with client:
        response = client.get("/me")
    assert response.status_code == 401
    assert response.json()["code"] == "token_missing"


def test_get_me_creates_profile_on_first_sight(
    me_client: tuple[TestClient, str],
) -> None:
    client, email = me_client
    response = client.get("/me")

    assert response.status_code == 200
    body = response.json()
    assert body["email"] == email
    assert body["display_name"] == email.split("@")[0]
    assert body["default_currency"] == "PKR"
    assert body["auto_categorize"] is True


def test_patch_me_updates_only_the_given_fields(
    me_client: tuple[TestClient, str],
) -> None:
    client, _ = me_client
    client.get("/me")

    response = client.patch(
        "/me",
        json={
            "display_name": "New Name",
            "default_currency": "usd",
            "auto_categorize": False,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["display_name"] == "New Name"
    assert body["default_currency"] == "USD"
    assert body["auto_categorize"] is False
    assert body["timezone"] == "Asia/Karachi"  # untouched


def test_device_register_and_unregister(me_client: tuple[TestClient, str]) -> None:
    client, _ = me_client
    client.get("/me")
    token = f"token-{uuid.uuid4().hex}"

    register = client.post(
        "/me/devices",
        json={"fcm_token": token, "platform": "android", "app_version": "1.2.3"},
    )
    assert register.status_code == 201
    assert register.json()["platform"] == "android"

    delete = client.delete(f"/me/devices/{token}")
    assert delete.status_code == 204

    # Idempotent: deleting an already-gone token still succeeds.
    delete_again = client.delete(f"/me/devices/{token}")
    assert delete_again.status_code == 204


def test_device_token_moves_to_the_new_account() -> None:
    # Two fully sequential `TestClient`s (not nested): each runs the app on
    # its own portal thread/event loop, and the app's DB engine is a
    # module-level singleton, so an open client from a second one would hand
    # asyncpg a connection bound to the wrong loop.
    token = f"token-{uuid.uuid4().hex}"

    owner_uid = f"uid-{uuid.uuid4().hex[:12]}"
    owner_email = f"{owner_uid}@example.com"
    with _client_for(owner_uid, owner_email) as client:
        client.get("/me")
        register = client.post(
            "/me/devices", json={"fcm_token": token, "platform": "ios"}
        )
        assert register.status_code == 201

    other_uid = f"uid-{uuid.uuid4().hex[:12]}"
    other_email = f"{other_uid}@example.com"
    with _client_for(other_uid, other_email) as other_client:
        other_client.get("/me")
        response = other_client.post(
            "/me/devices", json={"fcm_token": token, "platform": "web"}
        )

    assert response.status_code == 201
    assert response.json()["platform"] == "web"
