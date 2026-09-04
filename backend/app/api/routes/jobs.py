"""Cloud Scheduler targets. Replaces Firestore triggers + cleanupExpiredAuthDocs."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header
from pydantic import BaseModel, Field

from app.api.deps import AppSettings, DbSession
from app.core.errors import ServiceUnavailableError, UnauthorizedError
from app.services.rag_indexer import reindex_users
from app.workers.cleanup import cleanup_expired_auth
from app.workers.summaries import recompute_recent

router = APIRouter(prefix="/internal/jobs", tags=["jobs"])


class CleanupResult(BaseModel):
    auth_otps: int
    password_reset_sessions: int
    auth_rate_limits: int


class RecomputeRequest(BaseModel):
    user_id: UUID | None = None
    limit: int = Field(default=6, ge=1, le=24)


class RecomputeResult(BaseModel):
    months_updated: int


class ReindexRagRequest(BaseModel):
    user_id: UUID | None = None
    full: bool = False


class ReindexRagResult(BaseModel):
    users: int
    transactions: int
    merchants: int
    periods: int
    skipped: int
    deleted: int


def _require_cron(settings: AppSettings, x_cron_secret: str | None) -> None:
    if not settings.cron_secret:
        if settings.environment == "local":
            return
        raise ServiceUnavailableError(
            "CRON_SECRET is not configured.",
            code="cron_unconfigured",
        )
    if x_cron_secret != settings.cron_secret:
        raise UnauthorizedError("Invalid cron secret.", code="cron_unauthorized")


@router.post(
    "/cleanup-auth",
    response_model=CleanupResult,
    summary="Delete expired OTPs, reset sessions, and stale rate-limit rows",
)
async def cleanup_auth(
    session: DbSession,
    settings: AppSettings,
    x_cron_secret: Annotated[str | None, Header(alias="X-Cron-Secret")] = None,
) -> CleanupResult:
    _require_cron(settings, x_cron_secret)
    counts = await cleanup_expired_auth(session, settings=settings)
    return CleanupResult(**counts)


@router.post(
    "/recompute-summaries",
    response_model=RecomputeResult,
    summary="Rebuild monthly_summaries from live transaction SQL",
)
async def recompute_summaries(
    session: DbSession,
    settings: AppSettings,
    body: RecomputeRequest | None = None,
    x_cron_secret: Annotated[str | None, Header(alias="X-Cron-Secret")] = None,
) -> RecomputeResult:
    _require_cron(settings, x_cron_secret)
    payload = body or RecomputeRequest()
    count = await recompute_recent(
        session, user_id=payload.user_id, limit=payload.limit
    )
    return RecomputeResult(months_updated=count)


@router.post(
    "/reindex-rag",
    response_model=ReindexRagResult,
    summary="Backfill rag_documents embeddings for one or all users",
)
async def reindex_rag(
    session: DbSession,
    settings: AppSettings,
    body: ReindexRagRequest | None = None,
    x_cron_secret: Annotated[str | None, Header(alias="X-Cron-Secret")] = None,
) -> ReindexRagResult:
    _require_cron(settings, x_cron_secret)
    payload = body or ReindexRagRequest()
    stats = await reindex_users(session, user_id=payload.user_id, full=payload.full)
    return ReindexRagResult(
        users=stats.users,
        transactions=stats.transactions,
        merchants=stats.merchants,
        periods=stats.periods,
        skipped=stats.skipped,
        deleted=stats.deleted,
    )
