"""Inbound SMS/email ingest. Port of `ingestTransactionForUser`.

Webhook JSON stays camelCase (`ingestionId`, `receivedAt`) so Shortcuts that
eventually flip from the Cloud Function do not need a body rewrite.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.firebase import FirebaseIdentity
from app.db.models.enums import (
    ExternalIdType,
    IngestionSource,
    IngestionStatus,
    TransactionStatus,
    TransactionType,
)
from app.db.models.merchant_override import MerchantCategoryOverride
from app.db.models.raw_ingestion import RawIngestion
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.categories import allowed_category_names
from app.services.dates import day_name_from_date, parse_received_at
from app.services.dedup import DedupFields, compute_dedup_key, mask_account_id
from app.services.gemini import ParsedTransaction, ParseFail, parse_transaction
from app.services.merchant_key import normalize_merchant, normalize_merchant_key
from app.services.money import as_money
from app.services.user_profile import ensure_profile
from app.workers.summaries import recompute_for_date

logger = logging.getLogger(__name__)

INGESTION_SOURCES = {item.value for item in IngestionSource}
UID_RE = re.compile(r"^[a-zA-Z0-9_-]{1,128}$")
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


@dataclass(frozen=True)
class WebhookRequest:
    raw: str
    source: IngestionSource
    received_at: datetime
    received_at_raw: str
    bank: str | None
    message_id: str | None
    idempotency_key: str | None


@dataclass(frozen=True)
class WebhookResponse:
    success: bool
    ingestion_id: str | None = None
    transaction_id: str | None = None
    duplicate: bool | None = None
    error: str | None = None

    def as_json(self) -> dict[str, Any]:
        body: dict[str, Any] = {"success": self.success}
        if self.ingestion_id is not None:
            body["ingestionId"] = self.ingestion_id
        if self.transaction_id is not None:
            body["transactionId"] = self.transaction_id
        if self.duplicate:
            body["duplicate"] = True
        if self.error is not None:
            body["error"] = self.error
        return body


def is_valid_uid(uid: str) -> bool:
    return bool(UID_RE.fullmatch(uid))


def validate_webhook_body(
    body: Any,
) -> tuple[WebhookRequest | None, str | None]:
    if not isinstance(body, dict):
        return None, "Request body must be a JSON object"

    raw = body.get("raw")
    source = body.get("source")
    received_at = body.get("receivedAt")

    if not isinstance(raw, str) or not raw.strip():
        return None, "raw is required and must be a non-empty string"

    if not isinstance(source, str) or source not in INGESTION_SOURCES:
        return None, "source must be one of: ios_shortcut, gmail, manual"

    if not isinstance(received_at, str) or parse_received_at(received_at) is None:
        return None, (
            "receivedAt is required and must be ISO 8601 or dd/mm/yyyy with time "
            "(e.g. 10/07/2026, 6:02:00 PM GMT +5)"
        )

    message_id = body.get("messageId")
    if message_id is not None and not isinstance(message_id, str):
        return None, "messageId must be a string when provided"

    idempotency_key = body.get("idempotencyKey")
    if idempotency_key is not None and not isinstance(idempotency_key, str):
        return None, "idempotencyKey must be a string when provided"

    bank = body.get("bank")
    if bank is not None and not isinstance(bank, str):
        return None, "bank must be a string when provided"

    parsed_received = parse_received_at(received_at)
    if parsed_received is None:
        return None, (
            "receivedAt is required and must be ISO 8601 or dd/mm/yyyy with time "
            "(e.g. 10/07/2026, 6:02:00 PM GMT +5)"
        )
    return (
        WebhookRequest(
            raw=raw.strip(),
            source=IngestionSource(source),
            received_at=parsed_received,
            received_at_raw=received_at,
            bank=(bank.strip() or "Unknown") if isinstance(bank, str) else None,
            message_id=message_id,
            idempotency_key=idempotency_key,
        ),
        None,
    )


def validate_parsed(
    parsed: ParsedTransaction, allowed_categories: list[str]
) -> str | None:
    if not (parsed.amount > 0):
        return "amount must be a positive number"
    if not parsed.currency:
        return "currency is required"
    if parsed.type not in ("debit", "credit"):
        return "type must be debit or credit"
    if not parsed.merchant:
        return "merchant is required"
    if allowed_categories and parsed.category not in allowed_categories:
        return "category must be one of the default categories: " + ", ".join(
            allowed_categories
        )
    if not ISO_DATE_RE.match(parsed.transaction_date):
        return "transactionDate must be in YYYY-MM-DD format"
    if not (0 <= parsed.parse_confidence <= 1):
        return "parseConfidence must be a number between 0 and 1"
    return None


def _external_id_type(value: str) -> ExternalIdType:
    try:
        return ExternalIdType(value)
    except ValueError:
        return ExternalIdType.unknown


def _from_ingestion(ingestion: RawIngestion) -> WebhookResponse:
    tx_id = str(ingestion.transaction_id) if ingestion.transaction_id else None
    if ingestion.status is IngestionStatus.duplicate:
        return WebhookResponse(
            success=True,
            duplicate=True,
            ingestion_id=str(ingestion.id),
            transaction_id=tx_id,
        )
    if ingestion.status is IngestionStatus.parsed:
        return WebhookResponse(
            success=True,
            ingestion_id=str(ingestion.id),
            transaction_id=tx_id,
        )
    if ingestion.status is IngestionStatus.needs_parse:
        return WebhookResponse(
            success=False,
            ingestion_id=str(ingestion.id),
            error=ingestion.error or "Parsing needs manual review",
        )
    if ingestion.status is IngestionStatus.failed:
        return WebhookResponse(
            success=False,
            ingestion_id=str(ingestion.id),
            error=ingestion.error or "Ingestion failed",
        )
    return WebhookResponse(success=True, ingestion_id=str(ingestion.id))


async def _find_idempotent(
    session: AsyncSession, *, user_id: Any, key: str
) -> RawIngestion | None:
    result = await session.execute(
        select(RawIngestion).where(
            RawIngestion.user_id == user_id,
            RawIngestion.idempotency_key == key,
        )
    )
    return result.scalars().first()


async def _find_duplicate(
    session: AsyncSession, *, user_id: Any, dedup_key: str
) -> Transaction | None:
    result = await session.execute(
        select(Transaction).where(
            Transaction.user_id == user_id,
            Transaction.dedup_key == dedup_key,
        )
    )
    return result.scalars().first()


async def _load_override(
    session: AsyncSession, *, user_id: Any, merchant: str
) -> MerchantCategoryOverride | None:
    key = normalize_merchant_key(merchant)
    if not key:
        return None
    result = await session.execute(
        select(MerchantCategoryOverride).where(
            MerchantCategoryOverride.user_id == user_id,
            MerchantCategoryOverride.merchant_key == key,
        )
    )
    return result.scalar_one_or_none()


async def process_ingest(
    session: AsyncSession,
    *,
    user: User,
    request: WebhookRequest,
    settings: Settings,
) -> WebhookResponse:
    if request.idempotency_key:
        existing = await _find_idempotent(
            session, user_id=user.id, key=request.idempotency_key
        )
        if existing is not None:
            return _from_ingestion(existing)

    ingestion = RawIngestion(
        user_id=user.id,
        raw=request.raw,
        source=request.source,
        received_at=request.received_at,
        message_id=request.message_id,
        idempotency_key=request.idempotency_key,
        status=IngestionStatus.received,
    )
    session.add(ingestion)
    try:
        await session.commit()
        await session.refresh(ingestion)
    except IntegrityError:
        await session.rollback()
        if request.idempotency_key:
            existing = await _find_idempotent(
                session, user_id=user.id, key=request.idempotency_key
            )
            if existing is not None:
                return _from_ingestion(existing)
        raise
    ingestion_id = ingestion.id

    allowed = await allowed_category_names(session, user_id=user.id)
    parse_result = await parse_transaction(
        settings.gemini_api_key or "",
        request.raw,
        allowed,
    )

    if isinstance(parse_result, ParseFail):
        ingestion.status = IngestionStatus.needs_parse
        ingestion.error = parse_result.error[:1000]
        await session.commit()
        return WebhookResponse(
            success=False,
            ingestion_id=str(ingestion.id),
            error=parse_result.error,
        )

    parsed = parse_result.parsed
    field_error = validate_parsed(parsed, allowed)
    if field_error:
        ingestion.status = IngestionStatus.needs_parse
        ingestion.error = field_error
        await session.commit()
        return WebhookResponse(
            success=False,
            ingestion_id=str(ingestion.id),
            error=field_error,
        )

    dedup_key = compute_dedup_key(
        DedupFields(
            amount=parsed.amount,
            currency=parsed.currency,
            account_id=parsed.account_id,
            external_id=parsed.external_id,
            transaction_date=parsed.transaction_date,
            merchant=parsed.merchant,
            merchant_details=parsed.merchant_details,
            transaction_time=parsed.transaction_time,
        )
    )
    duplicate = await _find_duplicate(session, user_id=user.id, dedup_key=dedup_key)
    if duplicate is not None:
        ingestion.status = IngestionStatus.duplicate
        ingestion.transaction_id = duplicate.id
        await session.commit()
        return WebhookResponse(
            success=True,
            duplicate=True,
            ingestion_id=str(ingestion.id),
            transaction_id=str(duplicate.id),
        )

    category = parsed.category
    category_source = parse_result.model
    override = await _load_override(session, user_id=user.id, merchant=parsed.merchant)
    if override is not None:
        category = override.category
        category_source = "rule"

    confidence = Decimal(str(parsed.parse_confidence)).quantize(Decimal("0.001"))
    threshold = Decimal(str(settings.confidence_review_threshold))
    status = (
        TransactionStatus.needs_review
        if confidence < threshold
        else TransactionStatus.active
    )
    tx_date = date.fromisoformat(parsed.transaction_date)
    sms_source: dict[str, Any] = {
        "raw": request.raw,
        "source": request.source.value,
        "receivedAt": request.received_at.isoformat(),
    }
    if request.message_id:
        sms_source["messageId"] = request.message_id
    if request.idempotency_key:
        sms_source["idempotencyKey"] = request.idempotency_key

    tx = Transaction(
        user_id=user.id,
        amount=as_money(parsed.amount),
        currency=parsed.currency,
        type=TransactionType(parsed.type),
        merchant=parsed.merchant,
        merchant_details=parsed.merchant_details,
        merchant_normalized=normalize_merchant(parsed.merchant),
        is_recurring=False,
        category=category,
        category_source=category_source,
        payment_method=parsed.payment_method,
        bank=request.bank or parsed.bank,
        account_id=parsed.account_id,
        account_id_masked=mask_account_id(parsed.account_id),
        branch=parsed.branch,
        transaction_time=parsed.transaction_time,
        transaction_date=tx_date,
        day=day_name_from_date(parsed.transaction_date) or "Unknown",
        external_id=parsed.external_id,
        external_id_type=_external_id_type(parsed.external_id_type),
        dedup_key=dedup_key,
        sms_source=sms_source,
        parse_confidence=confidence,
        is_auto_detected=True,
        is_edited=False,
        is_duplicate=False,
        status=status,
    )
    session.add(tx)
    try:
        await session.flush()
        ingestion.transaction_id = tx.id
        ingestion.status = IngestionStatus.parsed
        await session.commit()
    except IntegrityError:
        await session.rollback()
        duplicate = await _find_duplicate(session, user_id=user.id, dedup_key=dedup_key)
        if duplicate is None:
            raise
        ingestion = await session.get(RawIngestion, ingestion_id)
        if ingestion is None:
            raise
        ingestion.status = IngestionStatus.duplicate
        ingestion.transaction_id = duplicate.id
        await session.commit()
        return WebhookResponse(
            success=True,
            duplicate=True,
            ingestion_id=str(ingestion.id),
            transaction_id=str(duplicate.id),
        )

    try:
        await recompute_for_date(session, user=user, tx_date=tx_date)
    except Exception:
        logger.exception(
            "summary_recompute_failed", extra={"yearMonth": tx_date.strftime("%Y-%m")}
        )

    return WebhookResponse(
        success=True,
        ingestion_id=str(ingestion.id),
        transaction_id=str(tx.id),
    )


async def ingest_for_identity(
    session: AsyncSession,
    *,
    identity: FirebaseIdentity,
    request: WebhookRequest,
    settings: Settings,
) -> tuple[WebhookResponse, User]:
    user = await ensure_profile(session, identity)
    result = await process_ingest(
        session, user=user, request=request, settings=settings
    )
    return result, user
