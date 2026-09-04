"""Application configuration, loaded from environment / .env."""

from __future__ import annotations

from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

Environment = Literal["local", "dev", "staging", "prod"]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    environment: Environment = "local"
    service_name: str = "novaspend-api"
    log_level: str = "INFO"
    log_json: bool | None = None

    database_url: str = (
        "postgresql+asyncpg://novaspend:novaspend@localhost:5432/novaspend_dev"
    )
    db_pool_size: int = 5
    db_max_overflow: int = 5
    db_pool_timeout: int = 30
    db_pool_recycle: int = 1800
    db_echo: bool = False

    firebase_project_id: str | None = None
    google_application_credentials: str | None = None
    # Identity Toolkit web API key — needed in Phase B for server-side password
    # sign-in. Unused in Phase A.
    firebase_web_api_key: str | None = None
    # Rejects tokens whose refresh tokens were revoked (change/reset password).
    # Costs one Admin SDK user lookup per request.
    verify_token_revoked: bool = True

    # --- Phase B: auth OTP + email ---
    # HMAC key for OTP codes at rest. If unset, a random key is generated at
    # process startup (logged once) so local dev works with no setup; outstanding
    # OTPs simply stop verifying across a restart, which is fine given their
    # 10-minute lifetime. Set a real value in dev/staging/prod so a restart never
    # invalidates a code a user is about to enter.
    otp_hash_secret: str | None = None
    otp_length: int = 6
    otp_expiry_minutes: int = 10
    otp_max_attempts: int = 5
    reset_session_expiry_minutes: int = 10

    # If unset, OTP emails are logged instead of sent — lets signup/reset be
    # exercised end-to-end (Swagger, tests) with no Resend account.
    resend_api_key: str | None = None
    resend_from_email: str = "NovaSpend <onboarding@resend.dev>"

    # Sliding-window limits, mirroring the Cloud Functions implementation.
    otp_send_limit_per_email: int = 5
    otp_send_limit_per_ip: int = 20
    otp_verify_limit_per_email: int = 10
    login_limit_per_email: int = 10
    login_limit_per_ip: int = 30
    rate_limit_window_minutes: int = 15

    gemini_api_key: str | None = None
    gemini_embedding_model: str = "text-embedding-004"
    ingest_shared_secret: str | None = None
    cron_secret: str | None = None
    confidence_review_threshold: float = 0.8
    chat_ask_limit_per_user: int = 20
    chat_min_transactions: int = 10

    # AES-256-GCM DEK for SMS payloads (raw_ingestions.raw, sms_source).
    # Base64-encoded 32 bytes. Required outside local; local generates an
    # ephemeral key if unset (encrypted rows will not decrypt after restart).
    field_encryption_key: str | None = None

    min_password_length: int = 6

    # NoDecode: accept a comma-separated string instead of pydantic-settings'
    # default JSON decoding, so `CORS_ORIGINS=` and `a,b` both work.
    cors_origins: Annotated[list[str], NoDecode] = Field(default_factory=list)

    docs_enabled: bool = True

    @field_validator("database_url")
    @classmethod
    def _require_async_driver(cls, value: str) -> str:
        """Normalize libpq-style URLs to the asyncpg driver SQLAlchemy needs.

        Cloud SQL and Supabase both hand out `postgresql://` URLs, and pasting one
        straight into .env would otherwise fail at engine creation.
        """
        if value.startswith("postgresql+asyncpg://"):
            return value
        for prefix in ("postgresql://", "postgres://"):
            if value.startswith(prefix):
                return "postgresql+asyncpg://" + value[len(prefix) :]
        raise ValueError(
            "database_url must be a PostgreSQL URL "
            "(postgresql+asyncpg://user:pass@host:port/db)"
        )

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

    @field_validator("log_level")
    @classmethod
    def _upper_log_level(cls, value: str) -> str:
        return value.upper()

    @model_validator(mode="after")
    def _apply_environment_defaults(self) -> Settings:
        if self.log_json is None:
            self.log_json = self.environment != "local"
        key = (self.field_encryption_key or "").strip()
        if self.environment != "local" and not key:
            raise ValueError(
                "FIELD_ENCRYPTION_KEY is required when ENVIRONMENT is not local"
            )
        return self

    @property
    def is_local(self) -> bool:
        return self.environment == "local"

    @property
    def sync_database_url(self) -> str:
        """psycopg-style URL, for tools that cannot drive asyncpg."""
        return self.database_url.replace("postgresql+asyncpg://", "postgresql://", 1)


@lru_cache
def get_settings() -> Settings:
    return Settings()
