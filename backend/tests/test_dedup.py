"""Port of `functions/src/dedup.test.ts`."""

from __future__ import annotations

from app.services.dedup import DedupFields, compute_dedup_key, mask_account_id


def _parsed(**overrides: object) -> DedupFields:
    base: dict[str, object] = {
        "amount": 710.0,
        "currency": "PKR",
        "account_id": "xxx1215",
        "external_id": None,
        "transaction_date": "2026-08-13",
        "merchant": "TELHA WASIM",
        "merchant_details": "SCB-xxx2501",
        "transaction_time": "2026-08-13T19:44:00+05:00",
    }
    base.update(overrides)
    return DedupFields(**base)  # type: ignore[arg-type]


def test_different_merchants_without_external_id() -> None:
    telha = compute_dedup_key(_parsed())
    waleed = compute_dedup_key(
        _parsed(
            merchant="WALEED ANJUM",
            merchant_details="SCB-xxx7301",
            transaction_time="2026-08-13T19:46:00+05:00",
        )
    )
    assert telha != waleed


def test_same_transfer_stable_across_casing() -> None:
    a = compute_dedup_key(_parsed())
    b = compute_dedup_key(
        _parsed(merchant="  telha   wasim ", merchant_details="scb-xxx2501")
    )
    assert a == b


def test_external_id_ignores_merchant() -> None:
    a = compute_dedup_key(_parsed(external_id="387522", merchant="PSO RANGERS"))
    b = compute_dedup_key(
        _parsed(
            external_id="387522",
            merchant="PSO Rangers LAH",
            merchant_details="LAH",
            transaction_time="2026-08-13T11:27:00+05:00",
        )
    )
    assert a == b


def test_same_merchant_different_minutes() -> None:
    first = compute_dedup_key(_parsed())
    second = compute_dedup_key(_parsed(transaction_time="2026-08-13T19:46:00+05:00"))
    assert first != second


def test_mask_account_id() -> None:
    assert mask_account_id("xxx1215") == "xxx1215"
    assert mask_account_id("1234567890") == "xxxxxx7890"
    assert mask_account_id("Unknown") == "Unknown"
