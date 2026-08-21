"""Review queue: needs_review transactions + pending ingestions."""

from __future__ import annotations

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.enums import IngestionStatus, TransactionStatus
from app.db.models.raw_ingestion import RawIngestion
from app.db.models.transaction import Transaction

REVIEW_LIMIT = 50


async def get_review_queue(
    session: AsyncSession, *, user_id: uuid.UUID, limit: int = REVIEW_LIMIT
) -> dict:
    needs_review = list(
        (
            await session.execute(
                select(Transaction)
                .where(
                    Transaction.user_id == user_id,
                    Transaction.status == TransactionStatus.needs_review,
                )
                .order_by(Transaction.transaction_date.desc(), Transaction.id.desc())
                .limit(limit)
            )
        )
        .scalars()
        .all()
    )

    async def _ingestions(status: IngestionStatus) -> list[RawIngestion]:
        result = await session.execute(
            select(RawIngestion)
            .where(RawIngestion.user_id == user_id, RawIngestion.status == status)
            .order_by(RawIngestion.received_at.desc(), RawIngestion.id.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    needs_parse = await _ingestions(IngestionStatus.needs_parse)
    duplicates = await _ingestions(IngestionStatus.duplicate)

    review_count = int(
        (
            await session.execute(
                select(func.count(Transaction.id)).where(
                    Transaction.user_id == user_id,
                    Transaction.status == TransactionStatus.needs_review,
                )
            )
        ).scalar_one()
    )
    parse_count = int(
        (
            await session.execute(
                select(func.count(RawIngestion.id)).where(
                    RawIngestion.user_id == user_id,
                    RawIngestion.status == IngestionStatus.needs_parse,
                )
            )
        ).scalar_one()
    )

    return {
        "needs_review": needs_review,
        "needs_parse": needs_parse,
        "duplicates": duplicates,
        "pending_count": review_count + parse_count,
    }
