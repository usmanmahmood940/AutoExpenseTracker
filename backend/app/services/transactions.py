"""CRUD + list/search for `transactions`. Port of `listTransactions` plus
the extra filters the Flutter client currently applies after the callable
returns, which SQL can do in one query.
"""

from __future__ import annotations

import logging
import re
import uuid
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import Select, func, or_, select, tuple_
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
from app.services.merchant_key import normalize_merchant_key, resolve_merchant
from app.services.money import as_money, money_float
from app.services.sms_source import build_sms_source, decrypt_ingestion_raw
from app.services.sql_like import contains_pattern

logger = logging.getLogger(__name__)

# Shown in home/search/merchant lists (includes absorbed merge rows).
LIST_STATUSES = (
    TransactionStatus.active,
    TransactionStatus.needs_review,
    TransactionStatus.settled,
    TransactionStatus.merged,
)
# Included in spend/receive totals, analytics, period stats, Ask SQL.
SUMMABLE_STATUSES = (
    TransactionStatus.active,
    TransactionStatus.needs_review,
    TransactionStatus.settled,
)
# Back-compat alias for callers that still import VISIBLE_STATUSES.
VISIBLE_STATUSES = LIST_STATUSES
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def parse_iso_date(value: str, field_name: str) -> date:
    if not DATE_RE.match(value):
        raise BadRequestError(
            f"{field_name} must be a YYYY-MM-DD date.",
            code="invalid_date",
        )
    return date.fromisoformat(value)


def weekday_name(value: date) -> str:
    return value.strftime("%A")


def _visible(user_id: uuid.UUID) -> list[Any]:
    return [
        Transaction.user_id == user_id,
        Transaction.status.in_(LIST_STATUSES),
    ]


