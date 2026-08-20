"""Firebase Admin SDK lifecycle and ID token verification.

Firebase stays the credential store and token issuer; this backend only verifies
tokens and manages users. Initialization is deliberately non-fatal so the service
still boots (and /health still answers) on a machine with no service account.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials

from app.core.config import Settings
from app.core.errors import ServiceUnavailableError, UnauthorizedError

logger = logging.getLogger(__name__)

_app: firebase_admin.App | None = None
_init_error: str | None = None


@dataclass(frozen=True)
class FirebaseIdentity:
    """The subset of an ID token's claims this backend cares about."""

    uid: str
    email: str | None
    email_verified: bool
    claims: dict[str, Any]


def init_firebase(settings: Settings) -> None:
    global _app, _init_error

    if _app is not None:
        return

    try:
        if settings.google_application_credentials:
            cred = credentials.Certificate(settings.google_application_credentials)
        else:
            # Cloud Run supplies these from the runtime service account.
            cred = credentials.ApplicationDefault()

        options = (
            {"projectId": settings.firebase_project_id}
            if settings.firebase_project_id
            else None
        )
        _app = firebase_admin.initialize_app(cred, options)
        _init_error = None
        logger.info(
            "firebase_initialized",
            extra={"projectId": settings.firebase_project_id or "<from credentials>"},
        )
    except Exception as exc:
        _init_error = str(exc)
        logger.warning(
            "firebase_init_failed",
            extra={
                "error": _init_error,
                "hint": (
                    "set GOOGLE_APPLICATION_CREDENTIALS or run `gcloud auth "
                    "application-default login`; auth routes will return 503 "
                    "until then"
                ),
            },
        )


def shutdown_firebase() -> None:
    global _app, _init_error
    if _app is not None:
        firebase_admin.delete_app(_app)
        _app = None
    _init_error = None


def is_available() -> bool:
    return _app is not None


def init_error() -> str | None:
    return _init_error


def require_app() -> firebase_admin.App:
    """The initialized Admin SDK app, or a 503 if Firebase never configured.

    Public so `app.services.firebase_users` (Phase B) can pass it explicitly to
    SDK calls, the same way `verify_id_token` does below.
    """
    if _app is None:
        raise ServiceUnavailableError(
            "Identity provider is not configured.",
            code="auth_unavailable",
        )
    return _app


def verify_id_token(token: str, *, check_revoked: bool) -> FirebaseIdentity:
    """Verify a Firebase ID token, translating SDK errors into our envelope."""
    app = require_app()
    try:
        claims = firebase_auth.verify_id_token(
            token, app=app, check_revoked=check_revoked
        )
    except firebase_auth.ExpiredIdTokenError as exc:
        raise UnauthorizedError(
            "Session expired. Sign in again.", code="token_expired"
        ) from exc
    except firebase_auth.RevokedIdTokenError as exc:
        raise UnauthorizedError(
            "Session was revoked. Sign in again.", code="token_revoked"
        ) from exc
    except firebase_auth.UserDisabledError as exc:
        raise UnauthorizedError("Account is disabled.", code="user_disabled") from exc
    except (firebase_auth.InvalidIdTokenError, ValueError) as exc:
        raise UnauthorizedError("Invalid token.", code="token_invalid") from exc

    return FirebaseIdentity(
        uid=claims["uid"],
        email=claims.get("email"),
        email_verified=bool(claims.get("email_verified", False)),
        claims=claims,
    )
