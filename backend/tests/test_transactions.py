"""Phase C transaction list / search / CRUD."""

from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from app.api import deps
from app.core.firebase import FirebaseIdentity
from app.main import create_app


def _post_tx(
    client: TestClient,
    *,
    merchant: str,
    amount: float,
    tx_date: str,
    tx_type: str = "debit",
    category: str = "Food & Dining",
    bank: str = "HBL",
) -> dict:
    response = client.post(
        "/transactions",
        json={
            "merchant": merchant,
            "amount": amount,
            "transaction_date": tx_date,
            "type": tx_type,
            "category": category,
            "bank": bank,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_list_requires_auth(client: TestClient) -> None:
    with client:
        response = client.get("/transactions")
    assert response.status_code == 401


def test_create_list_and_date_filter(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-01")
    _post_tx(api_client, merchant="Daraz", amount=2000, tx_date="2026-03-15")
    _post_tx(
        api_client,
        merchant="Salary",
        amount=80000,
        tx_date="2026-04-01",
        tx_type="credit",
    )

    page = api_client.get("/transactions").json()
    assert page["has_more"] is False
    assert len(page["items"]) == 3
    assert page["items"][0]["merchant"] == "Salary"  # newest date first

    march = api_client.get(
        "/transactions", params={"date_from": "2026-03-01", "date_to": "2026-03-31"}
    ).json()
    assert {item["merchant"] for item in march["items"]} == {"KFC", "Daraz"}


def test_amount_sort_with_date_range(api_client: TestClient) -> None:
    """The SQL advantage: Firestore forbade amount sort + date range together."""
    _post_tx(api_client, merchant="Cheap", amount=100, tx_date="2026-03-02")
    _post_tx(api_client, merchant="Pricey", amount=900, tx_date="2026-03-10")
    _post_tx(api_client, merchant="Outside", amount=5000, tx_date="2026-04-01")

    page = api_client.get(
        "/transactions",
        params={
            "date_from": "2026-03-01",
            "date_to": "2026-03-31",
            "sort_by": "amount",
            "order_by": "desc",
        },
    ).json()
    assert [item["merchant"] for item in page["items"]] == ["Pricey", "Cheap"]


def test_aggregates_and_cursor(api_client: TestClient) -> None:
    for i in range(3):
        _post_tx(
            api_client,
            merchant=f"Shop {i}",
            amount=10 + i,
            tx_date=f"2026-03-0{i + 1}",
        )

    first = api_client.get(
        "/transactions", params={"limit": 2, "include_aggregates": True}
    ).json()
    assert first["has_more"] is True
    assert first["total_count"] == 3
    assert first["total_amount"] == 33.0
    assert first["next_cursor"]

    second = api_client.get(
        "/transactions", params={"limit": 2, "cursor": first["next_cursor"]}
    ).json()
    assert second["has_more"] is False
    assert len(second["items"]) == 1
    ids = {item["id"] for item in first["items"]} | {second["items"][0]["id"]}
    assert len(ids) == 3


def test_patch_detail_soft_delete(api_client: TestClient) -> None:
    created = _post_tx(api_client, merchant="KFC", amount=250, tx_date="2026-03-08")
    tx_id = created["id"]
    assert created["merchant_normalized"] == "kfc"
    assert created["day"] == "Sunday"

    patched = api_client.patch(
        f"/transactions/{tx_id}",
        json={"merchant": "KFC DHA", "category": "Fast Food", "amount": 300},
    )
    assert patched.status_code == 200
    body = patched.json()
    assert body["merchant_normalized"] == "kfc dha"
    assert body["category"] == "Fast Food"
    assert body["amount"] == 300.0
    assert body["is_edited"] is True
    assert body["category_source"] == "user"

    detail = api_client.get(f"/transactions/{tx_id}")
    assert detail.status_code == 200

    deleted = api_client.delete(f"/transactions/{tx_id}")
    assert deleted.status_code == 204
    listed = api_client.get("/transactions").json()
    assert listed["items"] == []


def test_search_prefix_and_scan(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=100, tx_date="2026-03-01")
    _post_tx(api_client, merchant="Khaadi", amount=200, tx_date="2026-03-02")
    _post_tx(api_client, merchant="Daraz", amount=300, tx_date="2026-03-03")

    prefix = api_client.get("/transactions/search", params={"q": "kf"}).json()
    assert [item["merchant"] for item in prefix["items"]] == ["KFC"]

    scan = api_client.get(
        "/transactions/search",
        params={"q": "shopping", "date_from": "2026-03-01", "date_to": "2026-03-31"},
    )
    # "shopping" matches nothing in merchant/category/bank here
    assert scan.status_code == 200
    assert scan.json()["items"] == []

    by_bank = api_client.get(
        "/transactions/search",
        params={"q": "HBL", "date_from": "2026-03-01", "date_to": "2026-03-31"},
    ).json()
    assert len(by_bank["items"]) == 3


def test_search_by_categories(api_client: TestClient) -> None:
    _post_tx(
        api_client,
        merchant="KFC",
        amount=100,
        tx_date="2026-03-01",
        category="Food & Dining",
    )
    _post_tx(
        api_client,
        merchant="PSO",
        amount=200,
        tx_date="2026-03-02",
        category="Fuel",
    )
    _post_tx(
        api_client,
        merchant="Daraz",
        amount=300,
        tx_date="2026-03-03",
        category="Shopping",
    )

    food = api_client.get(
        "/transactions/search",
        params={"categories": "Food & Dining"},
    ).json()
    assert [item["merchant"] for item in food["items"]] == ["KFC"]

    multi = api_client.get(
        "/transactions/search",
        params={"categories": "Food & Dining,Fuel"},
    ).json()
    assert {item["merchant"] for item in multi["items"]} == {"KFC", "PSO"}


def test_user_isolation() -> None:
    created = None
    uid_a = f"uid-{uuid.uuid4().hex[:12]}"
    app_a = create_app()
    app_a.dependency_overrides[deps.get_current_identity] = lambda: FirebaseIdentity(
        uid=uid_a, email=f"{uid_a}@example.com", email_verified=True, claims={}
    )
    with TestClient(app_a) as client_a:
        client_a.get("/me")
        created = _post_tx(client_a, merchant="Secret", amount=1, tx_date="2026-03-01")

    uid_b = f"uid-{uuid.uuid4().hex[:12]}"
    app_b = create_app()
    app_b.dependency_overrides[deps.get_current_identity] = lambda: FirebaseIdentity(
        uid=uid_b, email=f"{uid_b}@example.com", email_verified=True, claims={}
    )
    with TestClient(app_b) as client_b:
        client_b.get("/me")
        listed = client_b.get("/transactions").json()
        assert listed["items"] == []
        missing = client_b.get(f"/transactions/{created['id']}")
        assert missing.status_code == 404
