"""Password-reset session tokens: single-use, expiring, unguessable."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import NotFoundError
from app.services import reset_session, user_profile


def _settings(**overrides: object) -> Settings:
    defaults: dict[str, object] = {
        "database_url": "postgresql+asyncpg://u:p@localhost:5432/db",
        "_env_file": None,
    }
    return Settings(**{**defaults, **overrides})  # type: ignore[arg-type]


async def _make_user(session: AsyncSession):
    email = f"reset-{uuid.uuid4().hex[:12]}@example.com"
    return await user_profile.create_profile(
        session,
        firebase_uid=f"uid-{uuid.uuid4().hex[:12]}",
        email=email,
        email_verified=True,
        display_name="Reset Test",
    )


async def test_issue_then_consume_returns_the_session(session: AsyncSession) -> None:
    settings = _settings()
    user = await _make_user(session)

    token = await reset_session.issue(
        session, settings, user_id=user.id, email=user.email
    )
    row = await reset_session.consume(session, token=token)

    assert row.user_id == user.id
    assert row.email == user.email


async def test_token_is_single_use(session: AsyncSession) -> None:
    settings = _settings()
    user = await _make_user(session)

    token = await reset_session.issue(
        session, settings, user_id=user.id, email=user.email
    )
    await reset_session.consume(session, token=token)

    with pytest.raises(NotFoundError):
        await reset_session.consume(session, token=token)


async def test_unknown_token_is_rejected(session: AsyncSession) -> None:
    with pytest.raises(NotFoundError):
        await reset_session.consume(session, token="not-a-real-token")


async def test_expired_session_is_rejected(session: AsyncSession) -> None:
    settings = _settings(reset_session_expiry_minutes=0)
    user = await _make_user(session)

    token = await reset_session.issue(
        session, settings, user_id=user.id, email=user.email
    )

    with pytest.raises(NotFoundError):
        await reset_session.consume(session, token=token)
