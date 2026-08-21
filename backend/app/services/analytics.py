"""Live monthly summaries. Replaces Firestore `monthlySummaries` reads.

Phase D may materialize these; Phase C computes them with SQL so Insights
does not wait on a worker.
"""

from __future__ import annotations

import re
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BadRequestError
from app.db.models.enums import TransactionStatus, TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.money import as_money, money_float

YEAR_MONTH_RE = re.compile(r"^\d{4}-\d{2}$")


def parse_year_month(value: str) -> str:
    if not YEAR_MONTH_RE.match(value):
        raise BadRequestError(
            "year_month must be YYYY-MM.",
            code="invalid_year_month",
        )
    year, month = int(value[:4]), int(value[5:7])
    if month < 1 or month > 12:
        raise BadRequestError(
            "year_month must be YYYY-MM.",
            code="invalid_year_month",
        )
    # Reject impossible dates like 2026-13 already handled; 2026-00 too.
    _ = date(year, month, 1)
    return value


def _month_bounds(year_month: str) -> tuple[date, date]:
    year, month = int(year_month[:4]), int(year_month[5:7])
    start = date(year, month, 1)
    end = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)
    last = end - timedelta(days=1)
    return start, last


async def _summary_for(session: AsyncSession, *, user: User, year_month: str) -> dict:
    start, end = _month_bounds(year_month)
    base = (
        Transaction.user_id == user.id,
        Transaction.status != TransactionStatus.deleted,
        Transaction.transaction_date >= start,
        Transaction.transaction_date <= end,
    )

    totals = (
        await session.execute(
            select(
                func.coalesce(
                    func.sum(Transaction.amount).filter(
                        Transaction.type == TransactionType.debit
                    ),
                    0,
                ),
                func.coalesce(
                    func.sum(Transaction.amount).filter(
                        Transaction.type == TransactionType.credit
                    ),
                    0,
                ),
                func.count(Transaction.id),
            ).where(*base)
        )
    ).one()
    total_debit = as_money(totals[0])
    total_credit = as_money(totals[1])
    count = int(totals[2])

    by_category_rows = (
        await session.execute(
            select(Transaction.category, func.sum(Transaction.amount))
            .where(*base, Transaction.type == TransactionType.debit)
            .group_by(Transaction.category)
        )
    ).all()
    by_merchant_rows = (
        await session.execute(
            select(Transaction.merchant, func.sum(Transaction.amount))
            .where(*base, Transaction.type == TransactionType.debit)
            .group_by(Transaction.merchant)
        )
    ).all()

    def _map(rows: list[tuple[str, Decimal]]) -> dict[str, float]:
        out: dict[str, float] = {}
        for key, value in rows:
            amount = money_float(value)
            if abs(amount) > 0.0001:
                out[key or "Unknown"] = amount
        return out

    return {
        "year_month": year_month,
        "currency": user.default_currency,
        "total_debit": money_float(total_debit),
        "total_credit": money_float(total_credit),
        "net": money_float(total_credit - total_debit),
        "transaction_count": count,
        "by_category": _map(by_category_rows),
        "by_merchant": _map(by_merchant_rows),
    }


async def get_summary(session: AsyncSession, *, user: User, year_month: str) -> dict:
    return await _summary_for(
        session, user=user, year_month=parse_year_month(year_month)
    )


async def list_recent_summaries(
    session: AsyncSession, *, user: User, limit: int
) -> list[dict]:
    """Months that actually have transactions, newest first — Insights' recent list."""
    month_col = func.to_char(Transaction.transaction_date, "YYYY-MM")
    rows = (
        await session.execute(
            select(month_col)
            .where(
                Transaction.user_id == user.id,
                Transaction.status != TransactionStatus.deleted,
            )
            .group_by(month_col)
            .order_by(month_col.desc())
            .limit(limit)
        )
    ).all()
    summaries = []
    for (year_month,) in rows:
        summaries.append(await _summary_for(session, user=user, year_month=year_month))
    return summaries
