"""users — the app-side profile keyed to a Firebase Auth account.

Mirrors the current Firestore `users/{uid}` document (see
shared/types/schema.ts `User` / `UserSettings`) so the Phase F migration is a
field-for-field copy. `firebase_uid` is the Firestore document id, which is why
no separate mapping column is needed here.
"""

from __future__ import annotations

from sqlalchemy import ARRAY, Boolean, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

DEFAULT_CURRENCY = "PKR"
DEFAULT_TIMEZONE = "Asia/Karachi"


class User(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "users"

    firebase_uid: Mapped[str] = mapped_column(
        String(128), nullable=False, unique=True, index=True
    )
    # Stored lowercased by the service layer so the unique index is meaningful.
    email: Mapped[str] = mapped_column(String(320), nullable=False, unique=True)
    email_verified: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    display_name: Mapped[str] = mapped_column(
        String(200), nullable=False, server_default=text("''")
    )
    default_currency: Mapped[str] = mapped_column(
        String(3), nullable=False, server_default=text(f"'{DEFAULT_CURRENCY}'")
    )
    timezone: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default=text(f"'{DEFAULT_TIMEZONE}'")
    )
    bank_senders: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default=text("'{}'::varchar[]")
    )
    email_filters: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default=text("'{}'::varchar[]")
    )
    # Flattened from Firestore's nested `settings` map.
    auto_categorize: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} firebase_uid={self.firebase_uid}>"
