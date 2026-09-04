"""RAG indexer: upsert, fingerprint skip, soft-delete, no SMS in content."""

from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.db.models.rag_document import EMBEDDING_DIM, RagDocument
from app.services.embeddings import hash_embed
from tests.conftest import run_isolated
from tests.test_transactions import _post_tx


def _docs_for(tx_id: str) -> list[RagDocument]:
    async def load(session):  # type: ignore[no-untyped-def]
        return list(
            (
                await session.execute(
                    select(RagDocument).where(RagDocument.ref_id == tx_id)
                )
            ).scalars()
        )

    return run_isolated(load)


def test_hash_embed_is_768d() -> None:
    vec = hash_embed("KFC debit PKR 500")
    assert len(vec) == EMBEDDING_DIM
    assert abs(sum(v * v for v in vec) ** 0.5 - 1.0) < 1e-6


def test_upsert_on_create(api_client: TestClient) -> None:
    created = _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    docs = _docs_for(created["id"])
    assert len(docs) == 1
    doc = docs[0]
    assert doc.doc_type == "transaction"
    assert "KFC" in doc.content_text
    assert "500.00" in doc.content_text
    assert "Food & Dining" in doc.content_text
    assert "2026-03-10" in doc.content_text
    assert "sms" not in doc.content_text.lower()
    assert "v1:" not in doc.content_text


def test_fingerprint_skip_when_unindexed_fields_change(api_client: TestClient) -> None:
    created = _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    before = _docs_for(created["id"])[0]

    patched = api_client.patch(f"/transactions/{created['id']}", json={"bank": "MCB"})
    assert patched.status_code == 200, patched.text
    after = _docs_for(created["id"])[0]
    assert after.fingerprint == before.fingerprint
    assert after.content_text == before.content_text


def test_fingerprint_updates_when_merchant_changes(api_client: TestClient) -> None:
    created = _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    before = _docs_for(created["id"])[0]
    patched = api_client.patch(
        f"/transactions/{created['id']}", json={"merchant": "Daraz"}
    )
    assert patched.status_code == 200, patched.text
    after = _docs_for(created["id"])[0]
    assert after.fingerprint != before.fingerprint
    assert "Daraz" in after.content_text
    assert "KFC" not in after.content_text


def test_delete_on_soft_delete(api_client: TestClient) -> None:
    created = _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    assert _docs_for(created["id"])
    deleted = api_client.delete(f"/transactions/{created['id']}")
    assert deleted.status_code == 204, deleted.text
    assert _docs_for(created["id"]) == []


def test_note_sms_not_indexed(api_client: TestClient) -> None:
    response = api_client.post(
        "/transactions",
        json={
            "merchant": "KFC",
            "amount": 200,
            "transaction_date": "2026-03-01",
            "note": "SECRET_SMS_BODY v1:should-not-index",
        },
    )
    assert response.status_code == 201, response.text
    doc = _docs_for(response.json()["id"])[0]
    assert "SECRET_SMS_BODY" not in doc.content_text
    assert "v1:should-not-index" not in doc.content_text
    assert "raw" not in doc.content_text.lower()
