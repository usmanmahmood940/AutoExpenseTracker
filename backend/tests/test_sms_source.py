"""sms_source JSON helpers: snake_case metadata, dual-read, encrypt."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from app.services.field_crypto import is_encrypted
from app.services.sms_source import (
    build_sms_source,
    decrypt_sms_source_raw,
    encrypt_legacy_sms_source,
    sms_source_for_api,
)

USER = UUID("33333333-3333-3333-3333-333333333333")


def test_build_encrypts_and_api_decrypts() -> None:
    received = datetime(2026, 7, 6, 11, 27, tzinfo=UTC)
    stored = build_sms_source(
        raw_plaintext="PKR 5,990 charged at PSO",
        source="ios_shortcut",
        user_id=USER,
        received_at=received,
        message_id="mid-1",
        idempotency_key="once",
    )
    assert "raw" not in stored
    assert is_encrypted(stored["raw_encrypted"])
    assert stored["source"] == "ios_shortcut"
    assert stored["message_id"] == "mid-1"

    assert decrypt_sms_source_raw(stored, user_id=USER) == "PKR 5,990 charged at PSO"
    listed = sms_source_for_api(stored, user_id=USER, include_raw=False)
    assert listed["raw"] == ""
    assert listed["source"] == "ios_shortcut"
    detail = sms_source_for_api(stored, user_id=USER, include_raw=True)
    assert detail["raw"] == "PKR 5,990 charged at PSO"


def test_decrypt_legacy_plaintext_and_camel_case() -> None:
    legacy = {
        "raw": "hello from gmail",
        "source": "gmail",
        "receivedAt": "2026-07-06T11:27:00+05:00",
        "messageId": "m",
        "idempotencyKey": "k",
    }
    assert decrypt_sms_source_raw(legacy, user_id=USER) == "hello from gmail"
    api = sms_source_for_api(legacy, user_id=USER, include_raw=True)
    assert api["received_at"] == "2026-07-06T11:27:00+05:00"
    assert api["message_id"] == "m"
    assert api["idempotency_key"] == "k"


def test_encrypt_legacy_sms_source_is_idempotent() -> None:
    legacy = {"raw": "PKR 99", "source": "manual", "received_at": None}
    once = encrypt_legacy_sms_source(legacy, user_id=USER)
    assert once is not None
    assert decrypt_sms_source_raw(once, user_id=USER) == "PKR 99"
    assert encrypt_legacy_sms_source(once, user_id=USER) is None
