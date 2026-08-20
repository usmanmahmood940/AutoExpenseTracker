"""Sliding-window rate limiting for auth routes.

Replaces the `authRateLimits` Firestore collection. Each call is its own
transaction — committed immediately, independent of the caller's session
state — so a count is never lost to an unrelated rollback later in the same
request, and a blocked attempt still counts against the window.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import RateLimitedError

_UPSERT_SQL = text(
    """
    INSERT INTO auth_rate_limits (scope, key, window_start, count)
    VALUES (:scope, :key, :now, 1)
    ON CONFLICT (scope, key) DO UPDATE SET
        window_start = CASE
            WHEN auth_rate_limits.window_start > :cutoff
            THEN auth_rate_limits.window_start
            ELSE :now
        END,
        count = CASE
            WHEN auth_rate_limits.window_start > :cutoff
            THEN auth_rate_limits.count + 1
            ELSE 1
        END,
        updated_at = now()
    RETURNING count
    """
)


async def enforce_rate_limit(
    session: AsyncSession,
    settings: Settings,
    *,
    scope: str,
    key: str,
    limit: int,
) -> None:
    """Raise `RateLimitedError` once more than `limit` calls land for
    `(scope, key)` inside the configured window."""
    now = datetime.now(UTC)
    cutoff = now - timedelta(minutes=settings.rate_limit_window_minutes)

    result = await session.execute(
        _UPSERT_SQL, {"scope": scope, "key": key, "now": now, "cutoff": cutoff}
    )
    count = result.scalar_one()
    await session.commit()

    if count > limit:
        raise RateLimitedError()
