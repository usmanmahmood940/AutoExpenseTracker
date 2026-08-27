"""Live Insights aggregations. Monthly summaries plus range/trend/recurring."""

from __future__ import annotations

import re
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BadRequestError
from app.db.models.enums import TransactionStatus, TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.merchant_key import normalize_merchant_key
from app.services.money import as_money, money_float
from app.services.transactions import parse_iso_date

YEAR_MONTH_RE = re.compile(r"^\d{4}-\d{2}$")
SIMILAR_AMOUNT_RATIO = Decimal("0.05")


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
    _ = date(year, month, 1)
    return value


def _month_bounds(year_month: str) -> tuple[date, date]:
    year, month = int(year_month[:4]), int(year_month[5:7])
    start = date(year, month, 1)
    end = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)
    last = end - timedelta(days=1)
    return start, last


def parse_range(date_from: str, date_to: str) -> tuple[date, date]:
    start = parse_iso_date(date_from, "from")
    end = parse_iso_date(date_to, "to")
    if end < start:
        raise BadRequestError(
            "`to` must be on or after `from`.",
            code="invalid_date_range",
        )
    return start, end


def default_trend_bucket(start: date, end: date) -> str:
    return "day" if (end - start).days <= 45 else "week"


def _base_filters(user_id, start: date, end: date):
    return (
        Transaction.user_id == user_id,
        Transaction.status != TransactionStatus.deleted,
        Transaction.transaction_date >= start,
        Transaction.transaction_date <= end,
    )


def _amount_map(rows: list[tuple[str | None, Decimal]]) -> dict[str, float]:
    out: dict[str, float] = {}
    for key, value in rows:
        amount = money_float(value)
        if abs(amount) > 0.0001:
            out[key or "Unknown"] = amount
    return out


async def _summary_for_range(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    year_month: str = "",
) -> dict:
    base = _base_filters(user.id, start, end)
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
            select(
                Transaction.merchant,
                Transaction.merchant_normalized,
                func.sum(Transaction.amount),
                func.count(Transaction.id),
            )
            .where(*base, Transaction.type == TransactionType.debit)
            .group_by(Transaction.merchant, Transaction.merchant_normalized)
        )
    ).all()

    by_merchant: dict[str, float] = {}
    by_merchant_stats: dict[str, dict] = {}
    for merchant, normalized, amount_raw, visits in by_merchant_rows:
        amount = money_float(amount_raw)
        if abs(amount) <= 0.0001:
            continue
        name = merchant or "Unknown"
        by_merchant[name] = amount
        by_merchant_stats[name] = {
            "amount": amount,
            "visit_count": int(visits),
            "merchant_normalized": normalized or normalize_merchant_key(name),
        }

    return {
        "year_month": year_month,
        "date_from": start.isoformat(),
        "date_to": end.isoformat(),
        "currency": user.default_currency,
        "total_debit": money_float(total_debit),
        "total_credit": money_float(total_credit),
        "net": money_float(total_credit - total_debit),
        "transaction_count": count,
        "by_category": _amount_map(by_category_rows),
        "by_merchant": by_merchant,
        "by_merchant_stats": by_merchant_stats,
    }


async def get_summary(session: AsyncSession, *, user: User, year_month: str) -> dict:
    parsed = parse_year_month(year_month)
    start, end = _month_bounds(parsed)
    return await _summary_for_range(
        session, user=user, start=start, end=end, year_month=parsed
    )


# Used by the monthly_summaries worker.
_summary_for = get_summary


async def get_range_summary(
    session: AsyncSession, *, user: User, date_from: str, date_to: str
) -> dict:
    start, end = parse_range(date_from, date_to)
    return await _summary_for_range(session, user=user, start=start, end=end)


