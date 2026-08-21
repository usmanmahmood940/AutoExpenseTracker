"""Merchant summary + transaction list. Port of FirestoreMerchantDatasource."""

from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import func, select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.enums import TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.merchant_key import normalize_merchant_key
from app.services.money import as_money, money_float
from app.services.transactions import VISIBLE_STATUSES, get_owned


def _merchant_filter(user_id: uuid.UUID, key: str):
    return (
        Transaction.user_id == user_id,
        Transaction.status.in_(VISIBLE_STATUSES),
        Transaction.merchant_normalized == key,
    )


async def get_merchant_summary(
    session: AsyncSession, *, user: User, merchant_key: str
) -> dict:
    key = normalize_merchant_key(merchant_key)
    this_month = date.today().strftime("%Y-%m")

    debit = (
        *_merchant_filter(user.id, key),
        Transaction.type == TransactionType.debit,
    )

    totals = (
        await session.execute(
            select(
                func.coalesce(func.sum(Transaction.amount), 0),
                func.count(Transaction.id),
                func.min(Transaction.merchant),
                func.min(Transaction.currency),
            ).where(*debit)
        )
    ).one()
    total_spent = as_money(totals[0])
    visit_count = int(totals[1])
    display_name = totals[2] or merchant_key
    currency = totals[3] or user.default_currency

    month_start = date.fromisoformat(f"{this_month}-01")
    month_totals = (
        await session.execute(
            select(
                func.coalesce(func.sum(Transaction.amount), 0),
                func.count(Transaction.id),
            ).where(*debit, Transaction.transaction_date >= month_start)
        )
    ).one()
    this_month_spent = as_money(month_totals[0])
    this_month_visits = int(month_totals[1])
    average = money_float(total_spent / visit_count) if visit_count else 0.0

    return {
        "merchant_normalized": key,
        "display_name": display_name,
        "currency": currency,
        "total_spent": money_float(total_spent),
        "visit_count": visit_count,
        "average_spent": average,
        "this_month_spent": money_float(this_month_spent),
        "this_month_visits": this_month_visits,
    }


async def list_merchant_transactions(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    merchant_key: str,
    limit: int,
    cursor: uuid.UUID | None,
) -> dict:
    key = normalize_merchant_key(merchant_key)
    stmt = (
        select(Transaction)
        .where(*_merchant_filter(user_id, key))
        .order_by(Transaction.transaction_date.desc(), Transaction.id.desc())
    )
    if cursor is not None:
        cursor_row = await get_owned(session, user_id=user_id, transaction_id=cursor)
        stmt = stmt.where(
            tuple_(Transaction.transaction_date, Transaction.id)
            < (cursor_row.transaction_date, cursor_row.id)
        )
    stmt = stmt.limit(limit + 1)
    rows = list((await session.execute(stmt)).scalars().all())
    has_more = len(rows) > limit
    items = rows[:limit]
    return {
        "items": items,
        "next_cursor": str(items[-1].id) if has_more and items else None,
        "has_more": has_more,
    }
