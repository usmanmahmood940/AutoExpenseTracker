"""CRUD + list/search for `transactions`. Port of `listTransactions` plus
the extra filters the Flutter client currently applies after the callable
returns, which SQL can do in one query.
"""

from __future__ import annotations

import re
import uuid
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import Select, and_, func, or_, select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BadRequestError, NotFoundError
from app.db.models.enums import (
    ExternalIdType,
    IngestionStatus,
    SortOrder,
    TransactionSortBy,
    TransactionStatus,
    TransactionType,
)
from app.db.models.raw_ingestion import RawIngestion
from app.db.models.transaction import Transaction
from app.db.seeds.categories import FALLBACK_CATEGORY_NAME
from app.services.merchant_key import normalize_merchant_key
from app.services.money import as_money, money_float

VISIBLE_STATUSES = (TransactionStatus.active, TransactionStatus.needs_review)
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_LIKE_SPECIAL = re.compile(r"([\\%_])")


def parse_iso_date(value: str, field_name: str) -> date:
    if not DATE_RE.match(value):
        raise BadRequestError(
            f"{field_name} must be a YYYY-MM-DD date.",
            code="invalid_date",
        )
    return date.fromisoformat(value)


def weekday_name(value: date) -> str:
    return value.strftime("%A")


def _escape_like(value: str) -> str:
    return _LIKE_SPECIAL.sub(r"\\\1", value)


def _empty_sms_source() -> dict[str, Any]:
    return {
        "raw": "",
        "source": "manual",
        "received_at": None,
        "message_id": None,
        "idempotency_key": None,
    }


def _visible(user_id: uuid.UUID) -> list[Any]:
    return [
        Transaction.user_id == user_id,
        Transaction.status.in_(VISIBLE_STATUSES),
    ]


async def get_owned(
    session: AsyncSession, *, user_id: uuid.UUID, transaction_id: uuid.UUID
) -> Transaction:
    result = await session.execute(
        select(Transaction).where(
            Transaction.id == transaction_id, Transaction.user_id == user_id
        )
    )
    tx = result.scalar_one_or_none()
    if tx is None:
        raise NotFoundError("Transaction not found.", code="transaction_not_found")
    return tx


def _apply_list_filters[T](
    stmt: Select[T],
    *,
    date_from: date | None,
    date_to: date | None,
    tx_type: TransactionType | None,
    category: str | None,
    bank: str | None,
    account_id_masked: str | None,
    merchant_query: str | None,
    amount_min: Decimal | None,
    amount_max: Decimal | None,
) -> Select[T]:
    if date_from is not None:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to is not None:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    if tx_type is not None:
        stmt = stmt.where(Transaction.type == tx_type)
    if category:
        stmt = stmt.where(Transaction.category == category)
    if bank:
        stmt = stmt.where(Transaction.bank == bank)
    if account_id_masked:
        stmt = stmt.where(Transaction.account_id_masked == account_id_masked)
    if merchant_query:
        escaped = _escape_like(merchant_query.strip())
        stmt = stmt.where(Transaction.merchant.ilike(f"%{escaped}%", escape="\\"))
    if amount_min is not None:
        stmt = stmt.where(Transaction.amount >= amount_min)
    if amount_max is not None:
        stmt = stmt.where(Transaction.amount <= amount_max)
    return stmt


def _order_clause(sort_by: TransactionSortBy, order_by: SortOrder):
    date_col = Transaction.transaction_date
    amount_col = Transaction.amount
    id_col = Transaction.id
    if sort_by is TransactionSortBy.amount:
        cols = (amount_col, date_col, id_col)
    else:
        cols = (date_col, id_col)
    if order_by is SortOrder.desc:
        return tuple(col.desc() for col in cols)
    return tuple(col.asc() for col in cols)


def _after_cursor(
    stmt: Select[tuple[Transaction]],
    cursor: Transaction,
    sort_by: TransactionSortBy,
    order_by: SortOrder,
) -> Select[tuple[Transaction]]:
    if sort_by is TransactionSortBy.amount:
        key = tuple_(Transaction.amount, Transaction.transaction_date, Transaction.id)
        cursor_key = (cursor.amount, cursor.transaction_date, cursor.id)
    else:
        key = tuple_(Transaction.transaction_date, Transaction.id)
        cursor_key = (cursor.transaction_date, cursor.id)
    if order_by is SortOrder.desc:
        return stmt.where(key < cursor_key)
    return stmt.where(key > cursor_key)


