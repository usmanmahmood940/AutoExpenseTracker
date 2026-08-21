"""Merchant summary and that merchant's transactions."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import (
    MerchantSummaryOut,
    TransactionListOut,
    TransactionOut,
)
from app.services import merchants as merchant_service

router = APIRouter(prefix="/merchants", tags=["merchants"])

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
