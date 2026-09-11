"""merchant_concepts — global merchant → closed-vocabulary concept tags.

Write-time enrichment (or seed bootstrap) fills these once per normalized
merchant so Ask/agent queries can JOIN instead of ILIKE-expanding topics.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func, text
from sqlalchemy.dialects.postgresql import ARRAY, UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class MerchantConcept(Base):
    __tablename__ = "merchant_concepts"

    merchant_normalized: Mapped[str] = mapped_column(
        String(200), primary_key=True, nullable=False
    )
    concepts: Mapped[list[str]] = mapped_column(
        ARRAY(String(64)),
        nullable=False,
        server_default=text("'{}'::text[]"),
    )
    model: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default=text("'seed'")
    )
    resolved_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    def __repr__(self) -> str:
        return f"<MerchantConcept {self.merchant_normalized}={self.concepts!r}>"


class MerchantConceptOverride(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    """Per-user override of merchant concepts (personal interpretations)."""

    __tablename__ = "merchant_concept_overrides"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "merchant_normalized",
            name="uq_merchant_concept_overrides_user_merchant",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    merchant_normalized: Mapped[str] = mapped_column(String(200), nullable=False)
    concepts: Mapped[list[str]] = mapped_column(
        ARRAY(String(64)),
        nullable=False,
        server_default=text("'{}'::text[]"),
    )

    def __repr__(self) -> str:
        return (
            f"<MerchantConceptOverride {self.merchant_normalized}"
            f"={self.concepts!r}>"
        )
