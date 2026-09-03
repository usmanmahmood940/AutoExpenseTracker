"""Live Insights aggregations. Monthly summaries plus range/trend/recurring."""

from __future__ import annotations

import re
from collections import defaultdict
from datetime import UTC, date, datetime, timedelta
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
TOP_MERCHANT_LIMIT = 5


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


def _iso_datetime(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=UTC)
    return value.astimezone(UTC).isoformat()


def _amount_map(rows: list[tuple[str | None, Decimal]]) -> dict[str, float]:
    out: dict[str, float] = {}
    for key, value in rows:
        amount = money_float(value)
        if abs(amount) > 0.0001:
            out[key or "Unknown"] = amount
    return out


def _merchant_stats_by_norm(
    rows: list[tuple[str | None, str | None, Decimal, int]],
) -> dict[str, dict]:
    """Aggregate merchant rows by normalized key so name variants share one bucket."""
    stats: dict[str, dict] = {}
    for merchant, normalized, amount_raw, visits in rows:
        amount = money_float(amount_raw)
        if abs(amount) <= 0.0001:
            continue
        display = merchant or "Unknown"
        norm = normalized or normalize_merchant_key(display)
        if norm not in stats:
            stats[norm] = {
                "display_name": display,
                "amount": 0.0,
                "visit_count": 0,
                "merchant_normalized": norm,
            }
        stats[norm]["amount"] += amount
        stats[norm]["visit_count"] += int(visits)
        if len(display) > len(stats[norm]["display_name"]):
            stats[norm]["display_name"] = display
    return stats


def _visit_totals_by_norm(
    rows: list[tuple[str | None, str | None, int]],
) -> dict[str, dict]:
    """Count every transaction (debit + credit) per merchant, merged by key."""
    merged: dict[str, dict] = {}
    for normalized, merchant, visits in rows:
        display = merchant or "Unknown"
        norm = (normalized or "").strip() or normalize_merchant_key(display)
        if norm not in merged:
            merged[norm] = {
                "display_name": display,
                "merchant_normalized": norm,
                "visit_count": 0,
            }
        merged[norm]["visit_count"] += int(visits)
        if len(display) > len(merged[norm]["display_name"]):
            merged[norm]["display_name"] = display
    return merged


def _top_merchant_row(data: dict, *, amount: float | None = None) -> dict:
    return {
        "display_name": data["display_name"],
        "merchant_normalized": data["merchant_normalized"],
        "amount": amount if amount is not None else data["amount"],
        "visit_count": data.get("visit_count", 0),
    }


def _top_merchants_from_stats(
    stats_by_norm: dict[str, dict],
    *,
    sort_key: str = "amount",
    limit: int = TOP_MERCHANT_LIMIT,
) -> list[dict]:
    items = list(stats_by_norm.values())
    items.sort(key=lambda item: item[sort_key], reverse=True)
    return [_top_merchant_row(item) for item in items[:limit]]


def _top_merchants_by_visits(
    spent_stats: dict[str, dict],
    received_stats: dict[str, dict],
    visit_totals: dict[str, dict],
    *,
    limit: int = TOP_MERCHANT_LIMIT,
) -> list[dict]:
    all_norms = set(spent_stats) | set(received_stats) | set(visit_totals)
    rows: list[dict] = []
    for norm in all_norms:
        visits = visit_totals.get(norm, {})
        spent = spent_stats.get(norm, {})
        received = received_stats.get(norm, {})
        display = max(
            (
                spent.get("display_name"),
                received.get("display_name"),
                visits.get("display_name"),
            ),
            key=lambda value: len(value or ""),
            default="Unknown",
        )
        spent_amount = spent.get("amount", 0.0)
        received_amount = received.get("amount", 0.0)
        amount = spent_amount if spent_amount > 0 else received_amount
        visit_count = visits.get("visit_count", 0)
        if visit_count <= 0:
            visit_count = spent.get("visit_count", 0) + received.get("visit_count", 0)
        if visit_count <= 0 and amount <= 0:
            continue
        rows.append(
            {
                "display_name": display or "Unknown",
                "merchant_normalized": norm,
                "amount": amount,
                "visit_count": visit_count,
            }
        )
    rows.sort(key=lambda item: item["visit_count"], reverse=True)
    return rows[:limit]


def _by_merchant_map(stats_by_norm: dict[str, dict]) -> dict[str, float]:
    return {data["display_name"]: data["amount"] for data in stats_by_norm.values()}