async def list_transactions(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    limit: int,
    cursor: uuid.UUID | None,
    sort_by: TransactionSortBy,
    order_by: SortOrder,
    include_aggregates: bool,
    date_from: date | None,
    date_to: date | None,
    tx_type: TransactionType | None,
    category: str | None,
    bank: str | None,
    account_id_masked: str | None,
    merchant_query: str | None,
    amount_min: Decimal | None,
    amount_max: Decimal | None,
) -> dict[str, Any]:
    if date_from and date_to and date_from > date_to:
        raise BadRequestError(
            "date_from must be on or before date_to.",
            code="invalid_date_range",
        )

    stmt = select(Transaction).where(*_visible(user_id))
    stmt = _apply_list_filters(
        stmt,
        date_from=date_from,
        date_to=date_to,
        tx_type=tx_type,
        category=category,
        bank=bank,
        account_id_masked=account_id_masked,
        merchant_query=merchant_query,
        amount_min=amount_min,
        amount_max=amount_max,
    )

    if cursor is not None:
        cursor_row = await get_owned(session, user_id=user_id, transaction_id=cursor)
        stmt = _after_cursor(stmt, cursor_row, sort_by, order_by)

    stmt = stmt.order_by(*_order_clause(sort_by, order_by)).limit(limit + 1)
    rows = list((await session.execute(stmt)).scalars().all())
    has_more = len(rows) > limit
    items = rows[:limit]
    next_cursor = str(items[-1].id) if has_more and items else None

    total_count: int | None = None
    total_amount: float | None = None
    if include_aggregates:
        agg = select(
            func.count(Transaction.id),
            func.coalesce(func.sum(Transaction.amount), 0),
        ).where(*_visible(user_id))
        agg = _apply_list_filters(
            agg,
            date_from=date_from,
            date_to=date_to,
            tx_type=tx_type,
            category=category,
            bank=bank,
            account_id_masked=account_id_masked,
            merchant_query=merchant_query,
            amount_min=amount_min,
            amount_max=amount_max,
        )
        count, total = (await session.execute(agg)).one()
        total_count = int(count)
        total_amount = money_float(total)

    return {
        "items": items,
        "next_cursor": next_cursor,
        "has_more": has_more,
        "total_count": total_count,
        "total_amount": total_amount,
        "sort_by": sort_by.value,
        "order_by": order_by.value,
        "date_from": date_from.isoformat() if date_from else None,
        "date_to": date_to.isoformat() if date_to else None,
    }


async def search_transactions(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    text: str,
    limit: int,
    cursor: uuid.UUID | None,
    date_from: date | None,
    date_to: date | None,
    tx_type: TransactionType | None,
    subscriptions_only: bool,
) -> dict[str, Any]:
    if date_from and date_to and date_from > date_to:
        raise BadRequestError(
            "date_from must be on or before date_to.",
            code="invalid_date_range",
        )

    needle = text.strip()
    use_prefix = (
        bool(needle)
        and not subscriptions_only
        and tx_type is None
        and date_from is None
        and date_to is None
    )
    prefix = normalize_merchant_key(needle) if use_prefix else ""

    stmt = select(Transaction).where(*_visible(user_id))
    if date_from is not None:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to is not None:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    if tx_type is not None:
        stmt = stmt.where(Transaction.type == tx_type)
    if subscriptions_only:
        stmt = stmt.where(Transaction.is_recurring.is_(True))

    if use_prefix:
        escaped = _escape_like(prefix)
        stmt = stmt.where(
            Transaction.merchant_normalized.like(escaped + "%", escape="\\")
        )
        order = (
            Transaction.merchant_normalized.asc(),
            Transaction.transaction_date.desc(),
            Transaction.id.desc(),
        )
    else:
        if needle:
            escaped = _escape_like(needle)
            pattern = f"%{escaped}%"
            stmt = stmt.where(
                or_(
                    Transaction.merchant.ilike(pattern, escape="\\"),
                    Transaction.merchant_normalized.ilike(pattern, escape="\\"),
                    Transaction.category.ilike(pattern, escape="\\"),
                    Transaction.bank.ilike(pattern, escape="\\"),
                )
            )
        order = (Transaction.transaction_date.desc(), Transaction.id.desc())

    if cursor is not None:
        cursor_row = await get_owned(session, user_id=user_id, transaction_id=cursor)
        if use_prefix:
            stmt = stmt.where(
                or_(
                    Transaction.merchant_normalized > cursor_row.merchant_normalized,
                    and_(
                        Transaction.merchant_normalized
                        == cursor_row.merchant_normalized,
                        tuple_(Transaction.transaction_date, Transaction.id)
                        < (cursor_row.transaction_date, cursor_row.id),
                    ),
                )
            )
        else:
            stmt = stmt.where(
                tuple_(Transaction.transaction_date, Transaction.id)
                < (cursor_row.transaction_date, cursor_row.id)
            )

    stmt = stmt.order_by(*order).limit(limit + 1)
    rows = list((await session.execute(stmt)).scalars().all())
    has_more = len(rows) > limit
    items = rows[:limit]
    return {
        "items": items,
        "next_cursor": str(items[-1].id) if has_more and items else None,
        "has_more": has_more,
    }


