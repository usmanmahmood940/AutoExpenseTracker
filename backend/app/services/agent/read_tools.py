"""Typed read tools — SQLAlchemy only; user_id from session, never LLM."""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal
from typing import Any

from sqlalchemy import Date, and_, cast, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.enums import TransactionStatus, TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.merchant_key import normalize_merchant_key
from app.services.money import as_money, money_float
from app.services.semantic import merchants_for_concepts, seed_known_merchant_concepts
from app.services.sql_like import contains_pattern
from app.services.transactions import LIST_STATUSES, SUMMABLE_STATUSES, get_owned

_DEFAULT_LIMIT = 20
_MAX_LIMIT = 50
_AGGREGATE_SAMPLE_LIMIT = 8


def _parse_date(value: str | None) -> date | None:
    if not value:
        return None
    return date.fromisoformat(value[:10])


def _status_list(raw: list[str] | None, *, default: tuple) -> list[TransactionStatus]:
    if not raw:
        return list(default)
    out: list[TransactionStatus] = []
    for item in raw:
        try:
            out.append(TransactionStatus(str(item).lower()))
        except ValueError:
            continue
    return out or list(default)


def _type_list(raw: list[str] | None) -> list[TransactionType] | None:
    if not raw:
        return None
    out: list[TransactionType] = []
    for item in raw:
        try:
            out.append(TransactionType(str(item).lower()))
        except ValueError:
            continue
    return out or None


def _tx_dict(tx: Transaction) -> dict[str, Any]:
    return {
        "transaction_id": str(tx.id),
        "date": tx.transaction_date.isoformat(),
        "amount": money_float(tx.amount),
        "currency": tx.currency,
        "type": tx.type.value if hasattr(tx.type, "value") else str(tx.type),
        "merchant": tx.merchant,
        "category": tx.category,
        "status": tx.status.value if hasattr(tx.status, "value") else str(tx.status),
        "updated_at": tx.updated_at.isoformat() if tx.updated_at else None,
        "original_amount": (
            money_float(tx.original_amount) if tx.original_amount is not None else None
        ),
        "merged_into_id": str(tx.merged_into_id) if tx.merged_into_id else None,
    }


async def _concept_merchants(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    concepts: list[str] | None,
    start: date | None,
    end: date | None,
) -> list[str]:
    if not concepts:
        return []
    await seed_known_merchant_concepts(session)
    await session.commit()
    return await merchants_for_concepts(
        session,
        user_id=user_id,
        concepts=concepts,
        date_from=start,
        date_to=end,
    )


async def query_transactions(
    session: AsyncSession,
    *,
    user: User,
    args: dict[str, Any],
) -> dict[str, Any]:
    start = _parse_date(args.get("date_from"))
    end = _parse_date(args.get("date_to"))
    statuses = _status_list(args.get("statuses"), default=LIST_STATUSES)
    types = _type_list(args.get("types"))
    limit = min(int(args.get("limit") or _DEFAULT_LIMIT), _MAX_LIMIT)
    concept_merchants = await _concept_merchants(
        session,
        user_id=user.id,
        concepts=args.get("concepts"),
        start=start,
        end=end,
    )
    merchants = list(args.get("merchants") or []) + concept_merchants
    categories = list(args.get("categories") or [])

    stmt = select(Transaction).where(
        Transaction.user_id == user.id,
        Transaction.status.in_(statuses),
    )
    if start is not None:
        stmt = stmt.where(Transaction.transaction_date >= start)
    if end is not None:
        stmt = stmt.where(Transaction.transaction_date <= end)
    if types:
        stmt = stmt.where(Transaction.type.in_(types))
    if merchants:
        keys = [normalize_merchant_key(m) for m in merchants]
        stmt = stmt.where(
            or_(
                Transaction.merchant.in_(merchants),
                Transaction.merchant_normalized.in_(keys),
                *[
                    Transaction.merchant.ilike(contains_pattern(m), escape="\\")
                    for m in merchants
                    if m
                ],
            )
        )
    if categories:
        stmt = stmt.where(Transaction.category.in_(categories))
    if args.get("min_amount") is not None:
        stmt = stmt.where(Transaction.amount >= as_money(args["min_amount"]))
    if args.get("max_amount") is not None:
        stmt = stmt.where(Transaction.amount <= as_money(args["max_amount"]))

    sort = str(args.get("sort") or "date_desc")
    if sort == "amount_desc":
        stmt = stmt.order_by(Transaction.amount.desc())
    elif sort == "amount_asc":
        stmt = stmt.order_by(Transaction.amount.asc())
    elif sort == "date_asc":
        stmt = stmt.order_by(Transaction.transaction_date.asc())
    else:
        stmt = stmt.order_by(Transaction.transaction_date.desc())

    rows = list((await session.execute(stmt.limit(limit))).scalars())
    return {
        "count": len(rows),
        "transactions": [_tx_dict(tx) for tx in rows],
    }


