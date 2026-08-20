"""password_reset_sessions — short-lived tokens minted after a reset OTP verifies.

Replaces the `authTemp` Firestore collection's `type: 'reset_session'` documents.
Only the SHA-256 hash of the token is stored (the token itself is a bearer
credential, mailed to no one and returned once from `POST /auth/verify-reset-otp`).
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class PasswordResetSession(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "password_reset_sessions"
    __table_args__ = (
        # Drives the cleanup worker that replaces cleanupExpiredAuthDocs.
        Index("ix_password_reset_sessions_expires_at", "expires_at"),
    )

    token_hash: Mapped[str] = mapped_column(
        String(64), nullable=False, unique=True, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    email: Mapped[str] = mapped_column(String(320), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    consumed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    def __repr__(self) -> str:
        return f"<PasswordResetSession user_id={self.user_id}>"
