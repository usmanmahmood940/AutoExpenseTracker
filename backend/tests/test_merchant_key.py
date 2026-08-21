"""Cross-language merchant key — must match shared/test-fixtures."""

from __future__ import annotations

import json
from pathlib import Path

from app.services.merchant_key import normalize_merchant_key

_CASES = json.loads(
    (
        Path(__file__).resolve().parents[2]
        / "shared/test-fixtures/normalize-merchant-key-cases.json"
    ).read_text()
)["cases"]


def test_normalize_merchant_key_matches_shared_vectors() -> None:
    for case in _CASES:
        assert normalize_merchant_key(case["input"]) == case["expected"], case
