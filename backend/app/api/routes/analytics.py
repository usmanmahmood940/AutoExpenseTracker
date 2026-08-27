"""Live monthly summaries for Insights. Replaces `monthlySummaries` reads."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import (
    MonthlySummaryListOut,
    MonthlySummaryOut,
    NarrativeOut,
    RecurringListOut,
    RecurringMerchantOut,
    TrendOut,
    TrendPointOut,
)
from app.services import analytics as analytics_service
from app.services import insights_narrative

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


@router.get("/range", response_model=MonthlySummaryOut)
async def get_range(
    user: CurrentUser,
    session: DbSession,
    date_from: Annotated[str, Query(alias="from")],
    date_to: Annotated[str, Query(alias="to")],
) -> MonthlySummaryOut:
    payload = await analytics_service.get_range_summary(
        session, user=user, date_from=date_from, date_to=date_to
    )
    return MonthlySummaryOut.model_validate(payload)


@router.get("/trend", response_model=TrendOut)
async def get_trend(
    user: CurrentUser,
    session: DbSession,
    date_from: Annotated[str, Query(alias="from")],
    date_to: Annotated[str, Query(alias="to")],
    bucket: str | None = None,
) -> TrendOut:
    payload = await analytics_service.get_trend(
        session,
        user=user,
        date_from=date_from,
        date_to=date_to,
        bucket=bucket,
    )
    return TrendOut(
        bucket=payload["bucket"],
        currency=payload["currency"],
        points=[TrendPointOut.model_validate(point) for point in payload["points"]],
    )


@router.get("/recurring", response_model=RecurringListOut)
async def get_recurring(
    user: CurrentUser,
    session: DbSession,
    date_from: Annotated[str, Query(alias="from")],
    date_to: Annotated[str, Query(alias="to")],
) -> RecurringListOut:
    payload = await analytics_service.list_recurring(
        session, user=user, date_from=date_from, date_to=date_to
    )
    return RecurringListOut(
        items=[RecurringMerchantOut.model_validate(item) for item in payload["items"]]
    )


@router.get("/narrative", response_model=NarrativeOut)
async def get_narrative(
    user: CurrentUser,
    session: DbSession,
    date_from: Annotated[str, Query(alias="from")],
    date_to: Annotated[str, Query(alias="to")],
) -> NarrativeOut:
    payload = await insights_narrative.get_narrative(
        session, user=user, date_from=date_from, date_to=date_to
    )
    return NarrativeOut.model_validate(payload)
