"""SQL spending signals for suggested questions and smart cards."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import Decimal
from statistics import median

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.enums import TransactionStatus, TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services import analytics as analytics_service
from app.services.money import as_money, money_float

CATEGORY_SPIKE_RATIO = Decimal("1.3")
MERCHANT_SHARE = Decimal("0.25")
WEEKEND_RATIO = Decimal("1.5")
LARGE_ONE_OFF_RATIO = Decimal("2")
MIN_DEBITS_FOR_MEDIAN = 3
TRAILING_WINDOWS = 3


@dataclass
class SpendingSignal:
    signal_type: str
    severity: float
    params: dict = field(default_factory=dict)
    suggested_question: str = ""


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def _shift_range(start: date, end: date, *, windows_back: int) -> tuple[date, date]:
    span = (end - start).days + 1
    shifted_end = start - timedelta(days=1 + (windows_back - 1) * span)
    shifted_start = shifted_end - timedelta(days=span - 1)
    return shifted_start, shifted_end


async def detect_signals(
    session: AsyncSession,
    *,
    user: User,
    date_from: str,
    date_to: str,
) -> list[SpendingSignal]:
    start, end = analytics_service.parse_range(date_from, date_to)
    current = await analytics_service.get_range_summary(
        session, user=user, date_from=date_from, date_to=date_to
    )
    if int(current.get("transaction_count") or 0) == 0:
        return []

    signals: list[SpendingSignal] = []
    signals.extend(
        await _category_spikes(
            session, user=user, start=start, end=end, current=current
        )
    )
    signals.extend(await _new_recurring(session, user=user, start=start, end=end))
    signals.extend(_merchant_concentration(current))
    signals.extend(await _weekend_skew(session, user=user, start=start, end=end))
    signals.extend(await _large_one_off(session, user=user, start=start, end=end))
    signals.extend(
        await _net_negative_swing(
            session, user=user, start=start, end=end, current=current
        )
    )
    signals.sort(key=lambda item: item.severity, reverse=True)
    return signals


async def _category_spikes(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    current: dict,
) -> list[SpendingSignal]:
    categories = current.get("by_category") or {}
    if not categories:
        return []
    trailing: list[dict] = []
    for window in range(1, TRAILING_WINDOWS + 1):
        prior_start, prior_end = _shift_range(start, end, windows_back=window)
        trailing.append(
            await analytics_service.get_range_summary(
                session,
                user=user,
                date_from=prior_start.isoformat(),
                date_to=prior_end.isoformat(),
            )
        )
    out: list[SpendingSignal] = []
    for name, amount in categories.items():
        prior_amounts = [
            Decimal(str((item.get("by_category") or {}).get(name, 0)))
            for item in trailing
        ]
        avg = sum(prior_amounts, Decimal("0")) / TRAILING_WINDOWS
        current_amount = Decimal(str(amount))
        if avg <= 0 or current_amount <= avg * CATEGORY_SPIKE_RATIO:
            continue
        ratio = float(current_amount / avg) if avg else 0.0
        pct = round((ratio - 1) * 100)
        out.append(
            SpendingSignal(
                signal_type="category_spike",
                severity=_clamp((ratio - 1.3) / 1.3),
                params={
                    "category": name,
                    "amount": money_float(current_amount),
                    "average": money_float(avg),
                    "percent": pct,
                },
                suggested_question=f"Why did {name} spending jump this period?",
            )
        )
    return out


async def _new_recurring(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
) -> list[SpendingSignal]:
    recurring = await analytics_service.list_recurring(
        session,
        user=user,
        date_from=start.isoformat(),
        date_to=end.isoformat(),
    )
    out: list[SpendingSignal] = []
    for item in recurring.get("items") or []:
        key = item["merchant_normalized"]
        first = (
            await session.execute(
                select(func.min(Transaction.transaction_date)).where(
                    Transaction.user_id == user.id,
                    Transaction.merchant_normalized == key,
                    Transaction.status != TransactionStatus.deleted,
                    Transaction.type == TransactionType.debit,
                )
            )
        ).scalar_one()
        if first is None or first < start or first > end:
            continue
        out.append(
            SpendingSignal(
                signal_type="new_recurring",
                severity=0.7,
                params={
                    "merchant": item["display_name"],
                    "merchant_normalized": key,
                    "count": item["count"],
                    "average_amount": item["average_amount"],
                },
                suggested_question=(
                    f"Is {item['display_name']} a new recurring payment?"
                ),
            )
        )
    return out


def _merchant_concentration(current: dict) -> list[SpendingSignal]:
    total = Decimal(str(current.get("total_debit") or 0))
    if total <= 0:
        return []
    out: list[SpendingSignal] = []
    for item in current.get("top_merchants_spent") or []:
        amount = Decimal(str(item.get("amount") or 0))
        if amount <= total * MERCHANT_SHARE:
            continue
        share = float(amount / total)
        out.append(
            SpendingSignal(
                signal_type="merchant_concentration",
                severity=_clamp((share - 0.25) / 0.75),
                params={
                    "merchant": item["display_name"],
                    "merchant_normalized": item["merchant_normalized"],
                    "amount": money_float(amount),
                    "share": round(share, 4),
                },
                suggested_question=(
                    f"Why is so much of my spend at {item['display_name']}?"
                ),
            )
        )
    return out


async def _weekend_skew(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
) -> list[SpendingSignal]:
    rows = (
        await session.execute(
            select(Transaction.transaction_date, func.sum(Transaction.amount))
            .where(
                Transaction.user_id == user.id,
                Transaction.status != TransactionStatus.deleted,
                Transaction.type == TransactionType.debit,
                Transaction.transaction_date >= start,
                Transaction.transaction_date <= end,
            )
            .group_by(Transaction.transaction_date)
        )
    ).all()
    by_day = {row[0]: as_money(row[1]) for row in rows}
    weekend: list[Decimal] = []
    weekday: list[Decimal] = []
    cursor = start
    while cursor <= end:
        amount = by_day.get(cursor, Decimal("0"))
        if cursor.weekday() >= 4:
            weekend.append(amount)
        else:
            weekday.append(amount)
        cursor += timedelta(days=1)
    if not weekend or not weekday:
        return []
    weekend_avg = sum(weekend, Decimal("0")) / len(weekend)
    weekday_avg = sum(weekday, Decimal("0")) / len(weekday)
    if weekday_avg <= 0 or weekend_avg <= weekday_avg * WEEKEND_RATIO:
        return []
    ratio = float(weekend_avg / weekday_avg)
    return [
        SpendingSignal(
            signal_type="weekend_skew",
            severity=_clamp((ratio - 1.5) / 1.5),
            params={
                "weekend_average": money_float(weekend_avg),
                "weekday_average": money_float(weekday_avg),
                "ratio": round(ratio, 3),
            },
            suggested_question=(
                "Why is my weekend spending so high compared to weekdays?"
            ),
        )
    ]


async def _large_one_off(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
) -> list[SpendingSignal]:
    amounts = list(
        (
            await session.execute(
                select(Transaction.amount).where(
                    Transaction.user_id == user.id,
                    Transaction.status != TransactionStatus.deleted,
                    Transaction.type == TransactionType.debit,
                )
            )
        ).scalars()
    )
    if len(amounts) < MIN_DEBITS_FOR_MEDIAN:
        return []
    med = Decimal(str(median([as_money(value) for value in amounts])))
    if med <= 0:
        return []
    threshold = med * LARGE_ONE_OFF_RATIO
    rows = (
        await session.execute(
            select(
                Transaction.id,
                Transaction.merchant,
                Transaction.amount,
                Transaction.transaction_date,
                Transaction.category,
            )
            .where(
                Transaction.user_id == user.id,
                Transaction.status != TransactionStatus.deleted,
                Transaction.type == TransactionType.debit,
                Transaction.transaction_date >= start,
                Transaction.transaction_date <= end,
                Transaction.amount > threshold,
            )
            .order_by(Transaction.amount.desc())
            .limit(3)
        )
    ).all()
    out: list[SpendingSignal] = []
    for tx_id, merchant, amount, tx_date, category in rows:
        money = as_money(amount)
        ratio = float(money / med)
        out.append(
            SpendingSignal(
                signal_type="large_one_off",
                severity=_clamp((ratio - 2) / 4),
                params={
                    "transaction_id": str(tx_id),
                    "merchant": merchant,
                    "amount": money_float(money),
                    "date": tx_date.isoformat(),
                    "category": category,
                    "median": money_float(med),
                },
                suggested_question=(
                    f"What was the large {merchant} payment on {tx_date.isoformat()}?"
                ),
            )
        )
    return out


async def _net_negative_swing(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    current: dict,
) -> list[SpendingSignal]:
    prior_start, prior_end = _shift_range(start, end, windows_back=1)
    prior = await analytics_service.get_range_summary(
        session,
        user=user,
        date_from=prior_start.isoformat(),
        date_to=prior_end.isoformat(),
    )
    if int(prior.get("transaction_count") or 0) == 0:
        return []
    current_net = Decimal(str(current.get("net") or 0))
    prior_net = Decimal(str(prior.get("net") or 0))
    if current_net >= prior_net:
        return []
    delta = prior_net - current_net
    denom = abs(prior_net) + Decimal("1")
    return [
        SpendingSignal(
            signal_type="net_negative_swing",
            severity=_clamp(float(delta / denom)),
            params={
                "net": money_float(current_net),
                "prior_net": money_float(prior_net),
                "delta": money_float(delta),
            },
            suggested_question="Why did my net cash flow get worse this period?",
        )
    ]
