"""Async-friendly wrappers over the (blocking) Firebase Admin SDK user APIs.

The Admin SDK's calls are synchronous network I/O; every function here runs
the SDK call in FastAPI's threadpool so it never stalls the event loop.
"""

from __future__ import annotations

from dataclasses import dataclass

from firebase_admin import auth as firebase_auth
from starlette.concurrency import run_in_threadpool

from app.core import firebase
from app.core.errors import ConflictError, NotFoundError


@dataclass(frozen=True)
class FirebaseUser:
    uid: str
    email: str | None
    email_verified: bool
    disabled: bool


def _to_domain(record: firebase_auth.UserRecord) -> FirebaseUser:
    return FirebaseUser(
        uid=record.uid,
        email=record.email,
        email_verified=bool(record.email_verified),
        disabled=bool(record.disabled),
    )


async def get_by_email(email: str) -> FirebaseUser | None:
    app = firebase.require_app()

    def _fetch() -> FirebaseUser | None:
        try:
            return _to_domain(firebase_auth.get_user_by_email(email, app=app))
        except firebase_auth.UserNotFoundError:
            return None

    return await run_in_threadpool(_fetch)


async def create_user(*, email: str, password: str) -> FirebaseUser:
    app = firebase.require_app()

    def _create() -> FirebaseUser:
        try:
            record = firebase_auth.create_user(
                email=email, password=password, email_verified=True, app=app
            )
        except firebase_auth.EmailAlreadyExistsError as exc:
            raise ConflictError(
                "This email is already in use.", code="email_exists"
            ) from exc
        return _to_domain(record)

    return await run_in_threadpool(_create)


async def set_custom_claims(uid: str, claims: dict[str, object]) -> None:
    app = firebase.require_app()
    await run_in_threadpool(firebase_auth.set_custom_user_claims, uid, claims, app=app)


async def update_password(uid: str, new_password: str) -> None:
    app = firebase.require_app()

    def _update() -> None:
        try:
            firebase_auth.update_user(uid, password=new_password, app=app)
        except firebase_auth.UserNotFoundError as exc:
            raise NotFoundError("Account not found.", code="user_not_found") from exc

    await run_in_threadpool(_update)


async def revoke_refresh_tokens(uid: str) -> None:
    app = firebase.require_app()
    await run_in_threadpool(firebase_auth.revoke_refresh_tokens, uid, app=app)