async def create_transaction(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    amount: Decimal,
    merchant: str,
    transaction_date: date,
    tx_type: TransactionType,
    category: str,
    currency: str,
    transaction_time: str,
    payment_method: str,
    bank: str,
    account_id: str,
    account_id_masked: str,
    merchant_details: str | None,
    branch: str | None,
    category_source: str,
    ingestion_id: uuid.UUID | None,
) -> Transaction:
    merchant = merchant.strip()
    if not merchant:
        raise BadRequestError("merchant is required.", code="merchant_required")

    tx_id = uuid.uuid4()
    tx = Transaction(
        id=tx_id,
        user_id=user_id,
        amount=as_money(amount),
        currency=currency.upper(),
        type=tx_type,
        merchant=merchant,
        merchant_details=merchant_details,
        merchant_normalized=normalize_merchant_key(merchant),
        category=category.strip() or FALLBACK_CATEGORY_NAME,
        category_source=category_source,
        payment_method=payment_method,
        bank=bank,
        account_id=account_id,
        account_id_masked=account_id_masked,
        branch=branch,
        transaction_time=transaction_time,
        transaction_date=transaction_date,
        day=weekday_name(transaction_date),
        external_id_type=ExternalIdType.unknown,
        dedup_key=f"manual_{tx_id}",
        sms_source=_empty_sms_source(),
        parse_confidence=Decimal("1"),
        is_auto_detected=False,
        is_edited=True,
        status=TransactionStatus.active,
        reviewed_at=datetime.now(UTC),
    )
    session.add(tx)
    await session.flush()

    if ingestion_id is not None:
        ingestion = await session.get(RawIngestion, ingestion_id)
        if ingestion is None or ingestion.user_id != user_id:
            raise NotFoundError("Ingestion not found.", code="ingestion_not_found")
        ingestion.status = IngestionStatus.parsed
        ingestion.transaction_id = tx_id
        tx.sms_source = {
            "raw": ingestion.raw,
            "source": ingestion.source.value,
            "received_at": ingestion.received_at.isoformat(),
            "message_id": ingestion.message_id,
            "idempotency_key": ingestion.idempotency_key,
        }

    await session.commit()
    await session.refresh(tx)
    return tx


async def update_transaction(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    transaction_id: uuid.UUID,
    updates: dict[str, Any],
) -> Transaction:
    tx = await get_owned(session, user_id=user_id, transaction_id=transaction_id)
    if tx.status is TransactionStatus.deleted:
        raise NotFoundError("Transaction not found.", code="transaction_not_found")

    if "amount" in updates and updates["amount"] is not None:
        tx.amount = as_money(updates["amount"])
    if "merchant" in updates and updates["merchant"] is not None:
        merchant = updates["merchant"].strip()
        if not merchant:
            raise BadRequestError("merchant is required.", code="merchant_required")
        tx.merchant = merchant
        tx.merchant_normalized = normalize_merchant_key(merchant)
    if "merchant_details" in updates:
        tx.merchant_details = updates["merchant_details"]
    if "category" in updates and updates["category"] is not None:
        tx.category = updates["category"].strip() or FALLBACK_CATEGORY_NAME
    if "type" in updates and updates["type"] is not None:
        tx.type = updates["type"]
    if "category_source" in updates and updates["category_source"] is not None:
        tx.category_source = updates["category_source"]
    if "payment_method" in updates and updates["payment_method"] is not None:
        tx.payment_method = updates["payment_method"]
    if "currency" in updates and updates["currency"] is not None:
        tx.currency = updates["currency"].upper()
    if "bank" in updates and updates["bank"] is not None:
        tx.bank = updates["bank"]
    if "account_id_masked" in updates and updates["account_id_masked"] is not None:
        tx.account_id_masked = updates["account_id_masked"]
    if "account_id" in updates and updates["account_id"] is not None:
        tx.account_id = updates["account_id"]
    if "transaction_time" in updates and updates["transaction_time"] is not None:
        tx.transaction_time = updates["transaction_time"]
    if "transaction_date" in updates and updates["transaction_date"] is not None:
        tx.transaction_date = updates["transaction_date"]
        tx.day = weekday_name(tx.transaction_date)
    if "day" in updates and updates["day"] is not None:
        tx.day = updates["day"]
    if "status" in updates and updates["status"] is not None:
        tx.status = updates["status"]

    tx.is_edited = True
    if "category_source" not in updates and (
        "category" in updates or "merchant" in updates
    ):
        tx.category_source = "user"

    await session.commit()
    await session.refresh(tx)
    return tx


async def soft_delete(
    session: AsyncSession, *, user_id: uuid.UUID, transaction_id: uuid.UUID
) -> None:
    tx = await get_owned(session, user_id=user_id, transaction_id=transaction_id)
    tx.status = TransactionStatus.deleted
    await session.commit()


async def mark_reviewed(
    session: AsyncSession, *, user_id: uuid.UUID, transaction_id: uuid.UUID
) -> Transaction:
    tx = await get_owned(session, user_id=user_id, transaction_id=transaction_id)
    if tx.status is TransactionStatus.deleted:
        raise NotFoundError("Transaction not found.", code="transaction_not_found")
    tx.reviewed_at = datetime.now(UTC)
    tx.status = TransactionStatus.active
    await session.commit()
    await session.refresh(tx)
    return tx