async def aggregate_spending(
    session: AsyncSession,
    *,
    user: User,
    args: dict[str, Any],
) -> dict[str, Any]:
    start = _parse_date(args.get("date_from"))
    end = _parse_date(args.get("date_to"))
    if start is None or end is None:
        return {"error": "date_from and date_to are required"}
    statuses = _status_list(args.get("statuses"), default=SUMMABLE_STATUSES)
    types = _type_list(args.get("types")) or [TransactionType.debit]
    group_by = str(args.get("group_by") or "merchant").lower()
    concept_merchants = await _concept_merchants(
        session,
        user_id=user.id,
        concepts=args.get("concepts"),
        start=start,
        end=end,
    )
    merchants = list(args.get("merchants") or []) + concept_merchants
    categories = list(args.get("categories") or [])

    filters = [
        Transaction.user_id == user.id,
        Transaction.status.in_(statuses),
        Transaction.transaction_date >= start,
        Transaction.transaction_date <= end,
        Transaction.type.in_(types),
    ]
    if merchants:
        keys = [normalize_merchant_key(m) for m in merchants]
        filters.append(
            or_(
                Transaction.merchant.in_(merchants),
                Transaction.merchant_normalized.in_(keys),
            )
        )
    if categories:
        filters.append(Transaction.category.in_(categories))

    if group_by == "category":
        group_col = Transaction.category
    elif group_by == "month":
        group_col = func.to_char(Transaction.transaction_date, "YYYY-MM")
    elif group_by == "day":
        group_col = cast(Transaction.transaction_date, Date)
    else:
        group_col = Transaction.merchant
        group_by = "merchant"

    rows = (
        await session.execute(
            select(
                group_col.label("bucket"),
                func.coalesce(func.sum(Transaction.amount), 0),
                func.count(Transaction.id),
            )
            .where(*filters)
            .group_by(group_col)
            .order_by(func.coalesce(func.sum(Transaction.amount), 0).desc())
            .limit(40)
        )
    ).all()

    groups = []
    grand = Decimal("0")
    count = 0
    for bucket, total, visits in rows:
        money = as_money(total)
        grand += money
        count += int(visits)
        groups.append(
            {
                "key": bucket.isoformat() if hasattr(bucket, "isoformat") else str(bucket),
                "total": money_float(money),
                "transaction_count": int(visits),
            }
        )

    # Same filters as the total so Related transactions match debit vs credit.
    sample_rows = list(
        (
            await session.execute(
                select(Transaction)
                .where(*filters)
                .order_by(Transaction.transaction_date.desc(), Transaction.amount.desc())
                .limit(_AGGREGATE_SAMPLE_LIMIT)
            )
        ).scalars()
    )

    return {
        "date_from": start.isoformat(),
        "date_to": end.isoformat(),
        "group_by": group_by,
        "currency": user.default_currency,
        "grand_total": money_float(grand),
        "transaction_count": count,
        "groups": groups,
        "filter_merchants": merchants,
        "filter_concepts": list(args.get("concepts") or []),
        "filter_types": [t.value for t in types],
        "transactions": [_tx_dict(tx) for tx in sample_rows],
    }


