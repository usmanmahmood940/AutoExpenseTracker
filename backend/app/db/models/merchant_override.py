"""merchant_category_overrides — per-user "this merchant is always X".

Applied on ingest (Phase D) after Gemini parse so user corrections compound.
Phase C writes a row whenever a transaction's category is PATCHed, matching
the Firestore `upsertMerchantCategoryOverride` call the detail screen makes.
"""

from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class MerchantCategoryOverride(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "merchant_category_overrides"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "merchant_key", name="uq_merchant_overrides_user_key"
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    merchant_key: Mapped[str] = mapped_column(String(200), nullable=False)
    display_name: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(100), nullable=False)

    def __repr__(self) -> str:
        return f"<MerchantCategoryOverride {self.merchant_key}={self.category}>"
