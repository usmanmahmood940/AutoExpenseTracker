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
    assert body["by_merchant_stats"]["KFC"]["visit_count"] == 2
    assert body["by_merchant_stats"]["KFC"]["amount"] == 700.0
    assert body["date_from"] == "2026-03-01"
    assert body["date_to"] == "2026-03-31"

    empty = api_client.get(
        "/analytics/summary", params={"year_month": "2026-01"}
    ).json()
    assert empty["transaction_count"] == 0
    assert empty["total_debit"] == 0.0

    recent = api_client.get("/analytics/summaries", params={"limit": 6}).json()
    assert [item["year_month"] for item in recent["items"]] == ["2026-04", "2026-03"]


def test_range_summary_and_daily_trend(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    _post_tx(api_client, merchant="Daraz", amount=200, tx_date="2026-03-20")
    _post_tx(api_client, merchant="April", amount=50, tx_date="2026-04-01")

    ranged = api_client.get(
        "/analytics/range", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert ranged.status_code == 200, ranged.text
    body = ranged.json()
    assert body["total_debit"] == 700.0
    assert body["transaction_count"] == 2
    assert "April" not in body["by_merchant"]

    trend = api_client.get(
        "/analytics/trend",
        params={"from": "2026-03-10", "to": "2026-03-12", "bucket": "day"},
    )
    assert trend.status_code == 200, trend.text
    points = trend.json()["points"]
    assert [item["date"] for item in points] == [
        "2026-03-10",
        "2026-03-11",
        "2026-03-12",
    ]
    assert points[0]["debit"] == 500.0
    assert points[1]["debit"] == 0.0


def test_recurring_groups_similar_amounts(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="Netflix", amount=1500, tx_date="2026-03-01")
    _post_tx(api_client, merchant="Netflix", amount=1500, tx_date="2026-03-28")
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")

    response = api_client.get(
        "/analytics/recurring", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert response.status_code == 200, response.text
    names = {item["display_name"] for item in response.json()["items"]}
    assert "Netflix" in names
    assert "KFC" not in names


def test_narrative_cache_hit(api_client: TestClient, monkeypatch) -> None:
    from types import SimpleNamespace

    from app.services import insights_narrative

    calls = {"n": 0}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        calls["n"] += 1
        return "You spent PKR 500 at KFC.", "fake-model"

    monkeypatch.setattr(
        insights_narrative,
        "get_settings",
        lambda: SimpleNamespace(gemini_api_key="test-key"),
    )
    monkeypatch.setattr(
        insights_narrative,
        "generate_spend_narrative_text",
        fake_generate,
    )

    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    first = api_client.get(
        "/analytics/narrative", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert first.status_code == 200, first.text
    assert first.json()["narrative"] == "You spent PKR 500 at KFC."
    assert first.json()["source"] == "gemini"
    assert calls["n"] == 1

    second = api_client.get(
        "/analytics/narrative", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert second.json()["source"] == "cache"
    assert second.json()["narrative"] == "You spent PKR 500 at KFC."
    assert calls["n"] == 1


def test_narrative_regenerates_when_data_changes(
    api_client: TestClient, monkeypatch
) -> None:
    from types import SimpleNamespace

    from app.services import insights_narrative

    calls = {"n": 0}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        calls["n"] += 1
        if calls["n"] == 1:
            return "You spent PKR 500 at KFC.", "fake-model"
        return "You spent PKR 700 at KFC and Daraz.", "fake-model"

    monkeypatch.setattr(
        insights_narrative,
        "get_settings",
        lambda: SimpleNamespace(gemini_api_key="test-key"),
    )
    monkeypatch.setattr(
        insights_narrative,
        "generate_spend_narrative_text",
        fake_generate,
    )

    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    first = api_client.get(
        "/analytics/narrative", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert first.status_code == 200, first.text
    assert first.json()["source"] == "gemini"
    assert calls["n"] == 1

    _post_tx(api_client, merchant="Daraz", amount=200, tx_date="2026-03-20")
    second = api_client.get(
        "/analytics/narrative", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert second.status_code == 200, second.text
    assert second.json()["source"] == "gemini"
    assert second.json()["narrative"] == "You spent PKR 700 at KFC and Daraz."
    assert calls["n"] == 2


def test_narrative_empty_without_gemini(api_client: TestClient, monkeypatch) -> None:
    from types import SimpleNamespace

    from app.services import insights_narrative

    monkeypatch.setattr(
        insights_narrative,
        "get_settings",
        lambda: SimpleNamespace(gemini_api_key=None),
    )
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    response = api_client.get(
        "/analytics/narrative", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert response.status_code == 200, response.text
    assert response.json()["narrative"] is None
    assert response.json()["source"] == "none"
