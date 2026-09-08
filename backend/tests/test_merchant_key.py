"""Cross-language merchant key — must match shared/test-fixtures."""

from __future__ import annotations

import json
from pathlib import Path

from app.services.merchant_key import (
    decode_merchant_path_key,
    normalize_merchant_key,
    resolve_merchant,
)

_CASES = json.loads(
    (
        Path(__file__).resolve().parents[2]
        / "shared/test-fixtures/normalize-merchant-key-cases.json"
    ).read_text()
)["cases"]

_RESOLVE_CASES = json.loads(
    (
        Path(__file__).resolve().parents[2]
        / "shared/test-fixtures/resolve-merchant-cases.json"
    ).read_text()
)["cases"]


def test_normalize_merchant_key_matches_shared_vectors() -> None:
    for case in _CASES:
        assert normalize_merchant_key(case["input"]) == case["expected"], case


def test_decode_merchant_path_key_handles_space_encodings() -> None:
    assert decode_merchant_path_key("cursor ai power") == "cursor ai power"
    assert decode_merchant_path_key("cursor%20ai%20power") == "cursor ai power"
    assert decode_merchant_path_key("cursor%2520ai%2520power") == "cursor ai power"
    assert decode_merchant_path_key("cursor+ai+power") == "cursor ai power"
    assert decode_merchant_path_key("Cursor AI Power") == "cursor ai power"


def test_resolve_merchant_matches_shared_vectors() -> None:
    for case in _RESOLVE_CASES:
        assert (
            resolve_merchant(
                case["merchant"],
                category=case["category"],
                payment_method=case["paymentMethod"],
            )
            == case["expected"]
        ), case
