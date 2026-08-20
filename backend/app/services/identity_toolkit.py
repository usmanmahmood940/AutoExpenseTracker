"""Server-side password sign-in via the Identity Toolkit REST API.

The Admin SDK can issue and inspect tokens but cannot check a password — this
is the same `accounts:signInWithPassword` endpoint the Firebase client SDKs
call under the hood, invoked here so `/auth/login` and `/auth/change-password`
never need the client to hold a Firebase session.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

from app.core.config import Settings
from app.core.errors import (
    ForbiddenError,
    RateLimitedError,
    ServiceUnavailableError,
    UnauthorizedError,
)

logger = logging.getLogger(__name__)

_SIGN_IN_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"


@dataclass(frozen=True)
class SignInResult:
    uid: str
    id_token: str
    refresh_token: str
    expires_in: int


def _map_error(message: str) -> Exception:
    if message == "USER_DISABLED":
        return ForbiddenError("Account is disabled.", code="user_disabled")
    if message in ("TOO_MANY_ATTEMPTS_TRY_LATER",):
        return RateLimitedError("Too many attempts. Try again later.")
    # EMAIL_NOT_FOUND / INVALID_PASSWORD / INVALID_LOGIN_CREDENTIALS all
    # collapse to one message so login cannot be used to enumerate accounts.
    return UnauthorizedError("Invalid email or password.", code="invalid_credentials")


async def sign_in_with_password(
    settings: Settings, *, email: str, password: str
) -> SignInResult:
    if not settings.firebase_web_api_key:
        raise ServiceUnavailableError(
            "Sign-in is not configured.", code="identity_toolkit_unavailable"
        )

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            _SIGN_IN_URL,
            params={"key": settings.firebase_web_api_key},
            json={"email": email, "password": password, "returnSecureToken": True},
        )

    body = response.json()
    if response.status_code >= 400:
        message = str(body.get("error", {}).get("message", ""))
        logger.info("identity_toolkit_sign_in_rejected", extra={"reason": message})
        raise _map_error(message)

    return SignInResult(
        uid=str(body["localId"]),
        id_token=str(body["idToken"]),
        refresh_token=str(body["refreshToken"]),
        expires_in=int(body["expiresIn"]),
    )
