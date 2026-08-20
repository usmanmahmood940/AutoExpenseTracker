"""OTP issue/verify: hashing, expiry, replacement, and attempt limits."""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import BadRequestError, NotFoundError, RateLimitedError
from app.db.models.auth_otp import OtpPurpose
from app.services import otp


def _settings(**overrides: object) -> Settings:
    defaults: dict[str, object] = {
        "database_url": "postgresql+asyncpg://u:p@localhost:5432/db",
        "otp_hash_secret": "test-secret",
        "_env_file": None,
    }
    return Settings(**{**defaults, **overrides})  # type: ignore[arg-type]


def _email() -> str:
    return f"otp-{uuid.uuid4().hex[:12]}@example.com"


async def test_issue_then_verify_consumes_the_code(session: AsyncSession) -> None:
    settings = _settings()
    email = _email()

    code = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.email_verification
    )
    await otp.verify_and_consume_otp(
        session,
        settings,
        email=email,
        purpose=OtpPurpose.email_verification,
        code=code,
    )

    # Consumed: verifying again finds nothing outstanding.
    with pytest.raises(NotFoundError):
        await otp.verify_and_consume_otp(
            session,
            settings,
            email=email,
            purpose=OtpPurpose.email_verification,
            code=code,
        )


async def test_wrong_code_is_rejected_without_consuming(session: AsyncSession) -> None:
    settings = _settings()
    email = _email()

    code = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.email_verification
    )
    wrong = "000000" if code != "000000" else "111111"

    with pytest.raises(BadRequestError):
        await otp.verify_and_consume_otp(
            session,
            settings,
            email=email,
            purpose=OtpPurpose.email_verification,
            code=wrong,
        )

    # The real code still works — a wrong guess doesn't burn the outstanding OTP.
    await otp.verify_and_consume_otp(
        session,
        settings,
        email=email,
        purpose=OtpPurpose.email_verification,
        code=code,
    )


async def test_max_attempts_exhausts_the_code(session: AsyncSession) -> None:
    settings = _settings(otp_max_attempts=2)
    email = _email()

    code = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.email_verification
    )
    wrong = "000000" if code != "000000" else "111111"

    for _ in range(settings.otp_max_attempts):
        with pytest.raises(BadRequestError):
            await otp.verify_and_consume_otp(
                session,
                settings,
                email=email,
                purpose=OtpPurpose.email_verification,
                code=wrong,
            )

    # One more attempt (even the right one) finds the row gone.
    with pytest.raises(RateLimitedError):
        await otp.verify_and_consume_otp(
            session,
            settings,
            email=email,
            purpose=OtpPurpose.email_verification,
            code=code,
        )


async def test_resend_replaces_the_outstanding_code(session: AsyncSession) -> None:
    settings = _settings()
    email = _email()

    first = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.email_verification
    )
    second = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.email_verification
    )

    with pytest.raises(BadRequestError):
        await otp.verify_and_consume_otp(
            session,
            settings,
            email=email,
            purpose=OtpPurpose.email_verification,
            code=first,
        )
    await otp.verify_and_consume_otp(
        session,
        settings,
        email=email,
        purpose=OtpPurpose.email_verification,
        code=second,
    )


async def test_purposes_do_not_collide(session: AsyncSession) -> None:
    settings = _settings()
    email = _email()

    signup_code = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.email_verification
    )
    reset_code = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.password_reset
    )

    await otp.verify_and_consume_otp(
        session,
        settings,
        email=email,
        purpose=OtpPurpose.email_verification,
        code=signup_code,
    )
    await otp.verify_and_consume_otp(
        session,
        settings,
        email=email,
        purpose=OtpPurpose.password_reset,
        code=reset_code,
    )
