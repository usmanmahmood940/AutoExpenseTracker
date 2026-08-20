"""Shared route dependencies."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import firebase
from app.core.config import Settings, get_settings
from app.core.errors import UnauthorizedError
from app.core.firebase import FirebaseIdentity
from app.core.logging import uid_var
from app.db.models.user import User
from app.db.session import get_session
from app.services import user_profile

# auto_error=False so a missing header produces our envelope, not FastAPI's.
bearer_scheme = HTTPBearer(auto_error=False, description="Firebase ID token")

DbSession = Annotated[AsyncSession, Depends(get_session)]
AppSettings = Annotated[Settings, Depends(get_settings)]


async def get_current_identity(
    settings: AppSettings,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ] = None,
) -> FirebaseIdentity:
    """Verify the Bearer ID token and expose its claims.

    Phase B layers `get_current_user` on top of this to resolve the Postgres
    profile; product routes should depend on that instead.
    """
    if credentials is None or not credentials.credentials:
        raise UnauthorizedError("Missing bearer token.", code="token_missing")

    identity = firebase.verify_id_token(
        credentials.credentials,
        check_revoked=settings.verify_token_revoked,
    )
    uid_var.set(identity.uid)
    return identity


CurrentIdentity = Annotated[FirebaseIdentity, Depends(get_current_identity)]


async def get_current_user(identity: CurrentIdentity, session: DbSession) -> User:
    """The Postgres profile for the verified token, self-healing (create on
    first sight) exactly like the old `ensureUserProfile` callable."""
    return await user_profile.ensure_profile(session, identity)


CurrentUser = Annotated[User, Depends(get_current_user)]
