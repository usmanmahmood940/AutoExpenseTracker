"""Review queue: low-confidence transactions + stuck ingestions."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import (
    IngestionOut,
    ReviewQueueOut,
    TransactionOut,
)
from app.services import review as review_service

router = APIRouter(tags=["review"])


@router.get("/review", response_model=ReviewQueueOut)
async def get_review(user: CurrentUser, session: DbSession) -> ReviewQueueOut:
    queue = await review_service.get_review_queue(session, user_id=user.id)
    return ReviewQueueOut(
        needs_review=[
            TransactionOut.model_validate(item) for item in queue["needs_review"]
        ],
        needs_parse=[
            IngestionOut.model_validate(item) for item in queue["needs_parse"]
        ],
        duplicates=[IngestionOut.model_validate(item) for item in queue["duplicates"]],
        pending_count=queue["pending_count"],
    )
