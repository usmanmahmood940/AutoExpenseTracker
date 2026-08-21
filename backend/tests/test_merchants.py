"""Merchant summary + list."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.test_transactions import _post_tx


def test_merchant_summary_and_transactions(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-01")
    _post_tx(api_client, merchant="KFC", amount=700, tx_date="2026-03-10")
    _post_tx(
        api_client, merchant="KFC", amount=1000, tx_date="2026-03-15", tx_type="credit"
    )
    _post_tx(api_client, merchant="Daraz", amount=200, tx_date="2026-03-02")

    summary = api_client.get("/merchants/kfc").json()
    assert summary["merchant_normalized"] == "kfc"
    assert summary["display_name"] == "KFC"
    assert summary["visit_count"] == 2
    assert summary["total_spent"] == 1200.0
    assert summary["average_spent"] == 600.0

    page = api_client.get("/merchants/kfc/transactions").json()
    assert len(page["items"]) == 3  # credits included in the merchant list
    assert all(item["merchant_normalized"] == "kfc" for item in page["items"])
