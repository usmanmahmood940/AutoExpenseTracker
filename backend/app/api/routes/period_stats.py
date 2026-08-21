"""Period overview + highlights for Home. Replaces `getPeriodStats`."""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import PeriodStatsOut
from app.db.models.enums import PeriodKind
from app.services import period_stats as stats_service

router = APIRouter(tags=["period-stats"])


@router.get("/period-stats", response_model=PeriodStatsOut)
async def get_period_stats(
    user: CurrentUser,
    session: DbSession,
    period: PeriodKind,
    from_date: Annotated[date, Query(alias="from")],
    to_date: Annotated[date, Query(alias="to")],
) -> PeriodStatsOut:
    payload = await stats_service.get_period_stats(
        session, user=user, period=period, from_date=from_date, to_date=to_date
    )
    return PeriodStatsOut(
        period=payload["period"],
        from_=payload["from"],
        to=payload["to"],
        currency=payload["currency"],
        spent=payload["spent"],
        received=payload["received"],
        net=payload["net"],
        highest_spend=payload["highest_spend"],
        highest_receive=payload["highest_receive"],
        comparison=payload["comparison"],
    )
