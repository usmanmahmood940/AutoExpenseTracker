"""Chat guardrails, suggestions, and cited answers."""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.core.config import get_settings
from tests.test_transactions import _post_tx


def _seed_ten(api_client: TestClient) -> None:
    for i in range(10):
        day = f"{i + 1:02d}"
        merchant = "KFC" if i < 7 else "Daraz"
        _post_tx(
            api_client,
            merchant=merchant,
            amount=100 + i,
            tx_date=f"2026-03-{day}",
        )


def test_suggestions_empty_for_sparse_user(api_client: TestClient) -> None:
    response = api_client.get(
        "/chat/suggestions", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert response.status_code == 200, response.text
    assert response.json()["suggestions"] == []


def test_suggestions_capped_at_five(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=8000, tx_date="2026-03-10")
    _post_tx(api_client, merchant="Daraz", amount=200, tx_date="2026-03-20")
    _post_tx(
        api_client,
        merchant="Payroll",
        amount=20000,
        tx_date="2026-02-15",
        tx_type="credit",
        category="Income",
    )
    response = api_client.get(
        "/chat/suggestions", params={"from": "2026-03-01", "to": "2026-03-31"}
    )
    assert response.status_code == 200, response.text
    suggestions = response.json()["suggestions"]
    assert len(suggestions) <= 5
    assert suggestions
    assert all("question" in item and "signal_type" in item for item in suggestions)


def test_ask_rejects_off_topic(api_client: TestClient) -> None:
    response = api_client.post(
        "/chat/ask", json={"question": "What's the weather today?"}
    )
    assert response.status_code == 400, response.text
    assert response.json()["code"] == "chat_off_topic"


def test_ask_insufficient_data(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    response = api_client.post(
        "/chat/ask", json={"question": "Why did food spending jump?"}
    )
    assert response.status_code == 400, response.text
    assert response.json()["code"] == "insufficient_data"


def test_ask_navigation_skips_rag(api_client: TestClient) -> None:
    _seed_ten(api_client)
    response = api_client.post("/chat/ask", json={"question": "show KFC"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["source"] == "navigation"
    assert body["citations"] == []
    assert "Activity" in body["answer"]


def test_ask_returns_citations(api_client: TestClient, monkeypatch) -> None:
    from app.services import chat_rag

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        assert "SECRET_SMS" not in prompt
        assert "raw_encrypted" not in prompt
        return "You spent most of this period at KFC.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)

    _seed_ten(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "Why is KFC so much of my spending?",
            "from": "2026-03-01",
            "to": "2026-03-31",
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["source"] == "gemini"
    assert "KFC" in body["answer"]
    assert body["citations"]
    merchants = {item["merchant"] for item in body["citations"]}
    assert "KFC" in merchants
    for item in body["citations"]:
        assert "raw" not in item
        assert item["transaction_id"]
        assert item["date"]
        assert item["amount"] is not None
