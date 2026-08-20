"""auth_otps — short-lived email verification / password reset codes.

Replaces the `authTemp` Firestore collection's `type: 'otp'` documents. Only the
hash of the code is stored, and rows are keyed by (email, purpose) because a
fresh request for the same purpose should replace the outstanding code rather
than let a user hold several valid ones — matching today's `otp_{purpose}_{email}`
document id.

The `reset_session` half of `authTemp` and the rate-limit counters arrive with the
Phase B auth routes that consume them.
"""

from __future__ import annotations

from datetime import datetime
from enum import StrEnum

from sqlalchemy import (
    DateTime,
    Index,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, enum_check


class OtpPurpose(StrEnum):
    email_verification = "email_verification"
    password_reset = "password_reset"  # noqa: S105 — a purpose name, not a secret


class AuthOtp(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "auth_otps"
    __table_args__ = (
        UniqueConstraint("email", "purpose", name="uq_auth_otps_email_purpose"),
        # Drives the cleanup worker that replaces cleanupExpiredAuthDocs.
        Index("ix_auth_otps_expires_at", "expires_at"),
        enum_check("purpose", OtpPurpose, "otp_purpose"),
    )

    email: Mapped[str] = mapped_column(String(320), nullable=False, index=True)
    purpose: Mapped[OtpPurpose] = mapped_column(
        SAEnum(
            OtpPurpose,
            name="otp_purpose",
            native_enum=False,
            create_constraint=False,
            length=32,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
            validate_strings=True,
        ),
        nullable=False,
    )
    code_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    consumed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    def __repr__(self) -> str:
        return f"<AuthOtp email={self.email} purpose={self.purpose}>"
