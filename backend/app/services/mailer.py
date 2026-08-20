"""Outbound email via Resend.

If `RESEND_API_KEY` is unset, the message is logged instead of sent — lets
signup/reset OTP flows be exercised end-to-end (Swagger, tests, a fresh
`make run`) with no Resend account.
"""

from __future__ import annotations

import logging

import httpx

from app.core.config import Settings
from app.core.errors import ServiceUnavailableError

logger = logging.getLogger(__name__)

_RESEND_URL = "https://api.resend.com/emails"


async def send_email(settings: Settings, *, to: str, subject: str, html: str) -> None:
    if not settings.resend_api_key:
        logger.warning(
            "email_not_sent_dev_fallback",
            extra={"to": to, "subject": subject, "html": html},
        )
        return

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            _RESEND_URL,
            headers={"Authorization": f"Bearer {settings.resend_api_key}"},
            json={
                "from": settings.resend_from_email,
                "to": [to],
                "subject": subject,
                "html": html,
            },
        )

    if response.status_code >= 400:
        logger.error(
            "resend_email_failed",
            extra={"status": response.status_code, "body": response.text},
        )
        raise ServiceUnavailableError(
            "Failed to send email. Please try again.", code="email_send_failed"
        )
