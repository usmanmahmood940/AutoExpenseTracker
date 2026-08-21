"""Default + custom categories."""

from __future__ import annotations

from fastapi import APIRouter, status
from pydantic import BaseModel, Field

from app.api.deps import CurrentUser, DbSession
from app.api.product_schemas import CategoryOut
from app.db.models.enums import CategoryType
from app.services import categories as category_service

router = APIRouter(prefix="/categories", tags=["categories"])


class CategoryListOut(BaseModel):
    items: list[CategoryOut]


class CategoryCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    type: CategoryType = CategoryType.expense
    icon: str = Field(default="label", max_length=64)
    color: str = Field(default="#757575", min_length=7, max_length=7)


@router.get("", response_model=CategoryListOut)
async def list_categories(user: CurrentUser, session: DbSession) -> CategoryListOut:
    rows = await category_service.list_categories(session, user_id=user.id)
    return CategoryListOut(items=[CategoryOut.model_validate(row) for row in rows])


@router.post(
    "",
    response_model=CategoryOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_category(
    body: CategoryCreateRequest, user: CurrentUser, session: DbSession
) -> CategoryOut:
    row = await category_service.create_category(
        session,
        user_id=user.id,
        name=body.name,
        type=body.type,
        icon=body.icon,
        color=body.color,
    )
    return CategoryOut.model_validate(row)
