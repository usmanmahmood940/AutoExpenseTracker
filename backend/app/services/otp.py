"""Email verification / password-reset OTP codes.

Codes are numeric, HMAC-hashed before storage, and single-use per (email,
purpose): a fresh request replaces any outstanding code rather than letting a
user hold several valid ones — matching the old `otp_{purpose}_{email}`
Firestore document id.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import BadRequestError, NotFoundError, RateLimitedError
from app.db.models.auth_otp import AuthOtp, OtpPurpose

logger = logging.getLogger(__name__)

_DIGITS = "0123456789"
_dev_secret: str | None = None


def _hash_secret(settings: Settings) -> str:
    global _dev_secret
    if settings.otp_hash_secret:
        return settings.otp_hash_secret
    if _dev_secret is None:
        _dev_secret = secrets.token_hex(32)
        logger.warning(
            "otp_hash_secret_unset",
            extra={"hint": "set OTP_HASH_SECRET so outstanding OTPs survive a restart"},
        )
    return _dev_secret


def generate_code(settings: Settings) -> str:
    return "".join(secrets.choice(_DIGITS) for _ in range(settings.otp_length))


def _hash_code(settings: Settings, code: str) -> str:
    return hmac.new(
        _hash_secret(settings).encode(), code.encode(), hashlib.sha256
    ).hexdigest()


async def issue_otp(
    session: AsyncSession,
    settings: Settings,
    *,
    email: str,
    purpose: OtpPurpose,
) -> str:
    """Create (or replace) the outstanding OTP for `email`/`purpose`.

    Returns the raw code, which the caller must email — only the hash is
    persisted.
    """
    code = generate_code(settings)
    now = datetime.now(UTC)
    code_hash = _hash_code(settings, code)
    expires_at = now + timedelta(minutes=settings.otp_expiry_minutes)

    stmt = (
        pg_insert(AuthOtp)
        .values(
            email=email,
            purpose=purpose,
            code_hash=code_hash,
            attempts=0,
            expires_at=expires_at,
        )
        .on_conflict_do_update(
            constraint="uq_auth_otps_email_purpose",
            set_={
                "code_hash": code_hash,
                "attempts": 0,
                "expires_at": expires_at,
                "consumed_at": None,
            },
        )
    )
    await session.execute(stmt)
    await session.commit()
    return code


async def verify_and_consume_otp(
    session: AsyncSession,
    settings: Settings,
    *,
    email: str,
    purpose: OtpPurpose,
    code: str,
) -> None:
    """Raise if `code` does not match the outstanding OTP; otherwise consume it."""
    result = await session.execute(
        select(AuthOtp).where(AuthOtp.email == email, AuthOtp.purpose == purpose)
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise NotFoundError("Invalid or expired code.", code="otp_invalid")

    now = datetime.now(UTC)
    if row.expires_at < now:
        await session.delete(row)
        await session.commit()
        raise NotFoundError("Code expired. Request a new one.", code="otp_expired")

    if row.attempts >= settings.otp_max_attempts:
        await session.delete(row)
        await session.commit()
        raise RateLimitedError(
            "Too many incorrect attempts. Request a new code.",
            code="otp_too_many_attempts",
        )

    if not hmac.compare_digest(row.code_hash, _hash_code(settings, code)):
        row.attempts += 1
        await session.commit()
        raise BadRequestError("Invalid or expired code.", code="otp_invalid")

    await session.delete(row)
    await session.commit()
