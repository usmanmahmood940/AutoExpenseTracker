"""User-scoped cosine retrieval over rag_documents."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.enums import RagDocType
from app.db.models.rag_document import RagDocument
from app.services.embeddings import embed_texts


@dataclass(frozen=True)
class RagHit:
    id: uuid.UUID
    doc_type: str
    ref_id: str
    content_text: str
    distance: float
    period_from: date | None
    period_to: date | None


async def retrieve(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    query_text: str,
    limit: int = 10,
    doc_types: list[str] | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[RagHit]:
    query = (query_text or "").strip()
    if not query or limit <= 0:
        return []
    embedding = (await embed_texts([query]))[0]
    distance = RagDocument.embedding.cosine_distance(embedding)
    stmt = select(RagDocument, distance.label("distance")).where(
        RagDocument.user_id == user_id
    )
    if doc_types:
        allowed = [
            value for value in doc_types if value in {m.value for m in RagDocType}
        ]
        if allowed:
            stmt = stmt.where(RagDocument.doc_type.in_(allowed))
    if date_from is not None and date_to is not None:
        stmt = stmt.where(
            or_(
                RagDocument.period_from.is_(None),
                RagDocument.period_to.is_(None),
                (RagDocument.period_from <= date_to)
                & (RagDocument.period_to >= date_from),
            )
        )
    stmt = stmt.order_by(distance).limit(limit)
    rows = (await session.execute(stmt)).all()
    return [
        RagHit(
            id=row.id,
            doc_type=row.doc_type,
            ref_id=row.ref_id,
            content_text=row.content_text,
            distance=float(dist),
            period_from=row.period_from,
            period_to=row.period_to,
        )
        for row, dist in rows
    ]
