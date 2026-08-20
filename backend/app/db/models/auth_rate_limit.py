"""auth_rate_limits — sliding-window counters for OTP send/verify and login.

Replaces the `authRateLimits` Firestore collection. One row per (scope, key)
pair; `scope` separates independent limiters (e.g. `otp_send_email` vs
`login_ip`) that would otherwise collide if they shared a key namespace.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class AuthRateLimit(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "auth_rate_limits"
    __table_args__ = (
        UniqueConstraint("scope", "key", name="uq_auth_rate_limits_scope_key"),
    )

    scope: Mapped[str] = mapped_column(String(32), nullable=False)
    key: Mapped[str] = mapped_column(String(320), nullable=False)
    window_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    count: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )

    def __repr__(self) -> str:
        return f"<AuthRateLimit scope={self.scope} key={self.key}>"
