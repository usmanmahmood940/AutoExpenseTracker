"""Materialize `monthly_summaries` from live SQL.

Replaces `onUserTransactionWritten`. Insights still read live SQL in Phase C;
this table is what a later cache can switch to.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ai_summary import AiSummary
from app.db.models.monthly_summary import MonthlySummary
from app.db.models.user import User
from app.services.analytics import get_summary, list_recent_summaries
from app.services.money import as_money

AI_SUMMARY_RETENTION_DAYS = 180


async def recompute_month(
    session: AsyncSession, *, user: User, year_month: str
) -> MonthlySummary:
    payload = await get_summary(session, user=user, year_month=year_month)
    return await _upsert_summary(session, user=user, payload=payload)


async def _upsert_summary(
    session: AsyncSession, *, user: User, payload: dict
) -> MonthlySummary:
    year_month = payload["year_month"]
    result = await session.execute(
        select(MonthlySummary).where(
            MonthlySummary.user_id == user.id,
            MonthlySummary.year_month == year_month,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        row = MonthlySummary(user_id=user.id, year_month=year_month)
        session.add(row)
    row.currency = payload["currency"]
    row.total_debit = as_money(payload["total_debit"])
    row.total_credit = as_money(payload["total_credit"])
    row.net = as_money(payload["net"])
    row.transaction_count = payload["transaction_count"]
    row.by_category = payload["by_category"]
    row.by_merchant = payload["by_merchant"]
    await session.commit()
    await session.refresh(row)
    return row


async def purge_stale_ai_summaries(session: AsyncSession) -> int:
    cutoff = datetime.now(UTC) - timedelta(days=AI_SUMMARY_RETENTION_DAYS)
    result = await session.execute(
        delete(AiSummary).where(AiSummary.generated_at < cutoff)
    )
    await session.commit()
    return int(result.rowcount or 0)


async def recompute_recent(
    session: AsyncSession, *, user_id: uuid.UUID | None, limit: int = 6
) -> int:
    await purge_stale_ai_summaries(session)
    stmt = select(User)
    if user_id is not None:
        stmt = stmt.where(User.id == user_id)
    users = list((await session.execute(stmt)).scalars().all())
    count = 0
    for user in users:
        months = await list_recent_summaries(session, user=user, limit=limit)
        for item in months:
            await _upsert_summary(session, user=user, payload=item)
            count += 1
    return count