def _summable(user_id: uuid.UUID) -> list[Any]:
    return [
        Transaction.user_id == user_id,
        Transaction.status.in_(SUMMABLE_STATUSES),
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
        stmt = stmt.where(
            Transaction.merchant.ilike(
                contains_pattern(merchant_query.strip()), escape="\\"
            )
        )
    if amount_min is not None:
        stmt = stmt.where(Transaction.amount >= amount_min)
    if amount_max is not None:
        stmt = stmt.where(Transaction.amount <= amount_max)
    return stmt


def _sort_key_columns(sort_by: TransactionSortBy):
    date_col = Transaction.transaction_date
    id_col = Transaction.id
    if sort_by is TransactionSortBy.amount:
        return (Transaction.amount, date_col, id_col)
    if sort_by is TransactionSortBy.merchant:
        return (Transaction.merchant_normalized, date_col, id_col)
    return (date_col, id_col)


def _cursor_key(cursor: Transaction, sort_by: TransactionSortBy):
    if sort_by is TransactionSortBy.amount:
        return (cursor.amount, cursor.transaction_date, cursor.id)
    if sort_by is TransactionSortBy.merchant:
        return (cursor.merchant_normalized, cursor.transaction_date, cursor.id)
    return (cursor.transaction_date, cursor.id)


def _order_clause(sort_by: TransactionSortBy, order_by: SortOrder):
    cols = _sort_key_columns(sort_by)
    if order_by is SortOrder.desc:
        return tuple(col.desc() for col in cols)
    return tuple(col.asc() for col in cols)


def _apply_search_filters[T](
    stmt: Select[T],
    *,
    needle: str,
    date_from: date | None,
    date_to: date | None,
    tx_type: TransactionType | None,
    subscriptions_only: bool,
    category_names: list[str],
    amount_min: Decimal | None,
    amount_max: Decimal | None,
    payment_methods: list[str],
    sources: list[str],
) -> Select[T]:
    if date_from is not None:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to is not None:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    if tx_type is not None:
        stmt = stmt.where(Transaction.type == tx_type)
    if subscriptions_only:
        stmt = stmt.where(Transaction.is_recurring.is_(True))
    if category_names:
        stmt = stmt.where(Transaction.category.in_(category_names))
    if amount_min is not None:
        stmt = stmt.where(Transaction.amount >= amount_min)
    if amount_max is not None:
        stmt = stmt.where(Transaction.amount <= amount_max)
    if payment_methods:
        stmt = stmt.where(Transaction.payment_method.in_(payment_methods))
    if sources:
        source_col = func.coalesce(
            Transaction.sms_source.op("->>")("source"),
            "manual",
        )
        stmt = stmt.where(source_col.in_(sources))

    if needle:
        raw_pattern = contains_pattern(needle.strip())
        norm_pattern = contains_pattern(normalize_merchant_key(needle))
        stmt = stmt.where(
            or_(
                Transaction.merchant.ilike(raw_pattern, escape="\\"),
                Transaction.merchant_normalized.ilike(norm_pattern, escape="\\"),
                Transaction.merchant_details.ilike(raw_pattern, escape="\\"),
                Transaction.category.ilike(raw_pattern, escape="\\"),
            )
        )
    return stmt


def _after_cursor(
    stmt: Select[tuple[Transaction]],
    cursor: Transaction,
    sort_by: TransactionSortBy,
    order_by: SortOrder,
) -> Select[tuple[Transaction]]:
    key = tuple_(*_sort_key_columns(sort_by))
    cursor_key = _cursor_key(cursor, sort_by)
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
        count_stmt = select(func.count(Transaction.id)).where(*_visible(user_id))
        count_stmt = _apply_list_filters(
            count_stmt,
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
        sum_stmt = select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            *_summable(user_id)
        )
        sum_stmt = _apply_list_filters(
            sum_stmt,
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
        total_count = int((await session.execute(count_stmt)).scalar_one())
        total_amount = money_float((await session.execute(sum_stmt)).scalar_one())

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
    categories: list[str] | None = None,
    amount_min: Decimal | None = None,
    amount_max: Decimal | None = None,
    payment_methods: list[str] | None = None,
    sources: list[str] | None = None,
    include_aggregates: bool = False,
    sort_by: TransactionSortBy = TransactionSortBy.date,
    order_by: SortOrder = SortOrder.desc,
) -> dict[str, Any]:
    if date_from and date_to and date_from > date_to:
        raise BadRequestError(
            "date_from must be on or before date_to.",
            code="invalid_date_range",
        )
    if amount_min is not None and amount_max is not None and amount_min > amount_max:
        raise BadRequestError(
            "amount_min must be on or before amount_max.",
            code="invalid_amount_range",
        )

    needle = text.strip()
    category_names = [name for name in (categories or []) if name]
    methods = [name for name in (payment_methods or []) if name]
    source_names = [name for name in (sources or []) if name]
    filter_kwargs = {
        "needle": needle,
        "date_from": date_from,
        "date_to": date_to,
        "tx_type": tx_type,
        "subscriptions_only": subscriptions_only,
        "category_names": category_names,
        "amount_min": amount_min,
        "amount_max": amount_max,
        "payment_methods": methods,
        "sources": source_names,
    }

    stmt = select(Transaction).where(*_visible(user_id))
    stmt = _apply_search_filters(stmt, **filter_kwargs)

    if cursor is not None:
        cursor_row = await get_owned(session, user_id=user_id, transaction_id=cursor)
        stmt = _after_cursor(stmt, cursor_row, sort_by, order_by)

    stmt = stmt.order_by(*_order_clause(sort_by, order_by)).limit(limit + 1)
    rows = list((await session.execute(stmt)).scalars().all())
    has_more = len(rows) > limit
    items = rows[:limit]

    total_count: int | None = None
    total_spent: float | None = None
    total_received: float | None = None
    if include_aggregates:
        count_stmt = select(func.count(Transaction.id)).where(*_visible(user_id))
        count_stmt = _apply_search_filters(count_stmt, **filter_kwargs)
        sum_stmt = select(
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
        ).where(*_summable(user_id))
        sum_stmt = _apply_search_filters(sum_stmt, **filter_kwargs)
        total_count = int((await session.execute(count_stmt)).scalar_one())
        spent, received = (await session.execute(sum_stmt)).one()
        total_spent = money_float(spent)
        total_received = money_float(received)

    return {
        "items": items,
        "next_cursor": str(items[-1].id) if has_more and items else None,
        "has_more": has_more,
        "total_count": total_count,
        "total_spent": total_spent,
        "total_received": total_received,
        "sort_by": sort_by.value,
        "order_by": order_by.value,
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
    note: str | None = None,
) -> Transaction:
    merchant = resolve_merchant(
        merchant.strip(),
        category=category,
        payment_method=payment_method,
    )
    if not merchant:
        raise BadRequestError("merchant is required.", code="merchant_required")

    tx_id = uuid.uuid4()
    sms_source = build_sms_source(
        raw_plaintext=note.strip() if note and note.strip() else "",
        source="manual",
        user_id=user_id,
    )

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
        sms_source=sms_source,
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
        tx.sms_source = build_sms_source(
            raw_plaintext=decrypt_ingestion_raw(ingestion.raw, user_id=user_id),
            source=ingestion.source.value,
            user_id=user_id,
            received_at=ingestion.received_at,
            message_id=ingestion.message_id,
            idempotency_key=ingestion.idempotency_key,
        )

    await session.commit()
    await session.refresh(tx)
    await _index_after_commit(session, user_id=user_id, transaction_id=tx.id)
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
    if tx.status is TransactionStatus.merged:
        raise BadRequestError(
            "Unmerge this transaction before editing it.",
            code="merged_locked",
        )
    if tx.status is TransactionStatus.settled and "amount" in updates:
        raise BadRequestError(
            "Unsettle this transaction before changing its amount.",
            code="settled_amount_locked",
        )
    # Never let PATCH clobber settle/merge lifecycle statuses.
    if "status" in updates and updates["status"] is not None:
        requested = updates["status"]
        if isinstance(requested, str):
            requested = TransactionStatus(requested)
        if tx.status in (TransactionStatus.settled, TransactionStatus.merged):
            if requested is not tx.status:
                raise BadRequestError(
                    "Use settle/unsettle/unmerge endpoints to change this status.",
                    code="status_locked",
                )
        if requested in (TransactionStatus.settled, TransactionStatus.merged):
            raise BadRequestError(
                "Use settle/unsettle/unmerge endpoints to change this status.",
                code="status_locked",
            )

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

    resolved_merchant = resolve_merchant(
        tx.merchant,
        category=tx.category,
        payment_method=tx.payment_method,
    )
    if resolved_merchant != tx.merchant:
        tx.merchant = resolved_merchant
        tx.merchant_normalized = normalize_merchant_key(resolved_merchant)

    tx.is_edited = True
    if "category_source" not in updates and (
        "category" in updates or "merchant" in updates
    ):
        tx.category_source = "user"

    await session.commit()
    await session.refresh(tx)
    await _index_after_commit(session, user_id=user_id, transaction_id=tx.id)
    return tx


async def soft_delete(
    session: AsyncSession, *, user_id: uuid.UUID, transaction_id: uuid.UUID
) -> None:
    tx = await get_owned(session, user_id=user_id, transaction_id=transaction_id)
    if tx.status is TransactionStatus.settled:
        raise BadRequestError(
            "Unsettle this transaction before deleting it.",
            code="settled_locked",
        )
    if tx.status is TransactionStatus.merged:
        raise BadRequestError(
            "Unmerge this transaction before deleting it.",
            code="merged_locked",
        )
    tx.status = TransactionStatus.deleted
    await session.commit()
    await _index_after_commit(
        session, user_id=user_id, transaction_id=transaction_id, deleted=True
    )


async def mark_reviewed(
    session: AsyncSession, *, user_id: uuid.UUID, transaction_id: uuid.UUID
) -> Transaction:
    tx = await get_owned(session, user_id=user_id, transaction_id=transaction_id)
    if tx.status is TransactionStatus.deleted:
        raise NotFoundError("Transaction not found.", code="transaction_not_found")
    if tx.status in (TransactionStatus.settled, TransactionStatus.merged):
        raise BadRequestError(
            "Cannot mark a settled or merged transaction as reviewed.",
            code="status_locked",
        )
    tx.reviewed_at = datetime.now(UTC)
    tx.status = TransactionStatus.active
    await session.commit()
    await session.refresh(tx)
    await _index_after_commit(session, user_id=user_id, transaction_id=tx.id)
    return tx


def _source_contribution(tx: Transaction) -> Decimal:
    """How much this source reduces the primary amount (credits reduce, debits increase)."""
    amount = as_money(tx.amount)
    if tx.type is TransactionType.credit:
        return amount
    return -amount


def _groups_list(primary: Transaction) -> list[dict[str, Any]]:
    raw = primary.settlement_groups
    if not raw:
        return []
    return [dict(item) for item in raw]


def _clear_primary_settlement(primary: Transaction) -> None:
    primary.status = TransactionStatus.active
    primary.original_amount = None
    primary.settlement_groups = None


def _apply_remaining_groups(primary: Transaction, groups: list[dict[str, Any]]) -> None:
    if not groups:
        base = as_money(
            primary.original_amount
            if primary.original_amount is not None
            else primary.amount
        )
        primary.amount = base
        _clear_primary_settlement(primary)
        return
    base = as_money(
        primary.original_amount if primary.original_amount is not None else primary.amount
    )
    applied = sum(
        (as_money(group.get("amountApplied") or 0) for group in groups),
        Decimal("0"),
    )
    primary.amount = as_money(base - applied)
    primary.settlement_groups = groups
    primary.status = TransactionStatus.settled


async def settle(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    primary_id: uuid.UUID,
    source_ids: list[uuid.UUID],
) -> Transaction:
    if not source_ids:
        raise BadRequestError(
            "Select at least one transaction to settle.",
            code="settle_sources_required",
        )
    unique_sources = list(dict.fromkeys(source_ids))
    if primary_id in unique_sources:
        raise BadRequestError(
            "Primary transaction cannot be settled into itself.",
            code="settle_primary_in_sources",
        )

    primary = await get_owned(session, user_id=user_id, transaction_id=primary_id)
    if primary.status not in (TransactionStatus.active, TransactionStatus.settled):
        raise BadRequestError(
            "Primary must be an active or settled transaction.",
            code="settle_primary_invalid",
        )

    result = await session.execute(
        select(Transaction).where(
            Transaction.user_id == user_id,
            Transaction.id.in_(unique_sources),
        )
    )
    sources = list(result.scalars().all())
    if len(sources) != len(unique_sources):
        raise NotFoundError(
            "One or more source transactions were not found.",
            code="settle_source_not_found",
        )

    for source in sources:
        if source.status is not TransactionStatus.active:
            raise BadRequestError(
                "Only active transactions can be settled into a primary.",
                code="settle_source_invalid",
            )
        if source.currency.upper() != primary.currency.upper():
            raise BadRequestError(
                "All transactions in a settle must share the same currency.",
                code="settle_currency_mismatch",
            )

    amount_applied = sum(
        (_source_contribution(source) for source in sources),
        Decimal("0"),
    )
    new_amount = as_money(primary.amount) - as_money(amount_applied)
    if new_amount <= 0:
        raise BadRequestError(
            "Settle would reduce the primary amount to zero or below.",
            code="settle_amount_invalid",
        )

    if primary.original_amount is None:
        primary.original_amount = as_money(primary.amount)

    group_id = str(uuid.uuid4())
    group = {
        "groupId": group_id,
        "mergedTransactionIds": [str(source.id) for source in sources],
        "createdAt": datetime.now(UTC).isoformat(),
        "amountApplied": money_float(amount_applied),
    }
    groups = _groups_list(primary)
    groups.append(group)
    primary.settlement_groups = groups
    primary.amount = new_amount
    primary.status = TransactionStatus.settled
    primary.is_edited = True

    for source in sources:
        source.status = TransactionStatus.merged
        source.merged_into_id = primary.id
        source.settlement_group_id = group_id
        source.is_edited = True

    await session.commit()
    await session.refresh(primary)

    await _index_after_commit(session, user_id=user_id, transaction_id=primary.id)
    for source in sources:
        await _index_after_commit(session, user_id=user_id, transaction_id=source.id)
    return primary


async def unsettle(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    primary_id: uuid.UUID,
    group_id: str,
) -> Transaction:
    primary = await get_owned(session, user_id=user_id, transaction_id=primary_id)
    if primary.status is not TransactionStatus.settled:
        raise BadRequestError(
            "Only settled transactions can be unsettled.",
            code="unsettle_not_settled",
        )

    groups = _groups_list(primary)
    target = next((group for group in groups if group.get("groupId") == group_id), None)
    if target is None:
        raise NotFoundError("Settlement group not found.", code="settle_group_not_found")

    member_ids = [
        uuid.UUID(str(item)) for item in (target.get("mergedTransactionIds") or [])
    ]
    if member_ids:
        result = await session.execute(
            select(Transaction).where(
                Transaction.user_id == user_id,
                Transaction.id.in_(member_ids),
            )
        )
        for member in result.scalars().all():
            member.status = TransactionStatus.active
            member.merged_into_id = None
            member.settlement_group_id = None
            member.is_edited = True

    remaining = [group for group in groups if group.get("groupId") != group_id]
    _apply_remaining_groups(primary, remaining)
    primary.is_edited = True

    await session.commit()
    await session.refresh(primary)

    await _index_after_commit(session, user_id=user_id, transaction_id=primary.id)
    for member_id in member_ids:
        await _index_after_commit(session, user_id=user_id, transaction_id=member_id)
    return primary


async def unmerge(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    transaction_id: uuid.UUID,
) -> Transaction:
    merged = await get_owned(session, user_id=user_id, transaction_id=transaction_id)
    if merged.status is not TransactionStatus.merged:
        raise BadRequestError(
            "Only merged transactions can be unmerged.",
            code="unmerge_not_merged",
        )
    if merged.merged_into_id is None or not merged.settlement_group_id:
        raise BadRequestError(
            "Merged transaction is missing primary linkage.",
            code="unmerge_missing_link",
        )

    primary = await get_owned(
        session, user_id=user_id, transaction_id=merged.merged_into_id
    )
    groups = _groups_list(primary)
    group_id = merged.settlement_group_id
    target_idx = next(
        (i for i, group in enumerate(groups) if group.get("groupId") == group_id),
        None,
    )
    if target_idx is None:
        raise NotFoundError("Settlement group not found.", code="settle_group_not_found")

    contribution = _source_contribution(merged)
    target = dict(groups[target_idx])
    member_ids = [
        str(item) for item in (target.get("mergedTransactionIds") or []) if str(item)
    ]
    merged_id_str = str(merged.id)
    if merged_id_str not in member_ids:
        raise BadRequestError(
            "Merged transaction is not listed on its settlement group.",
            code="unmerge_not_in_group",
        )
    member_ids = [item for item in member_ids if item != merged_id_str]
    if member_ids:
        target["mergedTransactionIds"] = member_ids
        target["amountApplied"] = money_float(
            as_money(target.get("amountApplied") or 0) - contribution
        )
        groups[target_idx] = target
    else:
        groups.pop(target_idx)

    merged.status = TransactionStatus.active
    merged.merged_into_id = None
    merged.settlement_group_id = None
    merged.is_edited = True

    _apply_remaining_groups(primary, groups)
    primary.is_edited = True

    await session.commit()
    await session.refresh(merged)
    await session.refresh(primary)

    await _index_after_commit(session, user_id=user_id, transaction_id=primary.id)
    await _index_after_commit(session, user_id=user_id, transaction_id=merged.id)
    return merged


async def _index_after_commit(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    transaction_id: uuid.UUID,
    deleted: bool = False,
) -> None:
    from app.services.rag_indexer import index_after_commit
    from app.services.semantic.enrichment import enrich_merchant_if_needed

    await index_after_commit(
        session, user_id=user_id, transaction_id=transaction_id, deleted=deleted
    )
    if deleted:
        return
    tx = await session.get(Transaction, transaction_id)
    if tx is None or tx.user_id != user_id:
        return
    try:
        await enrich_merchant_if_needed(
            session,
            merchant_normalized=tx.merchant_normalized,
            display_name=tx.merchant,
        )
    except Exception:
        # Enrichment must never fail a successful write.
        logger.exception(
            "merchant concept enrichment failed",
            extra={"transaction_id": str(transaction_id)},
        )
