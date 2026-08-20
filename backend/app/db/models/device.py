"""devices — FCM registration targets for push.

Replaces the `fcmTokens` array on the Firestore user document. A row per token
(rather than an array on `users`) lets the push worker prune dead tokens and lets
a token move between accounts on shared hardware, which is why `fcm_token` is
globally unique rather than unique per user.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, enum_check


class DevicePlatform(StrEnum):
    ios = "ios"
    android = "android"
    web = "web"


class Device(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "devices"
    __table_args__ = (enum_check("platform", DevicePlatform, "device_platform"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    fcm_token: Mapped[str] = mapped_column(String(4096), nullable=False, unique=True)
    platform: Mapped[DevicePlatform] = mapped_column(
        # VARCHAR + explicit CHECK (see __table_args__) instead of a native PG
        # enum: adding a platform later is a constraint swap, not an ALTER TYPE.
        SAEnum(
            DevicePlatform,
            name="device_platform",
            native_enum=False,
            create_constraint=False,
            length=16,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
            validate_strings=True,
        ),
        nullable=False,
    )
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    def __repr__(self) -> str:
        return f"<Device id={self.id} user_id={self.user_id} platform={self.platform}>"
