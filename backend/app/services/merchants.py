"""Merchant summary, transaction list, and category overrides."""

from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import func, select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BadRequestError, NotFoundError
from app.db.models.enums import TransactionType
from app.db.models.merchant_override import MerchantCategoryOverride
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
    month_start = date.fromisoformat(f"{this_month}-01")
    merchant_filter = _merchant_filter(user.id, key)
    is_debit = Transaction.type == TransactionType.debit
    this_month_filter = Transaction.transaction_date >= month_start

    totals = (
        await session.execute(
            select(
                func.count(Transaction.id),
                func.coalesce(func.sum(Transaction.amount).filter(is_debit), 0),
                func.min(Transaction.merchant).filter(is_debit),
                func.min(Transaction.currency).filter(is_debit),
                func.coalesce(
                    func.sum(Transaction.amount).filter(is_debit & this_month_filter),
                    0,
                ),
                func.count(Transaction.id).filter(this_month_filter),
            ).where(*merchant_filter)
        )
    ).one()
    visit_count = int(totals[0])
    total_spent = as_money(totals[1])
    display_name = totals[2] or merchant_key
    currency = totals[3] or user.default_currency
    this_month_spent = as_money(totals[4])
    this_month_visits = int(totals[5])
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


def _normalized_key(merchant_key: str) -> str:
    key = normalize_merchant_key(merchant_key)
    if not key:
        raise BadRequestError("merchant_key is required.", code="merchant_required")
    return key


async def get_category_override(
    session: AsyncSession, *, user_id: uuid.UUID, merchant_key: str
) -> MerchantCategoryOverride:
    key = _normalized_key(merchant_key)
    result = await session.execute(
        select(MerchantCategoryOverride).where(
            MerchantCategoryOverride.user_id == user_id,
            MerchantCategoryOverride.merchant_key == key,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise NotFoundError(
            "No category override for this merchant.",
            code="override_not_found",
        )
    return row


async def upsert_category_override(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    merchant_key: str,
    category: str,
    display_name: str | None,
) -> MerchantCategoryOverride:
    key = _normalized_key(merchant_key)
    name = (display_name or merchant_key).strip() or key
    resolved_category = category.strip()
    if not resolved_category:
        raise BadRequestError("category is required.", code="category_required")

    result = await session.execute(
        select(MerchantCategoryOverride).where(
            MerchantCategoryOverride.user_id == user_id,
            MerchantCategoryOverride.merchant_key == key,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        row = MerchantCategoryOverride(
            user_id=user_id,
            merchant_key=key,
            display_name=name,
            category=resolved_category,
        )
        session.add(row)
    else:
        row.display_name = name
        row.category = resolved_category
    await session.commit()
    await session.refresh(row)
    return row


async def delete_category_override(
    session: AsyncSession, *, user_id: uuid.UUID, merchant_key: str
) -> None:
    key = _normalized_key(merchant_key)
    result = await session.execute(
        select(MerchantCategoryOverride).where(
            MerchantCategoryOverride.user_id == user_id,
            MerchantCategoryOverride.merchant_key == key,
        )
    )
    row = result.scalar_one_or_none()
    if row is not None:
        await session.delete(row)
        await session.commit()
