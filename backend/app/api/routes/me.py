"""The signed-in user's own profile and push-notification devices."""

from __future__ import annotations

from fastapi import APIRouter, status
from pydantic import BaseModel, Field

from app.api.deps import CurrentUser, DbSession
from app.api.schemas import DeviceOut, UserOut
from app.db.models.device import DevicePlatform
from app.services import devices as device_service

router = APIRouter(tags=["me"])


class MeUpdateRequest(BaseModel):
    """All fields optional: only the ones present are changed (`PATCH`)."""

    display_name: str | None = Field(default=None, max_length=200)
    default_currency: str | None = Field(default=None, min_length=3, max_length=3)
    timezone: str | None = Field(default=None, max_length=64)
    bank_senders: list[str] | None = None
    email_filters: list[str] | None = None
    auto_categorize: bool | None = None


class DeviceRegisterRequest(BaseModel):
    fcm_token: str = Field(min_length=1, max_length=4096)
    platform: DevicePlatform
    app_version: str | None = Field(default=None, max_length=32)


@router.get("/me", response_model=UserOut, summary="Get the current user's profile")
async def get_me(user: CurrentUser) -> UserOut:
    return UserOut.model_validate(user)


@router.patch("/me", response_model=UserOut, summary="Update profile / settings")
async def update_me(
    body: MeUpdateRequest, user: CurrentUser, session: DbSession
) -> UserOut:
    updates = body.model_dump(exclude_unset=True)
    if updates.get("default_currency"):
        updates["default_currency"] = updates["default_currency"].upper()

    for field, value in updates.items():
        setattr(user, field, value)

    await session.commit()
    await session.refresh(user)
    return UserOut.model_validate(user)


@router.post(
    "/me/devices",
    response_model=DeviceOut,
    status_code=status.HTTP_201_CREATED,
    summary="Register an FCM token for push",
)
async def register_device(
    body: DeviceRegisterRequest, user: CurrentUser, session: DbSession
) -> DeviceOut:
    device = await device_service.register_device(
        session,
        user_id=user.id,
        fcm_token=body.fcm_token,
        platform=body.platform,
        app_version=body.app_version,
    )
    return DeviceOut.model_validate(device)


@router.delete(
    "/me/devices/{token}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Unregister an FCM token",
)
async def unregister_device(token: str, user: CurrentUser, session: DbSession) -> None:
    await device_service.unregister_device(session, user_id=user.id, fcm_token=token)
