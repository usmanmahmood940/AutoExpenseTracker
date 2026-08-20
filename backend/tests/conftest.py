"""Test configuration.

Points the suite at novaspend_test and builds its schema from model metadata.
Migration correctness is guarded separately by `alembic check`.
"""

from __future__ import annotations

import asyncio
import os

# Must precede any app import: get_settings() is cached on first call, and real
# environment variables outrank the .env file that local runs use.
os.environ["ENVIRONMENT"] = "local"
os.environ["DATABASE_URL"] = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://novaspend:novaspend@localhost:5432/novaspend_test",
)
os.environ["LOG_LEVEL"] = "WARNING"

from collections.abc import AsyncGenerator, Awaitable, Callable

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import get_settings
from app.db.models import Base
from app.db.session import dispose_engine, get_sessionmaker
from app.main import create_app


@pytest.fixture(scope="session", autouse=True)
def schema() -> None:
    async def rebuild() -> None:
        engine = create_async_engine(get_settings().database_url)
        try:
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.drop_all)
                await conn.run_sync(Base.metadata.create_all)
        finally:
            await engine.dispose()

    asyncio.run(rebuild())


@pytest.fixture
def client() -> TestClient:
    # Used as a context manager by tests so startup/shutdown hooks run.
    return TestClient(create_app())


@pytest.fixture
async def session() -> AsyncGenerator[AsyncSession, None]:
    """A raw session for exercising service-layer functions directly.

    pytest-asyncio gives each async test its own event loop, but the app's
    engine is a module-level singleton bound to whichever loop first created
    it — so it's disposed on teardown, forcing the next test to lazily build a
    fresh one bound to *its* loop instead of reusing a dead one.
    """
    async with get_sessionmaker()() as db:
        yield db
    await dispose_engine()


@pytest.fixture
def settings():
    """The same cached `Settings` instance the app's dependencies resolve to."""
    return get_settings()


def run_isolated[T](fn: Callable[[AsyncSession], Awaitable[T]]) -> T:
    """Run `fn` against a brand-new engine + event loop, then tear both down.

    For sync tests that need one bit of direct DB access (e.g. seeding an OTP)
    alongside a `TestClient`, whose requests run in their own portal thread and
    loop — reusing the app's cached engine there would hand asyncpg a
    connection opened on a different loop than the one making the call.
    """

    async def _run() -> T:
        engine = create_async_engine(get_settings().database_url)
        sessionmaker = async_sessionmaker(bind=engine, expire_on_commit=False)
        try:
            async with sessionmaker() as db:
                return await fn(db)
        finally:
            await engine.dispose()

    return asyncio.run(_run())
