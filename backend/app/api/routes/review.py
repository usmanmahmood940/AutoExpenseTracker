"""Review queue: low-confidence transactions + stuck ingestions."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import ReviewQueueOut, ingestion_to_out, transaction_to_out
from app.services import review as review_service

router = APIRouter(tags=["review"])


@router.get("/review", response_model=ReviewQueueOut)
async def get_review(user: CurrentUser, session: DbSession) -> ReviewQueueOut:
    queue = await review_service.get_review_queue(session, user_id=user.id)
    return ReviewQueueOut(
        needs_review=[
            transaction_to_out(item, include_raw=True) for item in queue["needs_review"]
        ],
        needs_parse=[ingestion_to_out(item) for item in queue["needs_parse"]],
        duplicates=[ingestion_to_out(item) for item in queue["duplicates"]],
        pending_count=queue["pending_count"],
    )
