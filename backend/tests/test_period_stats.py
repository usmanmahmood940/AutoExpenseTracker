"""Period stats — live SQL, comparison windows matching period_stats.ts."""

from __future__ import annotations

from datetime import date

from fastapi.testclient import TestClient

from app.db.models.enums import PeriodKind
from app.services.period_stats import previous_range
from tests.test_transactions import _post_tx


def test_previous_range_matches_cloud_function() -> None:
    today = previous_range(PeriodKind.today, date(2026, 3, 15), date(2026, 3, 15))
    assert today is None

    week = previous_range(PeriodKind.week, date(2026, 3, 10), date(2026, 3, 16))
    assert week == (date(2026, 3, 3), date(2026, 3, 9))

    month = previous_range(PeriodKind.month, date(2026, 3, 1), date(2026, 3, 21))
    assert month == (date(2026, 2, 1), date(2026, 2, 21))

    clamped = previous_range(PeriodKind.month, date(2026, 3, 1), date(2026, 3, 31))
    assert clamped == (date(2026, 2, 1), date(2026, 2, 28))


def test_period_stats_totals_and_highlights(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    _post_tx(api_client, merchant="Daraz", amount=2000, tx_date="2026-03-14")
    _post_tx(
        api_client,
        merchant="Payroll",
        amount=80000,
        tx_date="2026-03-15",
        tx_type="credit",
        category="Income",
    )
    _post_tx(api_client, merchant="Old", amount=9999, tx_date="2026-02-01")

    response = api_client.get(
        "/period-stats",
        params={"period": "week", "from": "2026-03-10", "to": "2026-03-16"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["from"] == "2026-03-10"
    assert body["spent"] == 2500.0
    assert body["received"] == 80000.0
    assert body["net"] == 77500.0
    assert body["highest_spend"]["merchant"] == "Daraz"
    assert body["highest_receive"]["merchant"] == "Payroll"
    assert body["comparison"] is not None
    # Previous week has no rows → 100% increase on spent/received/net.
    assert body["comparison"]["spent_change_percent"] == 100.0


def test_today_has_no_comparison(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="Tea", amount=80, tx_date="2026-03-15")
    body = api_client.get(
        "/period-stats",
        params={"period": "today", "from": "2026-03-15", "to": "2026-03-15"},
    ).json()
    assert body["comparison"] is None
    assert body["spent"] == 80.0
