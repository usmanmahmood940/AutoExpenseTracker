"""Firestore → Postgres copy for §6 step 5 / Phase F.

ID rule (locked 2026-08-21): keep a Firestore document id when it is already a
UUID (Flutter `Uuid().v4()` rows). Auto-ids from `doc()` are 20-char Firestore
ids — those become a stable UUIDv5 so a second run is idempotent and ingestion
`transaction_id` pointers still resolve.

Does not touch Firebase Auth users, FCM delivery, or ephemeral `authTemp` /
`authRateLimits` docs. Global default categories are already seeded; only
per-user custom categories are copied.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from decimal import Decimal, InvalidOperation
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import DBAPIError, IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.category import Category
from app.db.models.enums import (
    CategoryType,
    ExternalIdType,
    IngestionSource,
    IngestionStatus,
    TransactionStatus,
    TransactionType,
)
from app.db.models.merchant_override import MerchantCategoryOverride
from app.db.models.monthly_summary import MonthlySummary
from app.db.models.user import DEFAULT_CURRENCY, DEFAULT_TIMEZONE, User
from app.services.categories import CUSTOM_SORT_ORDER, _slugify
from app.services.merchant_key import normalize_merchant_key, resolve_merchant
from app.services.money import as_money
from app.services.sms_source import build_sms_source, encrypt_ingestion_raw

logger = logging.getLogger(__name__)

# URL namespace + a product-specific prefix so ids don't collide with other
# uuid5 users of NAMESPACE_URL.
_ID_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, "https://novaspend.app/firestore")


@dataclass
class MigrateCounts:
    users: int = 0
    users_updated: int = 0
    transactions: int = 0
    ingestions: int = 0
    categories: int = 0
    overrides: int = 0
    summaries: int = 0
    skipped: int = 0
    errors: list[str] = field(default_factory=list)

    def add_error(self, message: str) -> None:
        logger.warning("migrate_skip: %s", message)
        self.errors.append(message)
        self.skipped += 1


def stable_uuid(kind: str, uid: str, doc_id: str) -> uuid.UUID:
    """Map a Firestore document id onto a Postgres UUID primary key."""
    try:
        return uuid.UUID(doc_id)
    except ValueError:
        return uuid.uuid5(_ID_NAMESPACE, f"{kind}:{uid}:{doc_id}")


def as_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value
    if hasattr(value, "timestamp"):
        try:
            ts = float(value.timestamp())  # DatetimeWithNanoseconds / Timestamp
        except (TypeError, ValueError):
            ts = None
        if ts is not None:
            return datetime.fromtimestamp(ts, tz=UTC)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=UTC)
        return parsed
    return None


def as_date(value: Any) -> date | None:
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, str) and len(value) >= 10:
        try:
            return date.fromisoformat(value[:10])
        except ValueError:
            return None
    dt = as_datetime(value)
    return dt.date() if dt is not None else None


def as_str_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value if str(item).strip()]


def as_num_map(value: Any) -> dict[str, float]:
    if not isinstance(value, dict):
        return {}
    out: dict[str, float] = {}
    for key, raw in value.items():
        try:
            out[str(key)] = float(raw)
        except (TypeError, ValueError):
            continue
    return out


def _clip(value: Any, length: int) -> str | None:
    if value is None:
        return None
    text = str(value)
    if not text:
        return None
    return text[:length]


def _enum_or(enum_cls: type, raw: Any, default: Any) -> Any:
    if raw is None:
        return default
    try:
        return enum_cls(str(raw))
    except ValueError:
        return default


def user_fields_from_doc(
    data: dict[str, Any], *, email: str, email_verified: bool
) -> dict[str, Any]:
    settings = data.get("settings") if isinstance(data.get("settings"), dict) else {}
    display = (data.get("displayName") or "").strip()
    if not display:
        display = email.split("@")[0] if email else ""
    currency = (data.get("defaultCurrency") or DEFAULT_CURRENCY).strip().upper()[:3]
    return {
        "email": email.lower(),
        "email_verified": email_verified,
        "display_name": display[:200],
        "default_currency": currency or DEFAULT_CURRENCY,
        "timezone": (data.get("timezone") or DEFAULT_TIMEZONE)[:64],
        "bank_senders": as_str_list(data.get("bankSenders")),
        "email_filters": as_str_list(data.get("emailFilters")),
        "auto_categorize": bool(settings.get("autoCategorize", True)),
    }


def transaction_kwargs(
    *,
    uid: str,
    doc_id: str,
    user_id: uuid.UUID,
    data: dict[str, Any],
) -> dict[str, Any] | None:
    tx_date = as_date(data.get("transactionDate"))
    if tx_date is None:
        return None
    category = (data.get("category") or "Uncategorized")[:100]
    payment_method = (data.get("paymentMethod") or "unknown")[:64]
    raw_merchant = (data.get("merchant") or "Unknown").strip() or "Unknown"
    merchant = resolve_merchant(
        raw_merchant, category=category, payment_method=payment_method
    )
    try:
        amount = as_money(data.get("amount") or 0)
    except (InvalidOperation, ValueError):
        return None
    sms = data.get("smsSource") if isinstance(data.get("smsSource"), dict) else {}
    received = as_datetime(sms.get("receivedAt"))
    sms_source = build_sms_source(
        raw_plaintext=str(sms.get("raw") or ""),
        source=str(sms.get("source") or "manual"),
        user_id=user_id,
        received_at=received,
        message_id=sms.get("messageId"),
        idempotency_key=sms.get("idempotencyKey"),
    )
    confidence = data.get("parseConfidence", 1)
    try:
        parse_confidence = Decimal(str(confidence))
    except (InvalidOperation, ValueError):
        parse_confidence = Decimal("1")
    if parse_confidence < 0:
        parse_confidence = Decimal("0")
    if parse_confidence > 1:
        parse_confidence = Decimal("1")

    normalized = (data.get("merchantNormalized") or "").strip()
    if not normalized or merchant != raw_merchant:
        normalized = normalize_merchant_key(merchant)

    return {
        "id": stable_uuid("tx", uid, doc_id),
        "user_id": user_id,
        "amount": amount,
        "currency": (data.get("currency") or "PKR").strip().upper()[:3] or "PKR",
        "type": _enum_or(TransactionType, data.get("type"), TransactionType.debit),
        "merchant": merchant[:200],
        "merchant_details": (
            str(data["merchantDetails"])[:500] if data.get("merchantDetails") else None
        ),
        "merchant_normalized": normalized[:200],
        "is_recurring": bool(data.get("isRecurring", False)),
        "recurring_group_id": _clip(data.get("recurringGroupId"), 64),
        "category": category,
        "category_source": (data.get("categorySource") or "rule")[:64],
        "payment_method": payment_method,
        "bank": (data.get("bank") or "")[:100],
        "account_id": (data.get("accountId") or "")[:100],
        "account_id_masked": (data.get("accountIdMasked") or "")[:32],
        "branch": _clip(data.get("branch"), 100),
        "transaction_time": (data.get("transactionTime") or "")[:32],
        "transaction_date": tx_date,
        "day": (data.get("day") or "")[:16],
        "external_id": _clip(data.get("externalId"), 128),
        "external_id_type": _enum_or(
            ExternalIdType, data.get("externalIdType"), ExternalIdType.unknown
        ),
        "dedup_key": (data.get("dedupKey") or f"migrated_{doc_id}")[:256],
        "sms_source": sms_source,
        "parse_confidence": parse_confidence,
        "is_auto_detected": bool(data.get("isAutoDetected", True)),
        "is_edited": bool(data.get("isEdited", False)),
        "is_duplicate": bool(data.get("isDuplicate", False)),
        "status": _enum_or(
            TransactionStatus, data.get("status"), TransactionStatus.active
        ),
        "reviewed_at": as_datetime(data.get("reviewedAt")),
        "created_at": as_datetime(data.get("createdAt")) or datetime.now(UTC),
        "updated_at": as_datetime(data.get("updatedAt")) or datetime.now(UTC),
    }


def ingestion_kwargs(
    *,
    uid: str,
    doc_id: str,
    user_id: uuid.UUID,
    data: dict[str, Any],
) -> dict[str, Any] | None:
    raw = (data.get("raw") or "").strip()
    if not raw:
        return None
    received = as_datetime(data.get("receivedAt")) or datetime.now(UTC)
    tx_ref = data.get("transactionId")
    tx_id = None
    if isinstance(tx_ref, str) and tx_ref:
        tx_id = stable_uuid("tx", uid, tx_ref)
    return {
        "id": stable_uuid("ing", uid, doc_id),
        "user_id": user_id,
        "raw": encrypt_ingestion_raw(raw[:8000], user_id=user_id),
        "source": _enum_or(IngestionSource, data.get("source"), IngestionSource.manual),
        "received_at": received,
        "message_id": _clip(data.get("messageId"), 256),
        "idempotency_key": _clip(data.get("idempotencyKey"), 256),
        "status": _enum_or(
            IngestionStatus, data.get("status"), IngestionStatus.received
        ),
        "transaction_id": tx_id,
        "error": (str(data["error"])[:1000] if data.get("error") else None),
        "created_at": as_datetime(data.get("createdAt")) or received,
        "updated_at": as_datetime(data.get("updatedAt")) or received,
    }


async def upsert_user(
    session: AsyncSession,
    *,
    firebase_uid: str,
    fields: dict[str, Any],
    counts: MigrateCounts,
    dry_run: bool,
) -> User | None:
    existing = (
        await session.execute(select(User).where(User.firebase_uid == firebase_uid))
    ).scalar_one_or_none()
    if dry_run:
        if existing is None:
            counts.users += 1
        else:
            counts.users_updated += 1
        return existing or User(firebase_uid=firebase_uid, **fields)

    if existing is None:
        user = User(firebase_uid=firebase_uid, **fields)
        try:
            async with session.begin_nested():
                session.add(user)
                await session.flush()
        except IntegrityError:
            counts.add_error(
                f"user {firebase_uid}: email conflict {fields.get('email')}"
            )
            return (
                await session.execute(
                    select(User).where(User.firebase_uid == firebase_uid)
                )
            ).scalar_one_or_none()
        counts.users += 1
        return user

    for key, value in fields.items():
        setattr(existing, key, value)
    counts.users_updated += 1
    return existing


async def insert_if_new(
    session: AsyncSession,
    model: type,
    kwargs: dict[str, Any],
    counts: MigrateCounts,
    counter: str,
    dry_run: bool,
) -> None:
    row_id = kwargs["id"]
    if dry_run:
        exists = await session.get(model, row_id)
        if exists is None:
            setattr(counts, counter, getattr(counts, counter) + 1)
        else:
            counts.skipped += 1
        return
    if await session.get(model, row_id) is not None:
        counts.skipped += 1
        return
    try:
        async with session.begin_nested():
            result = await session.execute(
                pg_insert(model).values(**kwargs).on_conflict_do_nothing()
            )
    except IntegrityError:
        counts.skipped += 1
        return
    except DBAPIError as exc:
        counts.add_error(f"{model.__tablename__} {row_id}: {exc.__class__.__name__}")
        return
    if result.rowcount:
        setattr(counts, counter, getattr(counts, counter) + 1)
    else:
        counts.skipped += 1


async def copy_custom_category(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    doc_id: str,
    data: dict[str, Any],
    counts: MigrateCounts,
    dry_run: bool,
) -> None:
    name = (data.get("name") or "").strip()
    if not name:
        counts.skipped += 1
        return
    slug = _slugify(name)
    existing = (
        await session.execute(
            select(Category).where(Category.user_id == user_id, Category.slug == slug)
        )
    ).scalar_one_or_none()
    if existing is not None:
        counts.skipped += 1
        return
    if dry_run:
        counts.categories += 1
        return
    try:
        async with session.begin_nested():
            session.add(
                Category(
                    id=stable_uuid("cat", str(user_id), doc_id),
                    user_id=user_id,
                    slug=slug[:64],
                    name=name[:100],
                    type=_enum_or(CategoryType, data.get("type"), CategoryType.expense),
                    icon=(data.get("icon") or "label")[:64],
                    color=(data.get("color") or "#757575")[:7],
                    sort_order=int(data.get("sortOrder") or CUSTOM_SORT_ORDER),
                    is_default=False,
                )
            )
            await session.flush()
    except IntegrityError:
        counts.skipped += 1
        return
    counts.categories += 1


async def copy_override(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    data: dict[str, Any],
    counts: MigrateCounts,
    dry_run: bool,
) -> None:
    key = normalize_merchant_key(data.get("merchantKey") or data.get("merchant") or "")
    category = (data.get("category") or "").strip()
    if not key or not category:
        counts.skipped += 1
        return
    existing = (
        await session.execute(
            select(MerchantCategoryOverride).where(
                MerchantCategoryOverride.user_id == user_id,
                MerchantCategoryOverride.merchant_key == key,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        counts.skipped += 1
        return
    if dry_run:
        counts.overrides += 1
        return
    try:
        async with session.begin_nested():
            session.add(
                MerchantCategoryOverride(
                    user_id=user_id,
                    merchant_key=key[:200],
                    display_name=(data.get("displayName") or key)[:200],
                    category=category[:100],
                )
            )
            await session.flush()
    except IntegrityError:
        counts.skipped += 1
        return
    counts.overrides += 1


async def copy_summary(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    doc_id: str,
    data: dict[str, Any],
    counts: MigrateCounts,
    dry_run: bool,
) -> None:
    year_month = (data.get("yearMonth") or doc_id or "")[:7]
    if len(year_month) != 7:
        counts.skipped += 1
        return
    existing = (
        await session.execute(
            select(MonthlySummary).where(
                MonthlySummary.user_id == user_id,
                MonthlySummary.year_month == year_month,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        counts.skipped += 1
        return
    if dry_run:
        counts.summaries += 1
        return
    try:
        async with session.begin_nested():
            session.add(
                MonthlySummary(
                    user_id=user_id,
                    year_month=year_month,
                    currency=(data.get("currency") or "PKR")[:3],
                    total_debit=as_money(data.get("totalDebit") or 0),
                    total_credit=as_money(data.get("totalCredit") or 0),
                    net=as_money(data.get("net") or 0),
                    transaction_count=int(data.get("transactionCount") or 0),
                    by_category=as_num_map(data.get("byCategory")),
                    by_merchant=as_num_map(data.get("byMerchant")),
                )
            )
            await session.flush()
    except IntegrityError:
        counts.skipped += 1
        return
    counts.summaries += 1
