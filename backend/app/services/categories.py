"""Default + user categories. Seeds the 20 product defaults if missing."""

from __future__ import annotations

import re
import uuid

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BadRequestError, ConflictError
from app.db.models.category import Category
from app.db.models.enums import CategoryType
from app.db.seeds.categories import DEFAULT_CATEGORIES

_SLUG_STRIP = re.compile(r"[^a-z0-9]+")
CUSTOM_SORT_ORDER = 1000
_defaults_ready = False


async def seed_default_categories(session: AsyncSession) -> None:
    """Idempotent insert of the global default set (user_id IS NULL)."""
    global _defaults_ready
    if _defaults_ready:
        return
    existing = {
        row.slug
        for row in (
            await session.execute(select(Category).where(Category.user_id.is_(None)))
        )
        .scalars()
        .all()
    }
    added = False
    for item in DEFAULT_CATEGORIES:
        if item["slug"] in existing:
            continue
        session.add(
            Category(
                user_id=None,
                slug=item["slug"],
                name=item["name"],
                type=item["type"],
                icon=item["icon"],
                color=item["color"],
                sort_order=item["sort_order"],
                is_default=True,
            )
        )
        added = True
    if added:
        await session.commit()
    _defaults_ready = True


async def list_categories(
    session: AsyncSession, *, user_id: uuid.UUID
) -> list[Category]:
    await seed_default_categories(session)
    result = await session.execute(
        select(Category)
        .where(or_(Category.user_id.is_(None), Category.user_id == user_id))
        .order_by(Category.is_default.desc(), Category.sort_order, Category.name)
    )
    return list(result.scalars().all())


async def allowed_category_names(
    session: AsyncSession, *, user_id: uuid.UUID
) -> list[str]:
    rows = await list_categories(session, user_id=user_id)
    names: list[str] = []
    seen: set[str] = set()
    for row in rows:
        key = row.name.lower()
        if key in seen:
            continue
        seen.add(key)
        names.append(row.name)
    return names


def _slugify(name: str) -> str:
    slug = _SLUG_STRIP.sub("_", name.strip().lower()).strip("_")
    return slug or "category"


async def create_category(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    name: str,
    type: CategoryType,
    icon: str,
    color: str,
) -> Category:
    name = name.strip()
    if not name:
        raise BadRequestError(
            "Category name is required.",
            code="category_name_required",
        )

    clash = await session.execute(
        select(Category).where(
            Category.user_id == user_id,
            Category.name.ilike(name),
        )
    )
    if clash.scalar_one_or_none() is not None:
        raise ConflictError(
            "You already have a category with this name.",
            code="category_exists",
        )

    slug = _slugify(name)
    taken = await session.execute(
        select(Category).where(Category.user_id == user_id, Category.slug == slug)
    )
    if taken.scalar_one_or_none() is not None:
        slug = f"{slug}_{uuid.uuid4().hex[:8]}"

    category = Category(
        user_id=user_id,
        slug=slug,
        name=name,
        type=type,
        icon=icon,
        color=color,
        sort_order=CUSTOM_SORT_ORDER,
        is_default=False,
    )
    session.add(category)
    await session.commit()
    await session.refresh(category)
    return category
