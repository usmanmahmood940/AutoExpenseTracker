"""Response models (and the shared `Email` field type) used across routes."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Annotated

from pydantic import AfterValidator, BaseModel, ConfigDict

from app.db.models.device import DevicePlatform


def _normalize_email(value: str) -> str:
    value = value.strip().lower()
    if "@" not in value or value.startswith("@") or value.endswith("@"):
        raise ValueError("Enter a valid email address.")
    return value


# Deliberately not `EmailStr` (which needs the `email-validator` extra) — this
# project only needs the same light `contains "@"` check the Cloud Functions
# it replaces used.
Email = Annotated[str, AfterValidator(_normalize_email)]


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    email_verified: bool
    display_name: str
    default_currency: str
    timezone: str
    bank_senders: list[str]
    email_filters: list[str]
    auto_categorize: bool
    created_at: datetime
    updated_at: datetime


class DeviceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    platform: DevicePlatform
    app_version: str | None
    last_seen_at: datetime


class AuthTokens(BaseModel):
    id_token: str
    refresh_token: str
    expires_in: int


class AuthResponse(BaseModel):
    tokens: AuthTokens
    user: UserOut


class OkResponse(BaseModel):
    ok: bool = True
