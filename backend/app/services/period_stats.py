"""Live period stats. Port of `functions/src/period_stats.ts`.

Computed with SQL over `transactions` — no `monthly_summaries` worker
dependency, which is the Phase C gating rule.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import and_, func, or_, select
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


def _in_range(start: date, end: date):
    return and_(
        Transaction.transaction_date >= start,
        Transaction.transaction_date <= end,
    )


async def _highlights(
    session: AsyncSession,
    *,
    user: User,
    from_date: date,
    to_date: date,
) -> tuple[dict | None, dict | None]:
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
    rows = (
        await session.execute(
            select(*highlight_cols)
            .where(
                *_countable(user.id, from_date, to_date),
                Transaction.type.in_((TransactionType.debit, TransactionType.credit)),
            )
            .distinct(Transaction.type)
            .order_by(
                Transaction.type,
                Transaction.amount.desc(),
                Transaction.transaction_date.desc(),
                Transaction.id.desc(),
            )
        )
    ).all()

    highest_spend = None
    highest_receive = None
    for row in rows:
        merchant = row.merchant or ""
        stored = row.merchant_normalized or ""
        payload = {
            "id": row.id,
            "amount": money_float(row.amount),
            "merchant": merchant,
            "merchant_normalized": stored or normalize_merchant_key(merchant),
            "category": row.category or "Uncategorized",
            "transaction_date": row.transaction_date.isoformat(),
            "type": row.type.value,
            "currency": row.currency,
        }
        if row.type == TransactionType.debit:
            highest_spend = payload
        elif row.type == TransactionType.credit:
            highest_receive = payload
    return highest_spend, highest_receive


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

    debit = Transaction.type == TransactionType.debit
    credit = Transaction.type == TransactionType.credit
    prev = previous_range(period, from_date, to_date)
    current_range = _in_range(from_date, to_date)

    if prev is None:
        totals_stmt = select(
            func.coalesce(func.sum(Transaction.amount).filter(debit), 0),
            func.coalesce(func.sum(Transaction.amount).filter(credit), 0),
        ).where(*_countable(user.id, from_date, to_date))
        spent_raw, received_raw = (await session.execute(totals_stmt)).one()
        prev_spent = prev_received = None
    else:
        prev_range = _in_range(prev[0], prev[1])
        totals_stmt = select(
            func.coalesce(
                func.sum(Transaction.amount).filter(debit & current_range), 0
            ),
            func.coalesce(
                func.sum(Transaction.amount).filter(credit & current_range), 0
            ),
            func.coalesce(func.sum(Transaction.amount).filter(debit & prev_range), 0),
            func.coalesce(func.sum(Transaction.amount).filter(credit & prev_range), 0),
        ).where(
            Transaction.user_id == user.id,
            Transaction.status != TransactionStatus.deleted,
            or_(current_range, prev_range),
        )
        spent_raw, received_raw, prev_spent, prev_received = (
            await session.execute(totals_stmt)
        ).one()

    spent = as_money(spent_raw)
    received = as_money(received_raw)
    highest_spend, highest_receive = await _highlights(
        session, user=user, from_date=from_date, to_date=to_date
    )

    comparison = None
    if prev is not None and prev_spent is not None and prev_received is not None:
        previous_spent = as_money(prev_spent)
        previous_received = as_money(prev_received)
        current_net = received - spent
        previous_net = previous_received - previous_spent
        comparison = {
            "spent_change_percent": percent_change(previous_spent, spent),
            "received_change_percent": percent_change(previous_received, received),
            "net_change_percent": percent_change(previous_net, current_net),
        }

    net = received - spent
    return {
        "period": period.value,
        "from": from_date.isoformat(),
        "to": to_date.isoformat(),
        "currency": user.default_currency,
        "spent": money_float(spent),
        "received": money_float(received),
        "net": money_float(net),
        "highest_spend": highest_spend,
        "highest_receive": highest_receive,
        "comparison": comparison,
    }
