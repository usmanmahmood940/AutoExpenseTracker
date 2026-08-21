"""monthly_summaries — materialized Insights rows.

Phase C serves live SQL; this table is the Phase D replacement for
`onUserTransactionWritten`. Recomputed from transactions after ingest.
"""

from __future__ import annotations

import uuid
from decimal import Decimal

from sqlalchemy import ForeignKey, Integer, Numeric, String, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class MonthlySummary(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "monthly_summaries"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "year_month", name="uq_monthly_summaries_user_month"
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    year_month: Mapped[str] = mapped_column(String(7), nullable=False)
    currency: Mapped[str] = mapped_column(
        String(3), nullable=False, server_default=text("'PKR'")
    )
    total_debit: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, server_default=text("0")
    )
    total_credit: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, server_default=text("0")
    )
    net: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, server_default=text("0")
    )
    transaction_count: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    by_category: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    by_merchant: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )

    def __repr__(self) -> str:
        return f"<MonthlySummary {self.year_month} user_id={self.user_id}>"
