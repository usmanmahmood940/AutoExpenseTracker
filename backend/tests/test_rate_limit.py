"""Sliding-window rate limiting."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import RateLimitedError
from app.services import rate_limit


def _settings(**overrides: object) -> Settings:
    defaults: dict[str, object] = {
        "database_url": "postgresql+asyncpg://u:p@localhost:5432/db",
        "_env_file": None,
    }
    return Settings(**{**defaults, **overrides})  # type: ignore[arg-type]


async def test_allows_up_to_the_limit_then_blocks(session: AsyncSession) -> None:
    settings = _settings(rate_limit_window_minutes=15)
    key = f"key-{uuid.uuid4().hex}"

    for _ in range(3):
        await rate_limit.enforce_rate_limit(
            session, settings, scope="test_scope", key=key, limit=3
        )

    with pytest.raises(RateLimitedError):
        await rate_limit.enforce_rate_limit(
            session, settings, scope="test_scope", key=key, limit=3
        )


async def test_scopes_are_independent(session: AsyncSession) -> None:
    settings = _settings()
    key = f"key-{uuid.uuid4().hex}"

    for _ in range(2):
        await rate_limit.enforce_rate_limit(
            session, settings, scope="scope_a", key=key, limit=2
        )
    with pytest.raises(RateLimitedError):
        await rate_limit.enforce_rate_limit(
            session, settings, scope="scope_a", key=key, limit=2
        )

    # A different scope for the same key starts its own counter.
    await rate_limit.enforce_rate_limit(
        session, settings, scope="scope_b", key=key, limit=2
    )


async def test_keys_are_independent(session: AsyncSession) -> None:
    settings = _settings()
    scope = "shared_scope"

    for _ in range(2):
        await rate_limit.enforce_rate_limit(
            session, settings, scope=scope, key="key-one", limit=2
        )
    with pytest.raises(RateLimitedError):
        await rate_limit.enforce_rate_limit(
            session, settings, scope=scope, key="key-one", limit=2
        )

    await rate_limit.enforce_rate_limit(
        session, settings, scope=scope, key="key-two", limit=2
    )
