"""POST /ingest — Gemini stubbed, Firebase UID lookup stubbed."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.services.firebase_users import FirebaseUser
from app.services.gemini import ParsedTransaction, ParseFail, ParseOk

PSO_RAW = (
    "PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 "
    "(DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522"
)

BODY = {
    "raw": PSO_RAW,
    "source": "ios_shortcut",
    "receivedAt": "2026-07-06T11:27:00+05:00",
    "bank": "HBL",
}


def _parsed(**overrides: object) -> ParsedTransaction:
    fields: dict[str, object] = {
        "amount": 5990.0,
        "currency": "PKR",
        "type": "debit",
        "merchant": "PSO RANGERS",
        "merchant_details": "LAH",
        "category": "Fuel",
        "payment_method": "debit_card",
        "bank": "Unknown",
        "account_id": "xxx1215",
        "branch": "DHA PHASE VIII BR LHR",
        "transaction_time": "2026-07-06T11:27:00+05:00",
        "transaction_date": "2026-07-06",
        "external_id": "387522",
        "external_id_type": "tid",
        "parse_confidence": 0.95,
    }
    fields.update(overrides)
    return ParsedTransaction(**fields)  # type: ignore[arg-type]


@pytest.fixture
def ingest_env(monkeypatch: pytest.MonkeyPatch) -> Generator[str, None, None]:
    uid = f"uid-{uuid4().hex[:12]}"

    async def fake_get(lookup: str) -> FirebaseUser | None:
        if lookup == "missing-user":
            return None
        if lookup != uid:
            return None
        return FirebaseUser(
            uid=uid, email=f"{uid}@example.com", email_verified=True, disabled=False
        )

    async def fake_parse(*_args: object, **_kwargs: object) -> ParseOk:
        return ParseOk(parsed=_parsed(), model="gemini-test")

    async def fake_notify(session: object, *, user_id: object, tx: object) -> None:
        return None

    monkeypatch.setattr("app.services.firebase_users.get_by_uid", fake_get)
    monkeypatch.setattr("app.api.routes.ingest.firebase_users.get_by_uid", fake_get)
    monkeypatch.setattr("app.services.ingest.parse_transaction", fake_parse)
    monkeypatch.setattr("app.api.routes.ingest.notify_new_transaction", fake_notify)
    yield uid


@pytest.fixture
def ingest_client(ingest_env: str) -> Generator[tuple[TestClient, str], None, None]:
    with TestClient(create_app()) as client:
        yield client, ingest_env


def test_missing_uid(ingest_client: tuple[TestClient, str]) -> None:
    client, _ = ingest_client
    response = client.post("/ingest", json=BODY)
    assert response.status_code == 400
    assert response.json()["success"] is False
    assert "uid is required" in response.json()["error"]


def test_invalid_uid(ingest_client: tuple[TestClient, str]) -> None:
    client, _ = ingest_client
    response = client.post("/ingest", json=BODY, headers={"X-User-Id": "bad uid!"})
    assert response.status_code == 400
    assert "1–128" in response.json()["error"]  # noqa: RUF001


def test_unknown_uid(ingest_client: tuple[TestClient, str]) -> None:
    client, _ = ingest_client
    response = client.post("/ingest", json=BODY, headers={"X-User-Id": "missing-user"})
    assert response.status_code == 404
    assert "does not exist" in response.json()["error"]


def test_invalid_body(ingest_client: tuple[TestClient, str]) -> None:
    client, uid = ingest_client
    response = client.post(
        "/ingest", json={"source": "ios_shortcut"}, headers={"X-User-Id": uid}
    )
    assert response.status_code == 400
    assert "raw is required" in response.json()["error"]


def test_happy_path_creates_transaction(
    ingest_client: tuple[TestClient, str],
) -> None:
    client, uid = ingest_client
    response = client.post("/ingest", json=BODY, headers={"X-User-Id": uid})
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["ingestionId"]
    assert payload["transactionId"]
    assert "duplicate" not in payload


def test_webhook_alias(ingest_client: tuple[TestClient, str]) -> None:
    client, uid = ingest_client
    body = {**BODY, "idempotencyKey": f"alias-{uuid4().hex}"}
    response = client.post("/webhooks/sms", json=body, headers={"X-User-Id": uid})
    assert response.status_code == 200
    assert response.json()["success"] is True


def test_duplicate_by_dedup_key(ingest_client: tuple[TestClient, str]) -> None:
    client, uid = ingest_client
    first = client.post("/ingest", json=BODY, headers={"X-User-Id": uid})
    second = client.post(
        "/ingest",
        json={**BODY, "idempotencyKey": "second-event"},
        headers={"X-User-Id": uid},
    )
    assert first.json()["success"] is True
    assert second.json()["duplicate"] is True
    assert second.json()["transactionId"] == first.json()["transactionId"]


def test_idempotency_returns_same_ingestion(
    ingest_client: tuple[TestClient, str],
) -> None:
    client, uid = ingest_client
    body = {**BODY, "idempotencyKey": f"once-{uuid4().hex}"}
    first = client.post("/ingest", json=body, headers={"X-User-Id": uid})
    second = client.post("/ingest", json=body, headers={"X-User-Id": uid})
    assert first.json()["ingestionId"] == second.json()["ingestionId"]
    assert first.json()["transactionId"] == second.json()["transactionId"]


def test_parse_failure_needs_parse(
    ingest_client: tuple[TestClient, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client, uid = ingest_client

    async def fail(*_args: object, **_kwargs: object) -> ParseFail:
        return ParseFail(error="Could not parse transaction from SMS")

    monkeypatch.setattr("app.services.ingest.parse_transaction", fail)
    response = client.post(
        "/ingest",
        json={**BODY, "raw": "hello this is not a transaction"},
        headers={"X-User-Id": uid},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is False
    assert payload["ingestionId"]
    assert "Could not parse" in payload["error"]


def test_low_confidence_needs_review(
    ingest_client: tuple[TestClient, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client, uid = ingest_client

    async def low(*_args: object, **_kwargs: object) -> ParseOk:
        return ParseOk(
            parsed=_parsed(parse_confidence=0.72, external_id="low-conf-1"),
            model="gemini-test",
        )

    monkeypatch.setattr("app.services.ingest.parse_transaction", low)
    response = client.post(
        "/ingest",
        json={**BODY, "idempotencyKey": f"low-{uuid4().hex}"},
        headers={"X-User-Id": uid},
    )
    assert response.status_code == 200
    tx_id = response.json()["transactionId"]
    from uuid import UUID

    from app.db.models.transaction import Transaction
    from tests.conftest import run_isolated

    async def load(session):  # type: ignore[no-untyped-def]
        return await session.get(Transaction, UUID(tx_id))

    tx = run_isolated(load)
    assert tx is not None
    assert tx.status.value == "needs_review"
