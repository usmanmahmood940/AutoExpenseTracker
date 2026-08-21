"""Live monthly summaries."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.test_transactions import _post_tx


def test_monthly_summary_debits_only_in_breakdowns(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    _post_tx(
        api_client,
        merchant="KFC",
        amount=200,
        tx_date="2026-03-20",
        category="Food & Dining",
    )
    _post_tx(
        api_client,
        merchant="Payroll",
        amount=10000,
        tx_date="2026-03-15",
        tx_type="credit",
        category="Income",
    )
    _post_tx(api_client, merchant="April", amount=50, tx_date="2026-04-01")

    response = api_client.get("/analytics/summary", params={"year_month": "2026-03"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["total_debit"] == 700.0
    assert body["total_credit"] == 10000.0
    assert body["net"] == 9300.0
    assert body["transaction_count"] == 3
    assert body["by_category"]["Food & Dining"] == 700.0
    assert "Income" not in body["by_category"]
    assert body["by_merchant"]["KFC"] == 700.0
    assert "Payroll" not in body["by_merchant"]

    empty = api_client.get(
        "/analytics/summary", params={"year_month": "2026-01"}
    ).json()
    assert empty["transaction_count"] == 0
    assert empty["total_debit"] == 0.0

    recent = api_client.get("/analytics/summaries", params={"limit": 6}).json()
    assert [item["year_month"] for item in recent["items"]] == ["2026-04", "2026-03"]
