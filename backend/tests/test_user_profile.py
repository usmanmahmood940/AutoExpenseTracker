"""Postgres profile lookup/creation, including the self-healing `ensure_profile`
path used by `/me` and `/auth/login` for accounts that predate their row."""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.firebase import FirebaseIdentity
from app.db.models.user import DEFAULT_CURRENCY, DEFAULT_TIMEZONE
from app.services import user_profile


async def test_ensure_profile_creates_a_row_on_first_sight(
    session: AsyncSession,
) -> None:
    uid = f"uid-{uuid.uuid4().hex[:12]}"
    email = f"{uid}@example.com"
    identity = FirebaseIdentity(uid=uid, email=email, email_verified=True, claims={})

    user = await user_profile.ensure_profile(session, identity)

    assert user.firebase_uid == uid
    assert user.email == email
    assert user.display_name == uid  # derived from the email's local part
    assert user.default_currency == DEFAULT_CURRENCY
    assert user.timezone == DEFAULT_TIMEZONE


async def test_ensure_profile_is_idempotent(session: AsyncSession) -> None:
    uid = f"uid-{uuid.uuid4().hex[:12]}"
    email = f"{uid}@example.com"
    identity = FirebaseIdentity(uid=uid, email=email, email_verified=True, claims={})

    first = await user_profile.ensure_profile(session, identity)
    second = await user_profile.ensure_profile(session, identity)

    assert first.id == second.id


async def test_get_by_email_and_by_id(session: AsyncSession) -> None:
    email = f"lookup-{uuid.uuid4().hex[:12]}@example.com"
    created = await user_profile.create_profile(
        session,
        firebase_uid=f"uid-{uuid.uuid4().hex[:12]}",
        email=email,
        email_verified=False,
        display_name="Lookup Test",
    )

    by_email = await user_profile.get_by_email(session, email)
    by_id = await user_profile.get_by_id(session, created.id)

    assert by_email is not None and by_email.id == created.id
    assert by_id is not None and by_id.id == created.id
