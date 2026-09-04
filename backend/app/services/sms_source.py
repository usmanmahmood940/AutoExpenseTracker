"""Read/write helpers for encrypted SMS payloads (Option A).

Storage:
- ``raw_ingestions.raw`` holds a ``v1:`` blob (or legacy plaintext during dual-read).
- ``transactions.sms_source`` JSONB keeps metadata in snake_case and the body
  under ``raw_encrypted``. Legacy rows may still have plaintext ``raw``.
  Older ingest rows used camelCase metadata keys; readers accept both.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from app.services.field_crypto import (
    encrypt_plaintext,
    is_encrypted,
    maybe_decrypt,
)


def aad_for_user(user_id: uuid.UUID) -> str:
    return str(user_id)


def _pick(source: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in source and source[key] is not None:
            return source[key]
    return None


def _received_at_iso(value: datetime | str | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    text = str(value).strip()
    return text or None


def encrypt_ingestion_raw(plaintext: str, *, user_id: uuid.UUID) -> str:
    return encrypt_plaintext(plaintext, aad=aad_for_user(user_id))


def decrypt_ingestion_raw(stored: str, *, user_id: uuid.UUID) -> str:
    return maybe_decrypt(stored, aad=aad_for_user(user_id))


def build_sms_source(
    *,
    raw_plaintext: str,
    source: str,
    user_id: uuid.UUID,
    received_at: datetime | str | None = None,
    message_id: str | None = None,
    idempotency_key: str | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "source": source,
        "received_at": _received_at_iso(received_at),
        "message_id": message_id,
        "idempotency_key": idempotency_key,
    }
    text = raw_plaintext or ""
    if text:
        payload["raw_encrypted"] = encrypt_plaintext(text, aad=aad_for_user(user_id))
    else:
        payload["raw"] = ""
    return payload


def decrypt_sms_source_raw(source: dict[str, Any] | None, *, user_id: uuid.UUID) -> str:
    if not source:
        return ""
    aad = aad_for_user(user_id)
    blob = _pick(source, "raw_encrypted")
    if isinstance(blob, str) and blob:
        return maybe_decrypt(blob, aad=aad)
    raw = _pick(source, "raw")
    if isinstance(raw, str) and raw:
        if is_encrypted(raw):
            return maybe_decrypt(raw, aad=aad)
        return raw
    return ""


def sms_source_for_api(
    source: dict[str, Any] | None,
    *,
    user_id: uuid.UUID,
    include_raw: bool,
) -> dict[str, Any]:
    source = source or {}
    raw = decrypt_sms_source_raw(source, user_id=user_id) if include_raw else ""
    return {
        "raw": raw,
        "source": _pick(source, "source") or "manual",
        "received_at": _pick(source, "received_at", "receivedAt"),
        "message_id": _pick(source, "message_id", "messageId"),
        "idempotency_key": _pick(source, "idempotency_key", "idempotencyKey"),
    }


def encrypt_legacy_sms_source(
    source: dict[str, Any], *, user_id: uuid.UUID
) -> dict[str, Any] | None:
    """Return an encrypted copy if ``raw`` is still plaintext; else None."""
    raw = _pick(source, "raw")
    encrypted = isinstance(raw, str) and is_encrypted(raw)
    if not isinstance(raw, str) or not raw or encrypted:
        if encrypted and not _pick(source, "raw_encrypted"):
            updated = dict(source)
            updated["raw_encrypted"] = raw
            updated.pop("raw", None)
            return updated
        return None
    if _pick(source, "raw_encrypted"):
        return None
    return build_sms_source(
        raw_plaintext=raw,
        source=_pick(source, "source") or "manual",
        user_id=user_id,
        received_at=_pick(source, "received_at", "receivedAt"),
        message_id=_pick(source, "message_id", "messageId"),
        idempotency_key=_pick(source, "idempotency_key", "idempotencyKey"),
    )
