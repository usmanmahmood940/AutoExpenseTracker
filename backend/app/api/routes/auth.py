"""Auth façade over Firebase Auth.

Firebase stays the credential store and token issuer; this module only owns
the OTP/rate-limit/reset-session bookkeeping and the Postgres profile that
Firebase itself has no notion of. Port of `functions/src/auth.ts`.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Request
from pydantic import BaseModel, field_validator

from app.api.deps import AppSettings, CurrentIdentity, DbSession
from app.api.schemas import AuthResponse, AuthTokens, Email, OkResponse, UserOut
from app.core import firebase
from app.core.config import Settings
from app.core.errors import BadRequestError, ConflictError, NotFoundError
from app.db.models.auth_otp import OtpPurpose
from app.services import (
    firebase_users,
    identity_toolkit,
    mailer,
    otp,
    rate_limit,
    reset_session,
    user_profile,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


def _client_ip(request: Request) -> str:
    if forwarded := request.headers.get("x-forwarded-for"):
        return forwarded.split(",", 1)[0].strip() or "unknown"
    return request.client.host if request.client else "unknown"


def _otp_email_html(*, lead: str, code: str, expiry_minutes: int) -> str:
    return (
        f"<p>{lead} <strong>{code}</strong>.</p>"
        f"<p>This code expires in {expiry_minutes} minutes.</p>"
    )


def _require_min_password(settings: Settings, value: str) -> None:
    if len(value) < settings.min_password_length:
        raise BadRequestError(
            f"Password must be at least {settings.min_password_length} characters.",
            code="password_too_short",
        )


def _digits_only(value: str) -> str:
    value = value.strip()
    if not value.isdigit():
        raise ValueError("Enter a valid code.")
    return value


class EmailRequest(BaseModel):
    email: Email


class SignupCompleteRequest(BaseModel):
    email: Email
    password: str
    code: str

    @field_validator("code")
    @classmethod
    def _code_is_digits(cls, value: str) -> str:
        return _digits_only(value)


class LoginRequest(BaseModel):
    email: Email
    password: str


class VerifyResetOtpRequest(BaseModel):
    email: Email
    code: str

    @field_validator("code")
    @classmethod
    def _code_is_digits(cls, value: str) -> str:
        return _digits_only(value)


class VerifyResetOtpResponse(BaseModel):
    reset_token: str


class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str


async def _tokens_and_profile(
    session: DbSession, settings: Settings, *, email: str, password: str
) -> AuthResponse:
    """Signs in via Identity Toolkit, then loads/creates the Postgres profile
    from the freshly issued ID token's claims."""
    signed_in = await identity_toolkit.sign_in_with_password(
        settings, email=email, password=password
    )
    # Freshly minted, so it cannot be revoked yet — skip the extra Admin lookup.
    identity = firebase.verify_id_token(signed_in.id_token, check_revoked=False)
    user = await user_profile.ensure_profile(session, identity)
    return AuthResponse(
        tokens=AuthTokens(
            id_token=signed_in.id_token,
            refresh_token=signed_in.refresh_token,
            expires_in=signed_in.expires_in,
        ),
        user=UserOut.model_validate(user),
    )


@router.post("/signup/otp", response_model=OkResponse, summary="Start email signup")
async def start_signup(
    body: EmailRequest,
    request: Request,
    settings: AppSettings,
    session: DbSession,
) -> OkResponse:
    email = body.email
    ip = _client_ip(request)

    # Fail before sending any code — authoritative existence check.
    if await firebase_users.get_by_email(email) is not None:
        raise ConflictError("This email is already in use.", code="email_exists")

    await rate_limit.enforce_rate_limit(
        session,
        settings,
        scope="otp_send_email",
        key=email,
        limit=settings.otp_send_limit_per_email,
    )
    await rate_limit.enforce_rate_limit(
        session,
        settings,
        scope="otp_send_ip",
        key=ip,
        limit=settings.otp_send_limit_per_ip,
    )

    code = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.email_verification
    )
    await mailer.send_email(
        settings,
        to=email,
        subject="Your NovaSpend verification code",
        html=_otp_email_html(
            lead="Your NovaSpend verification code is",
            code=code,
            expiry_minutes=settings.otp_expiry_minutes,
        ),
    )
    return OkResponse()


@router.post("/signup", response_model=AuthResponse, summary="Complete email signup")
async def complete_signup(
    body: SignupCompleteRequest, settings: AppSettings, session: DbSession
) -> AuthResponse:
    email = body.email
    _require_min_password(settings, body.password)

    # Checked again here so a signup can't outrun a concurrent one for the
    # same email before consuming the OTP.
    if await firebase_users.get_by_email(email) is not None:
        raise ConflictError("This email is already in use.", code="email_exists")

    await otp.verify_and_consume_otp(
        session,
        settings,
        email=email,
        purpose=OtpPurpose.email_verification,
        code=body.code,
    )

    firebase_user = await firebase_users.create_user(
        email=email, password=body.password
    )
    await firebase_users.set_custom_claims(
        firebase_user.uid, {"emailOtpVerified": True}
    )

    await user_profile.create_profile(
        session,
        firebase_uid=firebase_user.uid,
        email=email,
        email_verified=True,
        display_name=email.split("@")[0],
    )

    return await _tokens_and_profile(
        session, settings, email=email, password=body.password
    )


