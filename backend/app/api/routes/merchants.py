"""Merchant summary and that merchant's transactions."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status
from pydantic import BaseModel, Field

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import (
    MerchantOverrideOut,
    MerchantSummaryOut,
    TransactionListOut,
    TransactionOut,
)
from app.services import merchants as merchant_service

router = APIRouter(prefix="/merchants", tags=["merchants"])


class MerchantOverridePut(BaseModel):
    category: str = Field(min_length=1, max_length=100)
    display_name: str | None = Field(default=None, max_length=200)


Limit = Annotated[int, Query(ge=1, le=100)]


@router.get("/{merchant_key}", response_model=MerchantSummaryOut)
async def get_merchant(
    merchant_key: str, user: CurrentUser, session: DbSession
) -> MerchantSummaryOut:
    payload = await merchant_service.get_merchant_summary(
        session, user=user, merchant_key=merchant_key
    )
    return MerchantSummaryOut.model_validate(payload)


@router.get("/{merchant_key}/transactions", response_model=TransactionListOut)
async def list_merchant_transactions(
    merchant_key: str,
    user: CurrentUser,
    session: DbSession,
    limit: Limit = 50,
    cursor: uuid.UUID | None = None,
) -> TransactionListOut:
    page = await merchant_service.list_merchant_transactions(
        session,
        user_id=user.id,
        merchant_key=merchant_key,
        limit=limit,
        cursor=cursor,
    )
    return TransactionListOut(
        items=[TransactionOut.model_validate(item) for item in page["items"]],
        next_cursor=page["next_cursor"],
        has_more=page["has_more"],
    )


@router.get(
    "/{merchant_key}/category-override",
    response_model=MerchantOverrideOut,
    summary="Category override for this merchant, if any",
)
async def get_category_override(
    merchant_key: str, user: CurrentUser, session: DbSession
) -> MerchantOverrideOut:
    row = await merchant_service.get_category_override(
        session, user_id=user.id, merchant_key=merchant_key
    )
    return MerchantOverrideOut.model_validate(row)


@router.put(
    "/{merchant_key}/category-override",
    response_model=MerchantOverrideOut,
    summary="Remember a category for this merchant (ingest + future edits)",
)
async def put_category_override(
    merchant_key: str,
    body: MerchantOverridePut,
    user: CurrentUser,
    session: DbSession,
) -> MerchantOverrideOut:
    row = await merchant_service.upsert_category_override(
        session,
        user_id=user.id,
        merchant_key=merchant_key,
        category=body.category,
        display_name=body.display_name,
    )
    return MerchantOverrideOut.model_validate(row)


@router.delete(
    "/{merchant_key}/category-override",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Forget the saved category for this merchant",
)
async def delete_category_override(
    merchant_key: str, user: CurrentUser, session: DbSession
) -> None:
    await merchant_service.delete_category_override(
        session, user_id=user.id, merchant_key=merchant_key
    )
