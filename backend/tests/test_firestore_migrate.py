"""Firestore → Postgres id mapping and document transforms."""

from __future__ import annotations

from datetime import UTC, date, datetime
from decimal import Decimal
from uuid import UUID

from app.db.models.enums import TransactionStatus, TransactionType
from app.services.firestore_migrate import (
    as_date,
    as_datetime,
    ingestion_kwargs,
    stable_uuid,
    transaction_kwargs,
    user_fields_from_doc,
)


def test_stable_uuid_keeps_real_uuids() -> None:
    doc_id = "11111111-1111-1111-1111-111111111111"
    assert stable_uuid("tx", "uid", doc_id) == UUID(doc_id)


def test_stable_uuid_is_deterministic_for_auto_ids() -> None:
    auto_id = "AbCdEfGhIjKlMnOpQrSt"
    first = stable_uuid("tx", "uid-1", auto_id)
    second = stable_uuid("tx", "uid-1", auto_id)
    other = stable_uuid("tx", "uid-2", auto_id)
    assert first == second
    assert first != other
    assert first != UUID(int=0)


def test_user_fields_flatten_settings() -> None:
    fields = user_fields_from_doc(
        {
            "displayName": "Usman",
            "defaultCurrency": "pkr",
            "timezone": "Asia/Karachi",
            "bankSenders": ["HBL"],
            "emailFilters": [],
            "settings": {"autoCategorize": False},
        },
        email="Usman@Example.com",
        email_verified=True,
    )
    assert fields["email"] == "usman@example.com"
    assert fields["display_name"] == "Usman"
    assert fields["default_currency"] == "PKR"
    assert fields["auto_categorize"] is False
    assert fields["bank_senders"] == ["HBL"]


def test_transaction_kwargs_maps_camel_case() -> None:
    created = datetime(2026, 8, 1, 10, 0, tzinfo=UTC)
    kwargs = transaction_kwargs(
        uid="uid",
        doc_id="22222222-2222-2222-2222-222222222222",
        user_id=UUID("33333333-3333-3333-3333-333333333333"),
        data={
            "amount": 99.5,
            "currency": "PKR",
            "type": "debit",
            "merchant": "PSO Rangers",
            "merchantNormalized": "pso rangers",
            "category": "Fuel",
            "transactionDate": "2026-08-01",
            "transactionTime": "10:00",
            "dedupKey": "abc",
            "status": "active",
            "smsSource": {
                "raw": "PKR 99",
                "source": "ios_shortcut",
                "receivedAt": created,
            },
            "createdAt": created,
            "updatedAt": created,
        },
    )
    assert kwargs is not None
    assert kwargs["id"] == UUID("22222222-2222-2222-2222-222222222222")
    assert kwargs["amount"] == Decimal("99.50")
    assert kwargs["type"] is TransactionType.debit
    assert kwargs["status"] is TransactionStatus.active
    assert kwargs["transaction_date"] == date(2026, 8, 1)
    from app.services.sms_source import decrypt_sms_source_raw

    assert decrypt_sms_source_raw(kwargs["sms_source"], user_id=kwargs["user_id"]) == (
        "PKR 99"
    )
    assert "raw_encrypted" in kwargs["sms_source"]


def test_transaction_kwargs_skips_missing_date() -> None:
    assert (
        transaction_kwargs(
            uid="uid",
            doc_id="x",
            user_id=UUID("33333333-3333-3333-3333-333333333333"),
            data={"amount": 1, "merchant": "X"},
        )
        is None
    )


def test_ingestion_points_at_mapped_transaction() -> None:
    auto_tx = "AbCdEfGhIjKlMnOpQrSt"
    kwargs = ingestion_kwargs(
        uid="uid",
        doc_id="ing1",
        user_id=UUID("33333333-3333-3333-3333-333333333333"),
        data={
            "raw": "hello",
            "source": "ios_shortcut",
            "status": "parsed",
            "transactionId": auto_tx,
            "receivedAt": "2026-08-01T10:00:00+05:00",
        },
    )
    assert kwargs is not None
    assert kwargs["transaction_id"] == stable_uuid("tx", "uid", auto_tx)
    from app.services.field_crypto import is_encrypted
    from app.services.sms_source import decrypt_ingestion_raw

    assert is_encrypted(kwargs["raw"])
    assert decrypt_ingestion_raw(kwargs["raw"], user_id=kwargs["user_id"]) == "hello"


def test_as_date_and_datetime_from_iso() -> None:
    assert as_date("2026-08-21") == date(2026, 8, 21)
    parsed = as_datetime("2026-08-21T12:00:00Z")
    assert parsed is not None
    assert parsed.tzinfo is not None
