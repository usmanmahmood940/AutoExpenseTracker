"""POST /transactions/parse — Gemini stubbed, no writes."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.api import deps
from app.core.firebase import FirebaseIdentity
from app.main import create_app
from app.services.firebase_users import FirebaseUser
from app.services.gemini import ParsedTransaction, ParseFail, ParseOk

PSO_RAW = (
    "PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 "
    "(DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522"
)

INGEST_BODY = {
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
def parse_client(
    monkeypatch: pytest.MonkeyPatch,
) -> Generator[tuple[TestClient, str], None, None]:
    uid = f"uid-{uuid4().hex[:12]}"
    email = f"{uid}@example.com"

    async def fake_get(lookup: str) -> FirebaseUser | None:
        if lookup != uid:
            return None
        return FirebaseUser(uid=uid, email=email, email_verified=True, disabled=False)

    async def fake_parse(*_args: object, **_kwargs: object) -> ParseOk:
        return ParseOk(parsed=_parsed(), model="gemini-test")

    async def fake_notify(session: object, *, user_id: object, tx: object) -> None:
        return None

    monkeypatch.setattr("app.services.firebase_users.get_by_uid", fake_get)
    monkeypatch.setattr("app.api.routes.ingest.firebase_users.get_by_uid", fake_get)
    monkeypatch.setattr("app.services.ingest.parse_transaction", fake_parse)
    monkeypatch.setattr("app.api.routes.ingest.notify_new_transaction", fake_notify)

    app = create_app()
    app.dependency_overrides[deps.get_current_identity] = lambda: FirebaseIdentity(
        uid=uid, email=email, email_verified=True, claims={}
    )
    with TestClient(app) as client:
        assert client.get("/me").status_code == 200
        yield client, uid


def test_parse_requires_auth(client: TestClient) -> None:
    with client:
        response = client.post("/transactions/parse", json={"raw": "spent 200 at KFC"})
    assert response.status_code == 401


def test_parse_happy_path_does_not_write(
    parse_client: tuple[TestClient, str],
) -> None:
    client, _ = parse_client
    response = client.post(
        "/transactions/parse",
        json={"raw": PSO_RAW, "source": "manual"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["ok"] is True
    assert body["duplicate"] is False
    assert body["merchant"] == "PSO RANGERS"
    assert body["amount"] == 5990.0
    assert body["category"] == "Fuel"
    assert body["parse_confidence"] == 0.95
    assert body["model"] == "gemini-test"
    assert body["transaction_id"] is None

    listed = client.get("/transactions").json()
    assert listed["items"] == []


def test_parse_fail_returns_ok_false(
    parse_client: tuple[TestClient, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client, _ = parse_client

    async def fail(*_args: object, **_kwargs: object) -> ParseFail:
        return ParseFail(error="Could not parse that message")

    monkeypatch.setattr("app.services.ingest.parse_transaction", fail)
    response = client.post(
        "/transactions/parse",
        json={"raw": "hello there", "source": "manual"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["ok"] is False
    assert "Could not parse" in body["error"]
    assert body["merchant"] is None


def test_parse_duplicate_returns_existing_id(
    parse_client: tuple[TestClient, str],
) -> None:
    client, uid = parse_client
    ingested = client.post("/ingest", json=INGEST_BODY, headers={"X-User-Id": uid})
    assert ingested.status_code == 200, ingested.text
    payload = ingested.json()
    assert payload["success"] is True
    existing_id = payload["transactionId"]

    parsed = client.post(
        "/transactions/parse",
        json={"raw": PSO_RAW, "source": "manual"},
    )
    assert parsed.status_code == 200, parsed.text
    body = parsed.json()
    assert body["ok"] is True
    assert body["duplicate"] is True
    assert body["transaction_id"] == existing_id
    assert body["merchant"] == "PSO RANGERS"