async def get_trend(
    session: AsyncSession,
    *,
    user: User,
    date_from: str,
    date_to: str,
    bucket: str | None = None,
) -> dict:
    start, end = parse_range(date_from, date_to)
    resolved = (bucket or default_trend_bucket(start, end)).lower()
    if resolved not in {"day", "week"}:
        raise BadRequestError(
            "bucket must be day or week.",
            code="invalid_trend_bucket",
        )

    debit_filter = Transaction.type == TransactionType.debit
    if resolved == "day":
        group_col = Transaction.transaction_date
        rows = (
            await session.execute(
                select(
                    group_col,
                    func.coalesce(
                        func.sum(Transaction.amount).filter(debit_filter),
                        0,
                    ),
                )
                .where(*_base_filters(user.id, start, end))
                .group_by(group_col)
            )
        ).all()
        by_day = {row[0]: money_float(as_money(row[1])) for row in rows}
        points = []
        cursor = start
        while cursor <= end:
            points.append(
                {"date": cursor.isoformat(), "debit": by_day.get(cursor, 0.0)}
            )
            cursor += timedelta(days=1)
        return {"bucket": "day", "points": points, "currency": user.default_currency}

    week_col = func.date_trunc("week", Transaction.transaction_date)
    rows = (
        await session.execute(
            select(
                week_col,
                func.coalesce(func.sum(Transaction.amount).filter(debit_filter), 0),
            )
            .where(*_base_filters(user.id, start, end))
            .group_by(week_col)
            .order_by(week_col)
        )
    ).all()
    by_week: dict[date, float] = {}
    for raw_week, amount in rows:
        week_start = raw_week.date() if hasattr(raw_week, "date") else raw_week
        by_week[week_start] = money_float(as_money(amount))

    week_cursor = start - timedelta(days=start.weekday())
    points = []
    while week_cursor <= end:
        points.append(
            {"date": week_cursor.isoformat(), "debit": by_week.get(week_cursor, 0.0)}
        )
        week_cursor += timedelta(days=7)
    return {"bucket": "week", "points": points, "currency": user.default_currency}


def _has_similar_amounts(amounts: list[Decimal]) -> bool:
    if len(amounts) < 2:
        return False
    ordered = sorted(amounts)
    for i in range(1, len(ordered)):
        prev, curr = ordered[i - 1], ordered[i]
        avg = (prev + curr) / 2
        if avg <= 0:
            continue
        if abs(prev - curr) / avg <= SIMILAR_AMOUNT_RATIO:
            return True
    return False


async def list_recurring(
    session: AsyncSession, *, user: User, date_from: str, date_to: str
) -> dict:
    start, end = parse_range(date_from, date_to)
    rows = (
        await session.execute(
            select(
                Transaction.merchant,
                Transaction.merchant_normalized,
                Transaction.amount,
                Transaction.transaction_date,
                Transaction.is_recurring,
            ).where(
                *_base_filters(user.id, start, end),
                Transaction.type == TransactionType.debit,
            )
        )
    ).all()

    grouped: dict[str, list] = defaultdict(list)
    for merchant, normalized, amount, tx_date, is_recurring in rows:
        key = normalized or normalize_merchant_key(merchant or "Unknown")
        grouped[key].append((merchant, amount, tx_date, is_recurring))

    items = []
    for key, entries in grouped.items():
        amounts = [as_money(row[1]) for row in entries]
        flagged = any(row[3] for row in entries)
        if not flagged and not _has_similar_amounts(amounts):
            continue
        display = next((row[0] for row in entries if row[0]), key)
        last_date = max(row[2] for row in entries)
        total = sum(amounts, Decimal("0"))
        count = len(entries)
        items.append(
            {
                "display_name": display,
                "merchant_normalized": key,
                "count": count,
                "average_amount": money_float(total / count),
                "last_date": last_date.isoformat(),
            }
        )
    items.sort(key=lambda item: item["average_amount"], reverse=True)
    return {"items": items}


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
        summaries.append(await get_summary(session, user=user, year_month=year_month))
    return summaries
