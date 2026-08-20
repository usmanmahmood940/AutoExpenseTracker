"""FCM device registration backing `POST/DELETE /me/devices`.

`fcm_token` is globally unique (see the `Device` model's docstring), so
registering a token already bound to another account moves it rather than
conflicting — the common case is the same physical device signing into a
different account.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import Device, DevicePlatform


async def register_device(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    fcm_token: str,
    platform: DevicePlatform,
    app_version: str | None,
) -> Device:
    result = await session.execute(select(Device).where(Device.fcm_token == fcm_token))
    device = result.scalar_one_or_none()
    if device is None:
        device = Device(fcm_token=fcm_token, user_id=user_id)
        session.add(device)

    device.user_id = user_id
    device.platform = platform
    device.app_version = app_version
    device.last_seen_at = datetime.now(UTC)

    await session.commit()
    await session.refresh(device)
    return device


async def unregister_device(
    session: AsyncSession, *, user_id: uuid.UUID, fcm_token: str
) -> None:
    """Idempotent: deleting a token that is missing or owned by someone else is
    a no-op, matching logout-time cleanup semantics."""
    result = await session.execute(
        select(Device).where(Device.fcm_token == fcm_token, Device.user_id == user_id)
    )
    device = result.scalar_one_or_none()
    if device is None:
        return
    await session.delete(device)
    await session.commit()
