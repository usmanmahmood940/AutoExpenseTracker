"""categories — global defaults (`user_id` NULL) plus per-user custom rows.

Global rows are seeded from `app.db.seeds.categories`. User rows live
alongside them rather than in a separate table so `GET /categories` is one
query ordered by `sort_order`.
"""

from __future__ import annotations

import uuid

from sqlalchemy import (
    Boolean,
    ForeignKey,
    Index,
    Integer,
    String,
    text,
)
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, enum_check
from app.db.models.enums import CategoryType

_TYPE = SAEnum(
    CategoryType,
    name="category_type",
    native_enum=False,
    create_constraint=False,
    length=16,
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    validate_strings=True,
)


class Category(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "categories"
    __table_args__ = (
        # One global row per slug; one custom row per (user, slug).
        Index(
            "uq_categories_global_slug",
            "slug",
            unique=True,
            postgresql_where=text("user_id IS NULL"),
        ),
        Index(
            "uq_categories_user_slug",
            "user_id",
            "slug",
            unique=True,
            postgresql_where=text("user_id IS NOT NULL"),
        ),
        enum_check("type", CategoryType, "category_type"),
    )

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    slug: Mapped[str] = mapped_column(String(64), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type: Mapped[CategoryType] = mapped_column(_TYPE, nullable=False)
    icon: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default=text("'label'")
    )
    color: Mapped[str] = mapped_column(
        String(7), nullable=False, server_default=text("'#757575'")
    )
    sort_order: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("1000")
    )
    is_default: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )

    def __repr__(self) -> str:
        return f"<Category slug={self.slug} user_id={self.user_id}>"
