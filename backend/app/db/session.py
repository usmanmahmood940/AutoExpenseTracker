"""Async engine and session management."""

from __future__ import annotations

from collections.abc import AsyncGenerator

from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import Settings, get_settings

_engine: AsyncEngine | None = None
_sessionmaker: async_sessionmaker[AsyncSession] | None = None


def attach_pgvector(engine: AsyncEngine) -> None:
    """Register the pgvector codec on every asyncpg connection."""

    @event.listens_for(engine.sync_engine, "connect")
    def _register_vector(dbapi_connection, _connection_record) -> None:  # type: ignore[no-untyped-def]
        from pgvector.asyncpg import register_vector

        dbapi_connection.run_async(register_vector)


def _build_engine(settings: Settings) -> AsyncEngine:
    engine = create_async_engine(
        settings.database_url,
        echo=settings.db_echo,
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_timeout=settings.db_pool_timeout,
        # Cloud Run freezes idle instances, so connections can be dead on wake.
        pool_recycle=settings.db_pool_recycle,
        pool_pre_ping=True,
    )
    attach_pgvector(engine)
    return engine


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        _engine = _build_engine(get_settings())
    return _engine


def get_sessionmaker() -> async_sessionmaker[AsyncSession]:
    global _sessionmaker
    if _sessionmaker is None:
        _sessionmaker = async_sessionmaker(
            bind=get_engine(),
            expire_on_commit=False,
            autoflush=False,
        )
    return _sessionmaker


async def dispose_engine() -> None:
    global _engine, _sessionmaker
    if _engine is not None:
        await _engine.dispose()
    _engine = None
    _sessionmaker = None


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Request-scoped session.

    Commits are explicit in the service layer; this only guarantees a rollback
    and close if the request fails partway through.
    """
    async with get_sessionmaker()() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
