"""Live period stats. Port of `functions/src/period_stats.ts`.

Computed with SQL over `transactions` — no `monthly_summaries` worker
dependency, which is the Phase C gating rule.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BadRequestError
from app.db.models.enums import PeriodKind, TransactionStatus, TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.merchant_key import normalize_merchant_key
from app.services.money import as_money, money_float


def previous_range(
    period: PeriodKind, from_date: date, to_date: date
) -> tuple[date, date] | None:
    """Previous comparable window — mirrors HomeProvider / period_stats.ts."""
    if period is PeriodKind.today:
        return None

    if period is PeriodKind.week:
        days_elapsed = (to_date - from_date).days
        prev_from = from_date - timedelta(days=7)
        prev_to = prev_from + timedelta(days=days_elapsed)
        return prev_from, prev_to

    if from_date.month == 1:
        prev_month_start = date(from_date.year - 1, 12, 1)
    else:
        prev_month_start = date(from_date.year, from_date.month - 1, 1)
    # Last day of the previous calendar month (JS `Date(y, m, 0)`).
    last_day_prev = (from_date.replace(day=1) - timedelta(days=1)).day
    prev_end_day = min(to_date.day, last_day_prev)
    prev_to = date(prev_month_start.year, prev_month_start.month, prev_end_day)
    return prev_month_start, prev_to


def percent_change(previous: Decimal, current: Decimal) -> float:
    if previous == 0:
        return 0.0 if current == 0 else 100.0
    return money_float((current - previous) / abs(previous) * 100)


def _countable(user_id: uuid.UUID, from_date: date, to_date: date):
    return (
        Transaction.user_id == user_id,
        Transaction.status != TransactionStatus.deleted,
        Transaction.transaction_date >= from_date,
        Transaction.transaction_date <= to_date,
    )


async def _range_totals(
    session: AsyncSession,
    *,
    user: User,
    from_date: date,
    to_date: date,
) -> dict:
    totals_stmt = select(
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
    ).where(*_countable(user.id, from_date, to_date))
    spent_raw, received_raw = (await session.execute(totals_stmt)).one()
    spent = as_money(spent_raw)
    received = as_money(received_raw)

    highlight_cols = (
        Transaction.id,
        Transaction.amount,
        Transaction.merchant,
        Transaction.merchant_normalized,
        Transaction.category,
        Transaction.transaction_date,
        Transaction.type,
        Transaction.currency,
    )

    async def _highlight(tx_type: TransactionType) -> dict | None:
        stmt = (
            select(*highlight_cols)
            .where(
                *_countable(user.id, from_date, to_date),
                Transaction.type == tx_type,
            )
            .order_by(
                Transaction.amount.desc(),
                Transaction.transaction_date.desc(),
                Transaction.id.desc(),
            )
            .limit(1)
        )
        row = (await session.execute(stmt)).one_or_none()
        if row is None:
            return None
        merchant = row.merchant or ""
        stored = row.merchant_normalized or ""
        return {
            "id": row.id,
            "amount": money_float(row.amount),
            "merchant": merchant,
            "merchant_normalized": stored or normalize_merchant_key(merchant),
            "category": row.category or "Uncategorized",
            "transaction_date": row.transaction_date.isoformat(),
            "type": row.type.value,
            "currency": row.currency,
        }

    return {
        "spent": spent,
        "received": received,
        "currency": user.default_currency,
        "highest_spend": await _highlight(TransactionType.debit),
        "highest_receive": await _highlight(TransactionType.credit),
    }


async def get_period_stats(
    session: AsyncSession,
    *,
    user: User,
    period: PeriodKind,
    from_date: date,
    to_date: date,
) -> dict:
    if from_date > to_date:
        raise BadRequestError(
            "from must be on or before to.",
            code="invalid_date_range",
        )

    current = await _range_totals(
        session, user=user, from_date=from_date, to_date=to_date
    )
    comparison = None
    prev = previous_range(period, from_date, to_date)
    if prev is not None:
        previous = await _range_totals(
            session, user=user, from_date=prev[0], to_date=prev[1]
        )
        current_net = current["received"] - current["spent"]
        previous_net = previous["received"] - previous["spent"]
        comparison = {
            "spent_change_percent": percent_change(previous["spent"], current["spent"]),
            "received_change_percent": percent_change(
                previous["received"], current["received"]
            ),
            "net_change_percent": percent_change(previous_net, current_net),
        }

    net = current["received"] - current["spent"]
    return {
        "period": period.value,
        "from": from_date.isoformat(),
        "to": to_date.isoformat(),
        "currency": current["currency"],
        "spent": money_float(current["spent"]),
        "received": money_float(current["received"]),
        "net": money_float(net),
        "highest_spend": current["highest_spend"],
        "highest_receive": current["highest_receive"],
        "comparison": comparison,
    }
