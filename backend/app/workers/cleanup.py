"""OTP / reset-session / rate-limit cleanup. Replaces `cleanupExpiredAuthDocs`."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.db.models.auth_otp import AuthOtp
from app.db.models.auth_rate_limit import AuthRateLimit
from app.db.models.password_reset_session import PasswordResetSession


async def cleanup_expired_auth(
    session: AsyncSession, *, settings: Settings, now: datetime | None = None
) -> dict[str, int]:
    now = now or datetime.now(UTC)
    otps = await session.execute(delete(AuthOtp).where(AuthOtp.expires_at < now))
    sessions = await session.execute(
        delete(PasswordResetSession).where(PasswordResetSession.expires_at < now)
    )
    # Keep one extra window so a still-valid limiter is never dropped mid-count.
    stale_before = now - timedelta(minutes=settings.rate_limit_window_minutes * 2)
    limits = await session.execute(
        delete(AuthRateLimit).where(AuthRateLimit.window_start < stale_before)
    )
    await session.commit()
    return {
        "auth_otps": otps.rowcount or 0,
        "password_reset_sessions": sessions.rowcount or 0,
        "auth_rate_limits": limits.rowcount or 0,
    }