async def list_settlements(
    session: AsyncSession,
    *,
    user: User,
    args: dict[str, Any],
) -> dict[str, Any]:
    start = _parse_date(args.get("date_from"))
    end = _parse_date(args.get("date_to"))
    if start is None or end is None:
        return {"error": "date_from and date_to are required"}
    limit = min(int(args.get("limit") or 20), _MAX_LIMIT)
    in_window = or_(
        and_(
            Transaction.transaction_date >= start,
            Transaction.transaction_date <= end,
        ),
        and_(
            cast(Transaction.updated_at, Date) >= start,
            cast(Transaction.updated_at, Date) <= end,
        ),
    )
    rows = list(
        (
            await session.execute(
                select(Transaction)
                .where(
                    Transaction.user_id == user.id,
                    Transaction.status == TransactionStatus.settled,
                    in_window,
                )
                .order_by(Transaction.updated_at.desc())
                .limit(limit)
            )
        ).scalars()
    )
    return {"count": len(rows), "settlements": [_tx_dict(tx) for tx in rows]}


async def get_transaction(
    session: AsyncSession,
    *,
    user: User,
    args: dict[str, Any],
) -> dict[str, Any]:
    raw = str(args.get("transaction_id") or "").strip()
    try:
        tid = uuid.UUID(raw)
    except ValueError:
        return {"error": "invalid transaction_id"}
    try:
        tx = await get_owned(session, user_id=user.id, transaction_id=tid)
    except Exception as exc:
        return {"error": str(getattr(exc, "code", None) or exc)}
    return {"transaction": _tx_dict(tx)}


async def search_transaction_candidates(
    session: AsyncSession,
    *,
    user: User,
    args: dict[str, Any],
) -> dict[str, Any]:
    query = str(args.get("query") or "").strip()
    if not query:
        return {"candidates": [], "ambiguous": False}
    start = _parse_date(args.get("date_from"))
    end = _parse_date(args.get("date_to"))
    limit = min(int(args.get("limit") or 8), _MAX_LIMIT)
    concept_merchants = await _concept_merchants(
        session,
        user_id=user.id,
        concepts=args.get("concepts"),
        start=start,
        end=end,
    )
    pattern = contains_pattern(query)
    match_clauses = [
        Transaction.merchant.ilike(pattern, escape="\\"),
        Transaction.merchant_normalized.ilike(pattern, escape="\\"),
        Transaction.category.ilike(pattern, escape="\\"),
    ]
    if concept_merchants:
        match_clauses.append(Transaction.merchant.in_(concept_merchants))
    stmt = select(Transaction).where(
        Transaction.user_id == user.id,
        Transaction.status.in_(LIST_STATUSES),
        or_(*match_clauses),
    )
    if start is not None:
        stmt = stmt.where(Transaction.transaction_date >= start)
    if end is not None:
        stmt = stmt.where(Transaction.transaction_date <= end)
    tx_type = args.get("type")
    if tx_type:
        try:
            stmt = stmt.where(Transaction.type == TransactionType(str(tx_type).lower()))
        except ValueError:
            pass
    rows = list(
        (
            await session.execute(
                stmt.order_by(Transaction.transaction_date.desc()).limit(limit)
            )
        ).scalars()
    )
    return {
        "candidates": [_tx_dict(tx) for tx in rows],
        "ambiguous": len(rows) > 1,
        "count": len(rows),
    }


READ_HANDLERS = {
    "query_transactions": query_transactions,
    "aggregate_spending": aggregate_spending,
    "list_settlements": list_settlements,
    "get_transaction": get_transaction,
    "search_transaction_candidates": search_transaction_candidates,
}