_BREAKDOWN_COLS = (
    Transaction.type,
    Transaction.category,
    Transaction.merchant,
    Transaction.merchant_normalized,
    func.sum(Transaction.amount),
    func.count(Transaction.id),
    func.max(Transaction.updated_at),
)
_BREAKDOWN_GROUP = (
    Transaction.type,
    Transaction.category,
    Transaction.merchant,
    Transaction.merchant_normalized,
)


def _summary_from_breakdown(
    rows: list,
    *,
    user: User,
    start: date,
    end: date,
    year_month: str = "",
) -> dict:
    """Assemble a summary payload from type/category/merchant grouped rows."""
    total_debit = Decimal("0")
    total_credit = Decimal("0")
    count = 0
    source_updated_at: datetime | None = None
    category_acc: dict[str, Decimal] = defaultdict(lambda: Decimal("0"))
    debit_merchant_rows: list[tuple[str | None, str | None, Decimal, int]] = []
    credit_merchant_rows: list[tuple[str | None, str | None, Decimal, int]] = []
    visit_rows: list[tuple[str | None, str | None, int]] = []

    for tx_type, category, merchant, normalized, amount_raw, visits, updated_at in rows:
        amount = as_money(amount_raw)
        visit_count = int(visits)
        count += visit_count
        if updated_at is not None and (
            source_updated_at is None or updated_at > source_updated_at
        ):
            source_updated_at = updated_at
        visit_rows.append((normalized, merchant, visit_count))
        if tx_type == TransactionType.debit:
            total_debit += amount
            category_acc[category or "Unknown"] += amount
            debit_merchant_rows.append((merchant, normalized, amount, visit_count))
        elif tx_type == TransactionType.credit:
            total_credit += amount
            credit_merchant_rows.append((merchant, normalized, amount, visit_count))

    spent_stats = _merchant_stats_by_norm(debit_merchant_rows)
    received_stats = _merchant_stats_by_norm(credit_merchant_rows)
    visit_totals = _visit_totals_by_norm(visit_rows)

    return {
        "year_month": year_month,
        "date_from": start.isoformat(),
        "date_to": end.isoformat(),
        "currency": user.default_currency,
        "total_debit": money_float(total_debit),
        "total_credit": money_float(total_credit),
        "net": money_float(total_credit - total_debit),
        "transaction_count": count,
        "source_updated_at": _iso_datetime(source_updated_at),
        "by_category": _amount_map(list(category_acc.items())),
        "top_merchants_spent": _top_merchants_from_stats(spent_stats),
        "top_merchants_received": _top_merchants_from_stats(received_stats),
        "top_merchants_by_visits": _top_merchants_by_visits(
            spent_stats,
            received_stats,
            visit_totals,
        ),
        "by_merchant": _by_merchant_map(spent_stats),
    }


async def _summary_for_range(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    year_month: str = "",
) -> dict:
    rows = list(
        (
            await session.execute(
                select(*_BREAKDOWN_COLS)
                .where(*_base_filters(user.id, start, end))
                .group_by(*_BREAKDOWN_GROUP)
            )
        ).all()
    )
    return _summary_from_breakdown(
        rows, user=user, start=start, end=end, year_month=year_month
    )


async def get_summary(session: AsyncSession, *, user: User, year_month: str) -> dict:
    parsed = parse_year_month(year_month)
    start, end = _month_bounds(parsed)
    return await _summary_for_range(
        session, user=user, start=start, end=end, year_month=parsed
    )


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
    month_rows = (
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
    year_months = [row[0] for row in month_rows]
    if not year_months:
        return []

    start, _ = _month_bounds(year_months[-1])
    _, end = _month_bounds(year_months[0])
    grouped = (
        await session.execute(
            select(month_col, *_BREAKDOWN_COLS)
            .where(
                *_base_filters(user.id, start, end),
                month_col.in_(year_months),
            )
            .group_by(month_col, *_BREAKDOWN_GROUP)
        )
    ).all()

    by_month: dict[str, list] = defaultdict(list)
    for row in grouped:
        by_month[row[0]].append(row[1:])

    summaries = []
    for year_month in year_months:
        month_start, month_end = _month_bounds(year_month)
        summaries.append(
            _summary_from_breakdown(
                by_month.get(year_month, []),
                user=user,
                start=month_start,
                end=month_end,
                year_month=year_month,
            )
        )
    return summaries
