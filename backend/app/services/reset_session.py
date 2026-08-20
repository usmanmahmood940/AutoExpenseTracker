"""Password-reset session tokens minted after `/auth/verify-reset-otp`.

Replaces the `authTemp` Firestore collection's `type: 'reset_session'`
documents. Only the SHA-256 hash of the token is stored; the raw token is
returned once to the caller and never persisted.
"""

from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import NotFoundError
from app.db.models.password_reset_session import PasswordResetSession


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


async def issue(
    session: AsyncSession,
    settings: Settings,
    *,
    user_id: uuid.UUID,
    email: str,
) -> str:
    token = secrets.token_urlsafe(32)
    now = datetime.now(UTC)
    session.add(
        PasswordResetSession(
            token_hash=_hash_token(token),
            user_id=user_id,
            email=email,
            expires_at=now + timedelta(minutes=settings.reset_session_expiry_minutes),
        )
    )
    await session.commit()
    return token


async def consume(session: AsyncSession, *, token: str) -> PasswordResetSession:
    """Validate and delete the session in one step; tokens are single-use."""
    result = await session.execute(
        select(PasswordResetSession).where(
            PasswordResetSession.token_hash == _hash_token(token)
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise NotFoundError(
            "Reset session expired. Start again.", code="reset_session_invalid"
        )

    now = datetime.now(UTC)
    if row.expires_at < now or row.consumed_at is not None:
        await session.delete(row)
        await session.commit()
        raise NotFoundError(
            "Reset session expired. Start again.", code="reset_session_invalid"
        )

    await session.delete(row)
    await session.commit()
    return row
