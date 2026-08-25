"""Transaction list, detail, search, create, update, review, soft-delete."""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Query, status
from pydantic import BaseModel, Field

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import (
    SearchListOut,
    TransactionListOut,
    TransactionOut,
)
from app.db.models.enums import (
    IngestionSource,
    SortOrder,
    TransactionSortBy,
    TransactionStatus,
    TransactionType,
)
from app.services import transactions as tx_service
from app.services.payment_methods import PAYMENT_METHODS

router = APIRouter(tags=["transactions"])

Limit = Annotated[int, Query(ge=1, le=100)]


def _split_csv(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split(",") if part.strip()]


def _split_categories(raw: str | None) -> list[str] | None:
    names = _split_csv(raw)
    return names or None


def _parse_payment_methods(raw: str | None) -> list[str]:
    allowed = set(PAYMENT_METHODS)
    seen: list[str] = []
    for name in _split_csv(raw):
        if name in allowed and name not in seen:
            seen.append(name)
    return seen


def _parse_sources(raw: str | None) -> list[str]:
    allowed = {item.value for item in IngestionSource}
    seen: list[str] = []
    for name in _split_csv(raw):
        if name in allowed and name not in seen:
            seen.append(name)
    return seen


class PaymentMethodListOut(BaseModel):
    items: list[str]


class TransactionCreateRequest(BaseModel):
    amount: Decimal = Field(gt=0)
    merchant: str = Field(min_length=1, max_length=200)
    transaction_date: date
    type: TransactionType = TransactionType.debit
    category: str = "Uncategorized"
    currency: str = Field(default="PKR", min_length=3, max_length=3)
    transaction_time: str = ""
    payment_method: str = "unknown"
    bank: str = ""
    account_id: str = ""
    account_id_masked: str = ""
    merchant_details: str | None = None
    branch: str | None = None
    category_source: str = "user"
    ingestion_id: uuid.UUID | None = None


class TransactionUpdateRequest(BaseModel):
    amount: Decimal | None = Field(default=None, gt=0)
    merchant: str | None = Field(default=None, min_length=1, max_length=200)
    merchant_details: str | None = None
    category: str | None = None
    type: TransactionType | None = None
    category_source: str | None = None
    payment_method: str | None = None
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    bank: str | None = None
    account_id: str | None = None
    account_id_masked: str | None = None
    transaction_time: str | None = None
    transaction_date: date | None = None
    day: str | None = None
    status: TransactionStatus | None = None


@router.get("/payment-methods", response_model=PaymentMethodListOut)
async def list_payment_methods(_user: CurrentUser) -> PaymentMethodListOut:
    return PaymentMethodListOut(items=list(PAYMENT_METHODS))


@router.get("/transactions/search", response_model=SearchListOut)
async def search_transactions(
    user: CurrentUser,
    session: DbSession,
    q: str = "",
    limit: Limit = 50,
    cursor: uuid.UUID | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    type: TransactionType | None = None,
    subscriptions_only: bool = False,
    categories: str | None = None,
    amount_min: Decimal | None = None,
    amount_max: Decimal | None = None,
    payment_methods: str | None = None,
    sources: str | None = None,
    include_aggregates: bool = False,
    sort_by: TransactionSortBy = TransactionSortBy.date,
    order_by: SortOrder = SortOrder.desc,
) -> SearchListOut:
    page = await tx_service.search_transactions(
        session,
        user_id=user.id,
        text=q,
        limit=limit,
        cursor=cursor,
        date_from=date_from,
        date_to=date_to,
        tx_type=type,
        subscriptions_only=subscriptions_only,
        categories=_split_categories(categories),
        amount_min=amount_min,
        amount_max=amount_max,
        payment_methods=_parse_payment_methods(payment_methods),
        sources=_parse_sources(sources),
        include_aggregates=include_aggregates,
        sort_by=sort_by,
        order_by=order_by,
    )
    return SearchListOut(
        items=[TransactionOut.model_validate(item) for item in page["items"]],
        next_cursor=page["next_cursor"],
        has_more=page["has_more"],
        total_count=page["total_count"],
        total_spent=page["total_spent"],
        total_received=page["total_received"],
        sort_by=page["sort_by"],
        order_by=page["order_by"],
    )


