"""Review queue + mark reviewed + complete-from-ingestion."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.db.models.enums import IngestionSource, IngestionStatus
from app.db.models.raw_ingestion import RawIngestion
from app.services.user_profile import get_by_email
from tests.conftest import run_isolated
from tests.test_transactions import _post_tx


def test_review_flow(api_client: TestClient) -> None:
    created = _post_tx(
        api_client, merchant="Unknown Shop", amount=150, tx_date="2026-03-12"
    )
    tx_id = created["id"]
    patched = api_client.patch(
        f"/transactions/{tx_id}", json={"status": "needs_review"}
    )
    assert patched.status_code == 200

    email = api_client.get("/me").json()["email"]

    async def seed(session):  # type: ignore[no-untyped-def]
        user = await get_by_email(session, email)
        assert user is not None
        row = RawIngestion(
            user_id=user.id,
            raw="HBL: PKR 200 debited at PSO",
            source=IngestionSource.ios_shortcut,
            status=IngestionStatus.needs_parse,
            received_at=datetime.now(UTC),
        )
        session.add(row)
        session.add(
            RawIngestion(
                user_id=user.id,
                raw="duplicate sms",
                source=IngestionSource.gmail,
                status=IngestionStatus.duplicate,
                received_at=datetime.now(UTC),
            )
        )
        await session.commit()
        await session.refresh(row)
        return str(row.id)

    ingestion_id = run_isolated(seed)

    queue = api_client.get("/review").json()
    assert queue["pending_count"] == 2
    assert len(queue["needs_review"]) == 1
    assert len(queue["needs_parse"]) == 1
    assert len(queue["duplicates"]) == 1

    reviewed = api_client.post(f"/transactions/{tx_id}/review")
    assert reviewed.status_code == 200
    assert reviewed.json()["status"] == "active"
    assert reviewed.json()["reviewed_at"] is not None

    completed = api_client.post(
        "/transactions",
        json={
            "merchant": "PSO",
            "amount": 200,
            "transaction_date": "2026-03-12",
            "ingestion_id": ingestion_id,
        },
    )
    assert completed.status_code == 201, completed.text
    assert completed.json()["sms_source"]["raw"].startswith("HBL")

    after = api_client.get("/review").json()
    assert after["pending_count"] == 0
    assert after["needs_parse"] == []
    assert after["needs_review"] == []
