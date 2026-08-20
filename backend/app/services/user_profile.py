"""Postgres `users` row: the app-side profile keyed to a Firebase account."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.firebase import FirebaseIdentity
from app.db.models.user import User


async def get_by_firebase_uid(session: AsyncSession, uid: str) -> User | None:
    result = await session.execute(select(User).where(User.firebase_uid == uid))
    return result.scalar_one_or_none()


async def get_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_by_id(session: AsyncSession, user_id: uuid.UUID) -> User | None:
    return await session.get(User, user_id)


async def create_profile(
    session: AsyncSession,
    *,
    firebase_uid: str,
    email: str,
    email_verified: bool,
    display_name: str,
) -> User:
    user = User(
        firebase_uid=firebase_uid,
        email=email,
        email_verified=email_verified,
        display_name=display_name,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def ensure_profile(session: AsyncSession, identity: FirebaseIdentity) -> User:
    """Self-healing lookup used by `/me` and `/auth/login`: creates the Postgres
    row for a Firebase account that predates it, mirroring the old
    `ensureUserProfile` callable."""
    user = await get_by_firebase_uid(session, identity.uid)
    if user is not None:
        return user

    email = (identity.email or "").lower()
    display_name = email.split("@")[0] if email else identity.uid

    try:
        return await create_profile(
            session,
            firebase_uid=identity.uid,
            email=email,
            email_verified=identity.email_verified,
            display_name=display_name,
        )
    except IntegrityError:
        # Lost a race with a concurrent request creating the same row.
        await session.rollback()
        user = await get_by_firebase_uid(session, identity.uid)
        if user is not None:
            return user
        raise