@router.get("/transactions", response_model=TransactionListOut)
async def list_transactions(
    user: CurrentUser,
    session: DbSession,
    limit: Limit = 50,
    cursor: uuid.UUID | None = None,
    include_aggregates: bool = False,
    date_from: date | None = None,
    date_to: date | None = None,
    sort_by: TransactionSortBy = TransactionSortBy.date,
    order_by: SortOrder = SortOrder.desc,
    type: TransactionType | None = None,
    category: str | None = None,
    bank: str | None = None,
    account_id_masked: str | None = None,
    merchant_query: str | None = None,
    amount_min: Decimal | None = None,
    amount_max: Decimal | None = None,
) -> TransactionListOut:
    page = await tx_service.list_transactions(
        session,
        user_id=user.id,
        limit=limit,
        cursor=cursor,
        sort_by=sort_by,
        order_by=order_by,
        include_aggregates=include_aggregates,
        date_from=date_from,
        date_to=date_to,
        tx_type=type,
        category=category,
        bank=bank,
        account_id_masked=account_id_masked,
        merchant_query=merchant_query,
        amount_min=amount_min,
        amount_max=amount_max,
    )
    return TransactionListOut(
        items=[TransactionOut.model_validate(item) for item in page["items"]],
        next_cursor=page["next_cursor"],
        has_more=page["has_more"],
        total_count=page["total_count"],
        total_amount=page["total_amount"],
        sort_by=page["sort_by"],
        order_by=page["order_by"],
        date_from=page["date_from"],
        date_to=page["date_to"],
    )


@router.post(
    "/transactions",
    response_model=TransactionOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_transaction(
    body: TransactionCreateRequest, user: CurrentUser, session: DbSession
) -> TransactionOut:
    tx = await tx_service.create_transaction(
        session,
        user_id=user.id,
        amount=body.amount,
        merchant=body.merchant,
        transaction_date=body.transaction_date,
        tx_type=body.type,
        category=body.category,
        currency=body.currency,
        transaction_time=body.transaction_time,
        payment_method=body.payment_method,
        bank=body.bank,
        account_id=body.account_id,
        account_id_masked=body.account_id_masked,
        merchant_details=body.merchant_details,
        branch=body.branch,
        category_source=body.category_source,
        ingestion_id=body.ingestion_id,
    )
    return TransactionOut.model_validate(tx)


@router.get("/transactions/{transaction_id}", response_model=TransactionOut)
async def get_transaction(
    transaction_id: uuid.UUID, user: CurrentUser, session: DbSession
) -> TransactionOut:
    tx = await tx_service.get_owned(
        session, user_id=user.id, transaction_id=transaction_id
    )
    return TransactionOut.model_validate(tx)


@router.patch("/transactions/{transaction_id}", response_model=TransactionOut)
async def update_transaction(
    transaction_id: uuid.UUID,
    body: TransactionUpdateRequest,
    user: CurrentUser,
    session: DbSession,
) -> TransactionOut:
    tx = await tx_service.update_transaction(
        session,
        user_id=user.id,
        transaction_id=transaction_id,
        updates=body.model_dump(exclude_unset=True),
    )
    return TransactionOut.model_validate(tx)


@router.delete(
    "/transactions/{transaction_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_transaction(
    transaction_id: uuid.UUID, user: CurrentUser, session: DbSession
) -> None:
    await tx_service.soft_delete(
        session, user_id=user.id, transaction_id=transaction_id
    )


@router.post(
    "/transactions/{transaction_id}/review",
    response_model=TransactionOut,
)
async def review_transaction(
    transaction_id: uuid.UUID, user: CurrentUser, session: DbSession
) -> TransactionOut:
    tx = await tx_service.mark_reviewed(
        session, user_id=user.id, transaction_id=transaction_id
    )
    return TransactionOut.model_validate(tx)