@router.post("/login", response_model=AuthResponse, summary="Password sign-in")
async def login(
    body: LoginRequest,
    request: Request,
    settings: AppSettings,
    session: DbSession,
) -> AuthResponse:
    email = body.email
    ip = _client_ip(request)

    await rate_limit.enforce_rate_limit(
        session,
        settings,
        scope="login_email",
        key=email,
        limit=settings.login_limit_per_email,
    )
    await rate_limit.enforce_rate_limit(
        session,
        settings,
        scope="login_ip",
        key=ip,
        limit=settings.login_limit_per_ip,
    )

    return await _tokens_and_profile(
        session, settings, email=email, password=body.password
    )


@router.post(
    "/forgot-password", response_model=OkResponse, summary="Request a reset code"
)
async def forgot_password(
    body: EmailRequest,
    request: Request,
    settings: AppSettings,
    session: DbSession,
) -> OkResponse:
    email = body.email
    ip = _client_ip(request)

    # Always look successful, whether or not the account exists, to avoid
    # account enumeration.
    if await firebase_users.get_by_email(email) is None:
        logger.info("password_reset_requested_for_unknown_email")
        return OkResponse()

    await rate_limit.enforce_rate_limit(
        session,
        settings,
        scope="otp_send_email",
        key=email,
        limit=settings.otp_send_limit_per_email,
    )
    await rate_limit.enforce_rate_limit(
        session,
        settings,
        scope="otp_send_ip",
        key=ip,
        limit=settings.otp_send_limit_per_ip,
    )

    code = await otp.issue_otp(
        session, settings, email=email, purpose=OtpPurpose.password_reset
    )
    await mailer.send_email(
        settings,
        to=email,
        subject="Your NovaSpend password reset code",
        html=_otp_email_html(
            lead="Your NovaSpend password reset code is",
            code=code,
            expiry_minutes=settings.otp_expiry_minutes,
        ),
    )
    return OkResponse()


@router.post(
    "/verify-reset-otp",
    response_model=VerifyResetOtpResponse,
    summary="Verify a reset code",
)
async def verify_reset_otp(
    body: VerifyResetOtpRequest, settings: AppSettings, session: DbSession
) -> VerifyResetOtpResponse:
    email = body.email

    await rate_limit.enforce_rate_limit(
        session,
        settings,
        scope="otp_verify_email",
        key=email,
        limit=settings.otp_verify_limit_per_email,
    )

    await otp.verify_and_consume_otp(
        session,
        settings,
        email=email,
        purpose=OtpPurpose.password_reset,
        code=body.code,
    )

    if await firebase_users.get_by_email(email) is None:
        raise NotFoundError("No account found for this email.", code="user_not_found")

    user = await user_profile.get_by_email(session, email)
    if user is None:
        raise NotFoundError("No account found for this email.", code="user_not_found")

    token = await reset_session.issue(session, settings, user_id=user.id, email=email)
    return VerifyResetOtpResponse(reset_token=token)


@router.post(
    "/reset-password", response_model=OkResponse, summary="Complete a password reset"
)
async def complete_reset_password(
    body: ResetPasswordRequest, settings: AppSettings, session: DbSession
) -> OkResponse:
    _require_min_password(settings, body.new_password)

    session_row = await reset_session.consume(session, token=body.reset_token)
    user = await user_profile.get_by_id(session, session_row.user_id)
    if user is None:
        raise NotFoundError(
            "Reset session expired. Start again.", code="reset_session_invalid"
        )

    await firebase_users.update_password(user.firebase_uid, body.new_password)
    await firebase_users.revoke_refresh_tokens(user.firebase_uid)
    return OkResponse()


@router.post(
    "/change-password",
    response_model=OkResponse,
    summary="Change password while signed in",
)
async def change_password(
    body: ChangePasswordRequest,
    identity: CurrentIdentity,
    settings: AppSettings,
) -> OkResponse:
    _require_min_password(settings, body.new_password)
    if not identity.email:
        raise BadRequestError("Account has no email on file.", code="no_email")

    # Verifies the *current* password the same way `/auth/login` does.
    await identity_toolkit.sign_in_with_password(
        settings, email=identity.email, password=body.old_password
    )

    await firebase_users.update_password(identity.uid, body.new_password)
    await firebase_users.revoke_refresh_tokens(identity.uid)
    return OkResponse()


@router.post(
    "/logout",
    response_model=OkResponse,
    summary="Revoke the current refresh token family",
)
async def logout(identity: CurrentIdentity) -> OkResponse:
    await firebase_users.revoke_refresh_tokens(identity.uid)
    return OkResponse()
