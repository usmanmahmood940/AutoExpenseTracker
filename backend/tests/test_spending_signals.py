"""SQL spending signals from seeded transactions."""

from __future__ import annotations

from uuid import UUID

from fastapi.testclient import TestClient

from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.spending_signals import detect_signals
from tests.conftest import run_isolated
from tests.test_transactions import _post_tx


def _signal_types(
    user_id: UUID, date_from: str = "2026-03-01", date_to: str = "2026-03-31"
) -> set[str]:
    async def run(session):  # type: ignore[no-untyped-def]
        user = await session.get(User, user_id)
        assert user is not None
        signals = await detect_signals(
            session, user=user, date_from=date_from, date_to=date_to
        )
        return {item.signal_type for item in signals}

    return run_isolated(run)


def test_category_spike(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="Old", amount=100, tx_date="2025-12-01")
    _post_tx(api_client, merchant="Old", amount=100, tx_date="2026-01-15")
    _post_tx(api_client, merchant="Old", amount=100, tx_date="2026-02-15")
    _post_tx(api_client, merchant="KFC", amount=5000, tx_date="2026-03-10")
    user_id = UUID(api_client.get("/me").json()["id"])
    assert "category_spike" in _signal_types(user_id)


def test_merchant_concentration(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=8000, tx_date="2026-03-10")
    _post_tx(api_client, merchant="Daraz", amount=200, tx_date="2026-03-20")
    user_id = UUID(api_client.get("/me").json()["id"])
    assert "merchant_concentration" in _signal_types(user_id)


def test_weekend_skew(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="Club", amount=9000, tx_date="2026-03-07")
    _post_tx(api_client, merchant="Cafe", amount=100, tx_date="2026-03-02")
    user_id = UUID(api_client.get("/me").json()["id"])
    assert "weekend_skew" in _signal_types(user_id)


def test_large_one_off(api_client: TestClient) -> None:
    for day in range(1, 6):
        _post_tx(
            api_client,
            merchant="Snack",
            amount=100,
            tx_date=f"2026-03-0{day}",
        )
    _post_tx(api_client, merchant="Laptop", amount=10000, tx_date="2026-03-20")
    user_id = UUID(api_client.get("/me").json()["id"])
    assert "large_one_off" in _signal_types(user_id)


def test_net_negative_swing(api_client: TestClient) -> None:
    _post_tx(
        api_client,
        merchant="Payroll",
        amount=20000,
        tx_date="2026-02-15",
        tx_type="credit",
        category="Income",
    )
    _post_tx(api_client, merchant="KFC", amount=5000, tx_date="2026-03-10")
    user_id = UUID(api_client.get("/me").json()["id"])
    assert "net_negative_swing" in _signal_types(user_id)


def test_new_recurring(api_client: TestClient) -> None:
    first = _post_tx(api_client, merchant="Netflix", amount=1500, tx_date="2026-03-01")
    second = _post_tx(api_client, merchant="Netflix", amount=1500, tx_date="2026-03-28")
    user_id = UUID(api_client.get("/me").json()["id"])

    async def flag(session):  # type: ignore[no-untyped-def]
        for tx_id in (first["id"], second["id"]):
            tx = await session.get(Transaction, UUID(tx_id))
            assert tx is not None
            tx.is_recurring = True
        await session.commit()

    run_isolated(flag)
    assert "new_recurring" in _signal_types(user_id)
