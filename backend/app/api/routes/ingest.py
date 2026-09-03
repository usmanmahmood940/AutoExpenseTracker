"""SMS/email ingest webhook. Same JSON contract as `ingestTransactionForUser`."""

from __future__ import annotations

import logging
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request, status
from fastapi.responses import JSONResponse

from app.api.deps import AppSettings, DbSession
from app.core.errors import AppError, ServiceUnavailableError
from app.core.firebase import FirebaseIdentity
from app.core.logging import uid_var
from app.db.models.transaction import Transaction
from app.services import firebase_users
from app.services.firebase_users import FirebaseUser
from app.services.ingest import (
    ingest_for_identity,
    is_valid_uid,
    validate_webhook_body,
)
from app.services.push import notify_new_transaction

logger = logging.getLogger(__name__)

router = APIRouter(tags=["ingest"])


def _error(http_status: int, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=http_status, content={"success": False, "error": message}
    )


async def _resolve_uid(
    *,
    x_user_id: str | None,
    uid_query: str | None,
) -> tuple[FirebaseUser | None, JSONResponse | None]:
    uid = (x_user_id or "").strip() or (uid_query or "").strip()
    if not uid:
        return None, _error(
            status.HTTP_400_BAD_REQUEST,
            "uid is required (X-User-Id header or ?uid= query parameter)",
        )
    if not is_valid_uid(uid):
        return None, _error(
            status.HTTP_400_BAD_REQUEST,
            "uid must be 1–128 characters: letters, digits, underscore, or hyphen",  # noqa: RUF001
        )
    try:
        record = await firebase_users.get_by_uid(uid)
    except ServiceUnavailableError:
        return None, _error(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Firebase Authentication is not configured for this project. "
            "Enable Authentication in the Firebase Console, then run: "
            "firebase deploy --only auth",
        )
    except Exception:
        logger.exception("ingest_uid_lookup_failed", extra={"uid": uid})
        return None, _error(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "Failed to verify uid with Firebase Auth",
        )
    if record is None:
        return None, _error(
            status.HTTP_404_NOT_FOUND,
            "uid does not exist in Firebase Auth",
        )
    return record, None


@router.post(
    "/ingest",
    summary="Parse an SMS/email into a transaction (webhook)",
    include_in_schema=True,
)
@router.post(
    "/webhooks/sms",
    summary="Alias of POST /ingest for Shortcuts",
    include_in_schema=False,
)
async def ingest(
    request: Request,
    session: DbSession,
    settings: AppSettings,
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
    x_ingest_secret: Annotated[str | None, Header(alias="X-Ingest-Secret")] = None,
    uid: Annotated[str | None, Query()] = None,
) -> JSONResponse:
    try:
        if (
            settings.ingest_shared_secret
            and x_ingest_secret != settings.ingest_shared_secret
        ):
            return _error(status.HTTP_401_UNAUTHORIZED, "Invalid ingest secret")

        record, err = await _resolve_uid(x_user_id=x_user_id, uid_query=uid)
        if err is not None or record is None:
            return err or _error(status.HTTP_400_BAD_REQUEST, "uid is required")
        uid_var.set(record.uid)

        try:
            body: Any = await request.json()
        except Exception:
            return _error(
                status.HTTP_400_BAD_REQUEST, "Request body must be a JSON object"
            )

        webhook, error = validate_webhook_body(body)
        if error or webhook is None:
            return _error(status.HTTP_400_BAD_REQUEST, error or "Invalid body")

        identity = FirebaseIdentity(
            uid=record.uid,
            email=record.email,
            email_verified=record.email_verified,
            claims={},
        )
        result, user = await ingest_for_identity(
            session, identity=identity, request=webhook, settings=settings
        )

        if result.success and result.transaction_id and not result.duplicate:
            tx = await session.get(Transaction, UUID(result.transaction_id))
            if tx is not None:
                try:
                    await notify_new_transaction(session, user_id=user.id, tx=tx)
                except Exception:
                    logger.exception(
                        "ingest_push_failed",
                        extra={"transactionId": result.transaction_id},
                    )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result.as_json())
    except AppError as exc:
        return _error(exc.status_code, exc.detail)
    except Exception:
        logger.exception("ingest_failed")
        return _error(status.HTTP_500_INTERNAL_SERVER_ERROR, "Internal server error")
