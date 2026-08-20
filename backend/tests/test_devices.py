"""FCM device registration: upsert-by-token and cross-account moves."""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.device import DevicePlatform
from app.services import devices, user_profile


async def _make_user(session: AsyncSession):
    email = f"device-{uuid.uuid4().hex[:12]}@example.com"
    return await user_profile.create_profile(
        session,
        firebase_uid=f"uid-{uuid.uuid4().hex[:12]}",
        email=email,
        email_verified=True,
        display_name="Device Test",
    )


async def test_register_then_reregister_updates_in_place(session: AsyncSession) -> None:
    user = await _make_user(session)
    token = f"token-{uuid.uuid4().hex}"

    first = await devices.register_device(
        session,
        user_id=user.id,
        fcm_token=token,
        platform=DevicePlatform.ios,
        app_version="1.0.0",
    )
    second = await devices.register_device(
        session,
        user_id=user.id,
        fcm_token=token,
        platform=DevicePlatform.android,
        app_version="1.1.0",
    )

    assert first.id == second.id
    assert second.platform == DevicePlatform.android
    assert second.app_version == "1.1.0"


async def test_token_moves_between_accounts(session: AsyncSession) -> None:
    owner = await _make_user(session)
    new_owner = await _make_user(session)
    token = f"token-{uuid.uuid4().hex}"

    await devices.register_device(
        session,
        user_id=owner.id,
        fcm_token=token,
        platform=DevicePlatform.web,
        app_version=None,
    )
    moved = await devices.register_device(
        session,
        user_id=new_owner.id,
        fcm_token=token,
        platform=DevicePlatform.web,
        app_version=None,
    )

    assert moved.user_id == new_owner.id


async def test_unregister_is_idempotent_and_scoped_to_the_owner(
    session: AsyncSession,
) -> None:
    owner = await _make_user(session)
    other = await _make_user(session)
    token = f"token-{uuid.uuid4().hex}"

    await devices.register_device(
        session,
        user_id=owner.id,
        fcm_token=token,
        platform=DevicePlatform.ios,
        app_version=None,
    )

    # Someone else's delete of the same token does nothing.
    await devices.unregister_device(session, user_id=other.id, fcm_token=token)
    # Deleting a token that never existed also does nothing.
    await devices.unregister_device(session, user_id=owner.id, fcm_token="missing")

    await devices.unregister_device(session, user_id=owner.id, fcm_token=token)
    # Second delete by the rightful owner is a no-op too.
    await devices.unregister_device(session, user_id=owner.id, fcm_token=token)
