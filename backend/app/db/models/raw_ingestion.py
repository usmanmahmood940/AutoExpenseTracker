"""raw_ingestions — inbound SMS/email payloads before (or instead of) a tx.

Phase D's ingest worker writes these; Phase C exposes them on `GET /review`
so the Review screen has somewhere to land once Flutter points at the API.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, func
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, enum_check
from app.db.models.enums import IngestionSource, IngestionStatus

_SOURCE = SAEnum(
    IngestionSource,
    name="ingestion_source",
    native_enum=False,
    create_constraint=False,
    length=32,
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    validate_strings=True,
)
_STATUS = SAEnum(
    IngestionStatus,
    name="ingestion_status",
    native_enum=False,
    create_constraint=False,
    length=32,
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    validate_strings=True,
)


class RawIngestion(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "raw_ingestions"
    __table_args__ = (
        Index(
            "ix_raw_ingestions_user_status_received",
            "user_id",
            "status",
            "received_at",
        ),
        enum_check("source", IngestionSource, "ingestion_source"),
        enum_check("status", IngestionStatus, "ingestion_status"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    raw: Mapped[str] = mapped_column(String(8000), nullable=False)
    source: Mapped[IngestionSource] = mapped_column(_SOURCE, nullable=False)
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    message_id: Mapped[str | None] = mapped_column(String(256), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(256), nullable=True)
    status: Mapped[IngestionStatus] = mapped_column(_STATUS, nullable=False)
    transaction_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("transactions.id", ondelete="SET NULL"),
        nullable=True,
    )
    error: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    def __repr__(self) -> str:
        return f"<RawIngestion id={self.id} status={self.status}>"
