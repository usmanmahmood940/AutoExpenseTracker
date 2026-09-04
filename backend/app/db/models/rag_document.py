"""rag_documents — derived spend snippets + Gemini embeddings for RAG.

Never stores raw SMS. content_text is built from structured transaction columns.
"""

from __future__ import annotations

import uuid
from datetime import date

from pgvector.sqlalchemy import Vector as PgVector
from sqlalchemy import Date, ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, enum_check
from app.db.models.enums import RagDocType

EMBEDDING_DIM = 768


class Vector(PgVector):
    """Pass lists through to asyncpg's binary vector codec.

    Upstream bind_processor stringifies embeddings, which then fails inside
    `register_vector`'s binary encoder.
    """

    cache_ok = True

    def bind_processor(self, dialect):  # type: ignore[no-untyped-def]
        del dialect

        def process(value):
            return value

        return process


class RagDocument(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "rag_documents"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "doc_type",
            "ref_id",
            name="uq_rag_documents_user_type_ref",
        ),
        enum_check("doc_type", RagDocType, "rag_document_doc_type"),
        Index(
            "ix_rag_documents_user_embedding",
            "embedding",
            postgresql_using="hnsw",
            postgresql_ops={"embedding": "vector_cosine_ops"},
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    doc_type: Mapped[str] = mapped_column(String(16), nullable=False)
    content_text: Mapped[str] = mapped_column(Text, nullable=False)
    embedding: Mapped[list[float]] = mapped_column(
        Vector(EMBEDDING_DIM), nullable=False
    )
    ref_id: Mapped[str] = mapped_column(String(200), nullable=False)
    period_from: Mapped[date | None] = mapped_column(Date, nullable=True)
    period_to: Mapped[date | None] = mapped_column(Date, nullable=True)
    fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)

    def __repr__(self) -> str:
        return f"<RagDocument {self.doc_type} ref={self.ref_id!r}>"
