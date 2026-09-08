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
    assert summary["visit_count"] == 3
    assert summary["total_spent"] == 1200.0
    assert summary["average_spent"] == 400.0

    page = api_client.get("/merchants/kfc/transactions").json()
    assert len(page["items"]) == 3  # credits included in the merchant list
    assert all(item["merchant_normalized"] == "kfc" for item in page["items"])


def test_merchant_key_with_spaces_and_encodings(api_client: TestClient) -> None:
    _post_tx(
        api_client,
        merchant="Cursor AI Power",
        amount=2200,
        tx_date="2026-03-08",
        category="Subscriptions",
    )
    _post_tx(api_client, merchant="Daraz", amount=200, tx_date="2026-03-02")

    for path in (
        "/merchants/cursor%20ai%20power",
        "/merchants/cursor%2520ai%2520power",
        "/merchants/cursor+ai+power",
        "/merchants/Cursor%20AI%20Power",
    ):
        summary = api_client.get(path).json()
        assert summary["merchant_normalized"] == "cursor ai power"
        assert summary["visit_count"] == 1
        assert summary["total_spent"] == 2200.0

        page = api_client.get(f"{path}/transactions").json()
        assert [item["merchant"] for item in page["items"]] == ["Cursor AI Power"]


def test_category_override_is_explicit_not_tied_to_patch(
    api_client: TestClient,
) -> None:
    created = _post_tx(
        api_client, merchant="PSO RANGERS", amount=100, tx_date="2026-03-01"
    )
    missing = api_client.get("/merchants/pso%20rangers/category-override")
    assert missing.status_code == 404

    patched = api_client.patch(
        f"/transactions/{created['id']}",
        json={"category": "Fuel", "amount": 110},
    )
    assert patched.status_code == 200
    still_missing = api_client.get("/merchants/pso%20rangers/category-override")
    assert still_missing.status_code == 404

    saved = api_client.put(
        "/merchants/pso%20rangers/category-override",
        json={"category": "Fuel", "display_name": "PSO RANGERS"},
    )
    assert saved.status_code == 200
    assert saved.json()["merchant_key"] == "pso rangers"
    assert saved.json()["category"] == "Fuel"

    fetched = api_client.get("/merchants/PSO%20RANGERS/category-override")
    assert fetched.status_code == 200
    assert fetched.json()["category"] == "Fuel"

    deleted = api_client.delete("/merchants/pso%20rangers/category-override")
    assert deleted.status_code == 204
    gone = api_client.get("/merchants/pso%20rangers/category-override")
    assert gone.status_code == 404
    again = api_client.delete("/merchants/pso%20rangers/category-override")
    assert again.status_code == 204
