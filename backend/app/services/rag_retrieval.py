"""User-scoped retrieval over rag_documents: cosine plus lexical.

Cosine alone cannot be trusted for questions naming a specific merchant, since
sibling documents (LESCO vs SNGPL, both "Bills & Utilities") sit at nearly the
same distance. The lexical channel guarantees an explicitly named merchant or
enrichment keyword is always found.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.enums import RagDocType
from app.db.models.rag_document import RagDocument
from app.services.embeddings import EmbeddingError, embed_texts
from app.services.sql_like import contains_pattern

logger = logging.getLogger(__name__)
_MAX_LEXICAL_TERMS = 24


@dataclass(frozen=True)
class RagHit:
    id: uuid.UUID
    doc_type: str
    ref_id: str
    content_text: str
    distance: float
    period_from: date | None
    period_to: date | None


def _allowed_doc_types(doc_types: list[str] | None) -> list[str]:
    if not doc_types:
        return []
    known = {member.value for member in RagDocType}
    return [value for value in doc_types if value in known]


def _scoped(stmt, *, user_id: uuid.UUID, doc_types: list[str] | None):
    stmt = stmt.where(RagDocument.user_id == user_id)
    allowed = _allowed_doc_types(doc_types)
    if allowed:
        stmt = stmt.where(RagDocument.doc_type.in_(allowed))
    return stmt


def _period_scoped(
    stmt,
    *,
    date_from: date | None,
    date_to: date | None,
    strict_period: bool,
    periodless_doc_types: list[str] | None,
):
    if date_from is None or date_to is None:
        return stmt
    overlap = (RagDocument.period_from <= date_to) & (
        RagDocument.period_to >= date_from
    )
    periodless = or_(
        RagDocument.period_from.is_(None),
        RagDocument.period_to.is_(None),
    )
    if not strict_period:
        return stmt.where(or_(periodless, overlap))
    exempt = _allowed_doc_types(periodless_doc_types)
    if exempt:
        # Lifetime rollups (merchant docs) have no period, so a date filter is
        # meaningless for them; keep them eligible instead of dropping them.
        return stmt.where(
            or_(overlap, and_(periodless, RagDocument.doc_type.in_(exempt)))
        )
    return stmt.where(
        RagDocument.period_from.is_not(None),
        RagDocument.period_to.is_not(None),
        overlap,
    )


def _hit(row: RagDocument, distance: float) -> RagHit:
    return RagHit(
        id=row.id,
        doc_type=row.doc_type,
        ref_id=row.ref_id,
        content_text=row.content_text,
        distance=distance,
        period_from=row.period_from,
        period_to=row.period_to,
    )


async def retrieve(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    query_text: str,
    limit: int = 10,
    doc_types: list[str] | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    strict_period: bool = False,
    periodless_doc_types: list[str] | None = None,
) -> list[RagHit]:
    query = (query_text or "").strip()
    if not query or limit <= 0:
        return []
    try:
        embedding = (await embed_texts([query]))[0]
    except EmbeddingError:
        # Degrade to the lexical channel rather than failing the whole answer.
        logger.warning("query embed failed; skipping vector retrieval")
        return []
    distance = RagDocument.embedding.cosine_distance(embedding)
    stmt = _scoped(
        select(RagDocument, distance.label("distance")),
        user_id=user_id,
        doc_types=doc_types,
    )
    stmt = _period_scoped(
        stmt,
        date_from=date_from,
        date_to=date_to,
        strict_period=strict_period,
        periodless_doc_types=periodless_doc_types,
    )
    rows = (await session.execute(stmt.order_by(distance).limit(limit))).all()
    return [_hit(row, float(dist)) for row, dist in rows]


async def retrieve_lexical(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    terms: list[str],
    limit: int = 10,
    doc_types: list[str] | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    strict_period: bool = False,
    periodless_doc_types: list[str] | None = None,
) -> list[RagHit]:
    """Substring match over content_text for any of `terms`, newest first.

    Works on plain `content_text` because indexed documents carry the
    enrichment keywords, so "electricity" matches a LESCO row directly.
    """
    cleaned = [term.strip() for term in terms if term and term.strip()]
    if not cleaned or limit <= 0:
        return []
    stmt = _scoped(select(RagDocument), user_id=user_id, doc_types=doc_types)
    stmt = _period_scoped(
        stmt,
        date_from=date_from,
        date_to=date_to,
        strict_period=strict_period,
        periodless_doc_types=periodless_doc_types,
    )
    stmt = stmt.where(
        or_(
            *[
                RagDocument.content_text.ilike(contains_pattern(term), escape="\\")
                for term in cleaned[:_MAX_LEXICAL_TERMS]
            ]
        )
    )
    stmt = stmt.order_by(RagDocument.period_to.desc().nullslast()).limit(limit)
    rows = list((await session.execute(stmt)).scalars())
    # Distance 0.0 marks these as exact matches so callers can rank them first.
    return [_hit(row, 0.0) for row in rows]
