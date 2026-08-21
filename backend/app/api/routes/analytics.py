"""Live monthly summaries for Insights. Replaces `monthlySummaries` reads."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import MonthlySummaryListOut, MonthlySummaryOut
from app.services import analytics as analytics_service

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/summary", response_model=MonthlySummaryOut)
async def get_summary(
    user: CurrentUser,
    session: DbSession,
    year_month: str,
) -> MonthlySummaryOut:
    payload = await analytics_service.get_summary(
        session, user=user, year_month=year_month
    )
    return MonthlySummaryOut.model_validate(payload)


@router.get("/summaries", response_model=MonthlySummaryListOut)
async def list_summaries(
    user: CurrentUser,
    session: DbSession,
    limit: Annotated[int, Query(ge=1, le=24)] = 6,
) -> MonthlySummaryListOut:
    items = await analytics_service.list_recent_summaries(
        session, user=user, limit=limit
    )
    return MonthlySummaryListOut(
        items=[MonthlySummaryOut.model_validate(item) for item in items]
    )
