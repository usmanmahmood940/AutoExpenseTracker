"""Internal job endpoints that replace Firestore triggers / cleanupExpiredAuthDocs."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.db.models.auth_otp import AuthOtp, OtpPurpose
from app.main import create_app
from tests.conftest import run_isolated


def test_cleanup_auth_deletes_expired_otps() -> None:
    async def seed(session):  # type: ignore[no-untyped-def]
        session.add(
            AuthOtp(
                email="stale@example.com",
                purpose=OtpPurpose.email_verification,
                code_hash="abc",
                expires_at=datetime.now(UTC) - timedelta(hours=1),
            )
        )
        await session.commit()

    run_isolated(seed)

    with TestClient(create_app()) as client:
        response = client.post("/internal/jobs/cleanup-auth")
    assert response.status_code == 200
    assert response.json()["auth_otps"] >= 1


def test_recompute_summaries_empty() -> None:
    with TestClient(create_app()) as client:
        response = client.post("/internal/jobs/recompute-summaries", json={})
    assert response.status_code == 200
    assert "months_updated" in response.json()


def test_reindex_rag_empty() -> None:
    with TestClient(create_app()) as client:
        response = client.post("/internal/jobs/reindex-rag", json={"full": True})
    assert response.status_code == 200, response.text
    body = response.json()
    assert "users" in body
    assert "transactions" in body
