"""transactions — one row per parsed spend/receive event.

Mirrors Firestore `users/{uid}/transactions/{id}` so Phase F is a
field-for-field copy. Soft delete is `status = 'deleted'` (there is no
`is_deleted` / `deleted_at` column anywhere in the product).
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, enum_check
from app.db.models.enums import ExternalIdType, TransactionStatus, TransactionType

_TYPE = SAEnum(
    TransactionType,
    name="transaction_type",
    native_enum=False,
    create_constraint=False,
    length=16,
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    validate_strings=True,
)
_STATUS = SAEnum(
    TransactionStatus,
    name="transaction_status",
    native_enum=False,
    create_constraint=False,
    length=16,
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    validate_strings=True,
)
_EXTERNAL_ID_TYPE = SAEnum(
    ExternalIdType,
    name="external_id_type",
    native_enum=False,
    create_constraint=False,
    length=16,
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    validate_strings=True,
)


class Transaction(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "transactions"
    __table_args__ = (
        UniqueConstraint("user_id", "dedup_key", name="uq_transactions_user_dedup"),
        Index("ix_transactions_user_date_id", "user_id", "transaction_date", "id"),
        Index(
            "ix_transactions_user_amount_date",
            "user_id",
            "amount",
            "transaction_date",
            "id",
        ),
        Index(
            "ix_transactions_user_merchant_date",
            "user_id",
            "merchant_normalized",
            "transaction_date",
        ),
        Index(
            "ix_transactions_user_status_date",
            "user_id",
            "status",
            "transaction_date",
        ),
        enum_check("type", TransactionType, "transaction_type"),
        enum_check("status", TransactionStatus, "transaction_status"),
        enum_check("external_id_type", ExternalIdType, "external_id_type"),
        CheckConstraint("amount >= 0", name="amount_non_negative"),
        CheckConstraint(
            "parse_confidence >= 0 AND parse_confidence <= 1",
            name="parse_confidence_range",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    currency: Mapped[str] = mapped_column(
        String(3), nullable=False, server_default=text("'PKR'")
    )
    type: Mapped[TransactionType] = mapped_column(_TYPE, nullable=False)
    merchant: Mapped[str] = mapped_column(String(200), nullable=False)
    merchant_details: Mapped[str | None] = mapped_column(String(500), nullable=True)
    merchant_normalized: Mapped[str] = mapped_column(String(200), nullable=False)
    is_recurring: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    recurring_group_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    category: Mapped[str] = mapped_column(
        String(100), nullable=False, server_default=text("'Uncategorized'")
    )
    category_source: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default=text("'rule'")
    )
    payment_method: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default=text("'unknown'")
    )
    bank: Mapped[str] = mapped_column(
        String(100), nullable=False, server_default=text("''")
    )
    account_id: Mapped[str] = mapped_column(
        String(100), nullable=False, server_default=text("''")
    )
    account_id_masked: Mapped[str] = mapped_column(
        String(32), nullable=False, server_default=text("''")
    )
    branch: Mapped[str | None] = mapped_column(String(100), nullable=True)
    transaction_time: Mapped[str] = mapped_column(
        String(32), nullable=False, server_default=text("''")
    )
    transaction_date: Mapped[date] = mapped_column(Date, nullable=False)
    day: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("''")
    )
    external_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    external_id_type: Mapped[ExternalIdType] = mapped_column(
        _EXTERNAL_ID_TYPE,
        nullable=False,
        server_default=text("'unknown'"),
    )
    dedup_key: Mapped[str] = mapped_column(String(256), nullable=False)
    sms_source: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    parse_confidence: Mapped[Decimal] = mapped_column(
        Numeric(4, 3), nullable=False, server_default=text("1")
    )
    is_auto_detected: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    is_edited: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    is_duplicate: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    status: Mapped[TransactionStatus] = mapped_column(
        _STATUS, nullable=False, server_default=text("'active'")
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    def __repr__(self) -> str:
        return f"<Transaction id={self.id} merchant={self.merchant!r}>"
