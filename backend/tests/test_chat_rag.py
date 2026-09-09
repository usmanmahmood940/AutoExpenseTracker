"""Chat guardrails, suggestions, and cited answers."""

from __future__ import annotations

import json
from datetime import date

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
    assert body["filter_term"] == "KFC"
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
    assert body["window_from"] == "2026-03-01"
    assert body["window_to"] == "2026-03-31"


def test_ask_without_from_to_uses_default_window(
    api_client: TestClient, monkeypatch
) -> None:
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "KFC was the largest merchant in range.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)

    _seed_ten(api_client)
    response = api_client.post(
        "/chat/ask",
        json={"question": "Why is KFC so much of my spending?"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["window_from"]
    assert body["window_to"]
    assert "Selected period:" in captured["prompt"]


def test_ask_today_uses_largest_debit(api_client: TestClient, monkeypatch) -> None:
    from app.services import chat_rag

    today = date.today()
    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "Your largest debit today was at PSO.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)

    day = today.isoformat()
    for i in range(9):
        _post_tx(
            api_client,
            merchant="KFC",
            amount=100 + i,
            tx_date=day,
        )
    _post_tx(api_client, merchant="PSO", amount=9000, tx_date=day)

    response = api_client.post(
        "/chat/ask",
        json={
            "question": "tell me my biggest transaction of today",
            "from": f"{today.year}-01-01",
            "to": day,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["window_from"] == day
    assert body["window_to"] == day
    assert body["citations"]
    merchants = {item["merchant"] for item in body["citations"]}
    assert "PSO" in merchants
    prompt = captured["prompt"]
    assert "largest_debits" in prompt
    assert "PSO" in prompt
    assert f"Today is {day}" in prompt
    assert "day_totals" in prompt


def test_ask_year_range_keeps_transaction_docs(
    api_client: TestClient, monkeypatch
) -> None:
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "KFC was the largest merchant this year.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)

    _seed_ten(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "Why is KFC so much of my spending?",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    assert response.status_code == 200, response.text
    prompt = captured["prompt"]
    assert "KFC" in prompt
    assert "largest_debits" in prompt
    assert "Retrieved documents (examples only" in prompt
    docs = prompt.split("Retrieved documents (examples only", 1)[1]
    assert "merchant |" not in docs


def test_ask_history_is_in_prompt(api_client: TestClient, monkeypatch) -> None:
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "Food is mostly KFC as well.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)

    _seed_ten(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "What about food?",
            "from": "2026-03-01",
            "to": "2026-03-31",
            "history": [
                {
                    "question": "Why is KFC so much of my spending?",
                    "answer": "Most visits were at KFC.",
                }
            ],
        },
    )
    assert response.status_code == 200, response.text
    prompt = captured["prompt"]
    assert "Why is KFC so much of my spending?" in prompt
    assert "Most visits were at KFC." in prompt
    assert "follow-ups only" in prompt


def _tools_json(prompt: str) -> dict:
    """The exact SQL tool payload embedded in the prompt.

    Parsed rather than substring-matched because the prompt instructions also
    mention the tool keys by name.
    """
    head = "Tool outputs (exact numbers):\n"
    tail = "\n\nRetrieved documents (examples only, do not sum):\n"
    body = prompt.split(head, 1)[1].split(tail, 1)[0]
    return json.loads(body)


def _offline_embeddings(monkeypatch) -> None:
    """Keep indexing and retrieval local so tests never reach the Gemini API.

    Needed because these tests set a fake api_key, and `embed_texts` now raises
    instead of silently writing hash vectors into a real index.
    """
    from app.services import rag_indexer, rag_retrieval
    from app.services.embeddings import hash_embed

    async def fake_embed(texts: list[str]) -> list[list[float]]:
        return [hash_embed(text) for text in texts]

    monkeypatch.setattr(rag_indexer, "embed_texts", fake_embed)
    monkeypatch.setattr(rag_retrieval, "embed_texts", fake_embed)


def _seed_utility_bills(api_client: TestClient) -> None:
    """Electricity and gas bills under the one shared Bills & Utilities slug."""
    for day, amount in (("05", 5400), ("06", 6100), ("07", 4800)):
        _post_tx(
            api_client,
            merchant="LESCO",
            amount=amount,
            tx_date=f"2026-03-{day}",
            category="Bills & Utilities",
        )
    for day, amount in (("08", 1200), ("09", 1350)):
        _post_tx(
            api_client,
            merchant="SNGPL",
            amount=amount,
            tx_date=f"2026-03-{day}",
            category="Bills & Utilities",
        )
    # Looks like electricity if `power` is used as a LIKE term; must not be.
    _post_tx(
        api_client,
        merchant="CURSOR AI POWER",
        amount=5864.71,
        tx_date="2026-03-04",
        category="Software",
    )
    # Bulk unrelated spend so LESCO is nowhere near the top-5 by amount.
    for i in range(6):
        _post_tx(
            api_client,
            merchant="Daraz",
            amount=50000 + i,
            tx_date=f"2026-03-{10 + i:02d}",
        )


def test_ask_electricity_totals_lesco_not_sngpl(
    api_client: TestClient, monkeypatch
) -> None:
    """The reported bug: "electricity" answered with SNGPL, a gas merchant."""
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "You paid PKR 16,300.00 to LESCO for electricity.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    _offline_embeddings(monkeypatch)

    _seed_utility_bills(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "how much i paid in electricity till now",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    assert response.status_code == 200, response.text
    matched = _tools_json(captured["prompt"])["matched_totals"]
    merchants = {row["merchant"] for row in matched["by_merchant"]}

    # 5400 + 6100 + 4800, exact and uncapped by the top-5 merchant limit.
    assert matched["grand_total_debit"] == 16300.0
    assert merchants == {"LESCO"}
    assert matched["transaction_count"] == 3
    # Gas must not be folded into an electricity total.
    assert "SNGPL" not in merchants
    # Generic `power` must not pull in an AI subscription.
    assert "CURSOR AI POWER" not in merchants
    citations = {item["merchant"] for item in response.json()["citations"]}
    assert citations == {"LESCO"}


def test_ask_gas_totals_sngpl_not_lesco(api_client: TestClient, monkeypatch) -> None:
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "You paid PKR 2,550.00 to SNGPL for gas.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    _offline_embeddings(monkeypatch)

    _seed_utility_bills(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "how much did I spend on gas",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    assert response.status_code == 200, response.text
    matched = _tools_json(captured["prompt"])["matched_totals"]
    merchants = {row["merchant"] for row in matched["by_merchant"]}
    assert matched["grand_total_debit"] == 2550.0
    assert merchants == {"SNGPL"}


def test_ask_prompt_forbids_summing_documents(
    api_client: TestClient, monkeypatch
) -> None:
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "LESCO totalled PKR 16,300.00.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    _offline_embeddings(monkeypatch)

    _seed_utility_bills(api_client)
    api_client.post(
        "/chat/ask",
        json={
            "question": "how much i paid in electricity",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    prompt = captured["prompt"]
    assert "never add them up" in prompt
    assert "complete total" in prompt


def test_ask_without_topic_has_no_matched_totals(
    api_client: TestClient, monkeypatch
) -> None:
    """No term match and no planner pick means no misleading empty total."""
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "Your largest merchant was Daraz.", "fake-model"

    async def no_picks(**kwargs):  # type: ignore[no-untyped-def]
        return []

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    monkeypatch.setattr(chat_rag, "plan_merchants", no_picks)
    _offline_embeddings(monkeypatch)

    _seed_utility_bills(api_client)
    api_client.post(
        "/chat/ask",
        json={
            "question": "what was my biggest transaction",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    assert "matched_totals" not in _tools_json(captured["prompt"])


def test_ask_planner_fallback_supplies_terms(
    api_client: TestClient, monkeypatch
) -> None:
    """A merchant with no alias entry still totals via the LLM planner."""
    from app.services import chat_rag

    captured: dict[str, str] = {}
    seen: dict[str, object] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "You spent PKR 300,015.00 at Daraz.", "fake-model"

    async def fake_plan(*, api_key: str, question: str, merchants: list[str]):
        seen["merchants"] = merchants
        return ["Daraz"]

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    monkeypatch.setattr(chat_rag, "plan_merchants", fake_plan)
    _offline_embeddings(monkeypatch)

    _seed_utility_bills(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "how much total did I spend at that online store",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    assert response.status_code == 200, response.text
    # The planner picks from the user's real merchants, never free-form names.
    assert "Daraz" in seen["merchants"]
    matched = _tools_json(captured["prompt"])["matched_totals"]
    assert {row["merchant"] for row in matched["by_merchant"]} == {"Daraz"}


def test_ask_planner_failure_still_answers(api_client: TestClient, monkeypatch) -> None:
    from app.services import chat_rag

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        return "Your largest merchant was Daraz.", "fake-model"

    async def boom(**kwargs):  # type: ignore[no-untyped-def]
        raise RuntimeError("planner exploded")

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    monkeypatch.setattr(chat_rag, "plan_merchants", boom)
    _offline_embeddings(monkeypatch)

    _seed_utility_bills(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "how much total did I spend somewhere",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    assert response.status_code == 200, response.text


def test_ask_settled_lists_primary_not_largest_debits(
    api_client: TestClient, monkeypatch
) -> None:
    """Settle is a status, not a merchant — cosine/largest_debits cannot answer it."""
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "Yes — Cafe is settled (net PKR 1,000.00).", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    _offline_embeddings(monkeypatch)

    _seed_ten(api_client)
    cafe = _post_tx(api_client, merchant="Cafe", amount=4000, tx_date="2026-09-01")
    friend = _post_tx(
        api_client,
        merchant="Friend A",
        amount=3000,
        tx_date="2026-09-01",
        tx_type="credit",
        category="Transfer",
    )
    settled = api_client.post(
        "/transactions/settle",
        json={"primaryId": cafe["id"], "sourceIds": [friend["id"]]},
    )
    assert settled.status_code == 200, settled.text

    response = api_client.post(
        "/chat/ask",
        json={
            "question": "give me settle transaction if any",
            "from": "2026-01-01",
            "to": "2026-12-31",
        },
    )
    assert response.status_code == 200, response.text
    tools = _tools_json(captured["prompt"])
    settled_rows = tools["settled_transactions"]
    assert {row["merchant"] for row in settled_rows} == {"Cafe"}
    assert all(row.get("status") == "settled" for row in settled_rows)
    citations = {item["merchant"] for item in response.json()["citations"]}
    assert citations == {"Cafe"}
    assert "Daraz" not in citations
    assert "KFC" not in citations
    assert "matched_totals" not in tools


def test_ask_settled_includes_just_settled_outside_receipt_window(
    api_client: TestClient, monkeypatch
) -> None:
    """A settlement today must surface even when the receipt is years old."""
    from app.services import chat_rag

    captured: dict[str, str] = {}

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        captured["prompt"] = prompt
        return "Cafe was just settled.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    _offline_embeddings(monkeypatch)

    _seed_ten(api_client)
    cafe = _post_tx(api_client, merchant="Cafe", amount=4000, tx_date="2024-01-15")
    friend = _post_tx(
        api_client,
        merchant="Friend A",
        amount=3000,
        tx_date="2024-01-15",
        tx_type="credit",
        category="Transfer",
    )
    settled = api_client.post(
        "/transactions/settle",
        json={"primaryId": cafe["id"], "sourceIds": [friend["id"]]},
    )
    assert settled.status_code == 200, settled.text

    today = date.today().isoformat()
    response = api_client.post(
        "/chat/ask",
        json={"question": "any settled transactions?", "from": today, "to": today},
    )
    assert response.status_code == 200, response.text
    tools = _tools_json(captured["prompt"])
    assert {row["merchant"] for row in tools["settled_transactions"]} == {"Cafe"}


def test_ask_show_settled_is_not_navigation(
    api_client: TestClient, monkeypatch
) -> None:
    from app.services import chat_rag

    async def fake_generate(api_key: str, prompt: str) -> tuple[str, str]:
        return "No settlements in this window.", "fake-model"

    monkeypatch.setattr(get_settings(), "gemini_api_key", "test-key")
    monkeypatch.setattr(chat_rag, "generate_chat_answer", fake_generate)
    _offline_embeddings(monkeypatch)

    _seed_ten(api_client)
    response = api_client.post(
        "/chat/ask",
        json={
            "question": "show me settled transactions",
            "from": "2026-03-01",
            "to": "2026-03-31",
        },
    )
    assert response.status_code == 200, response.text
    assert response.json()["source"] == "gemini"
