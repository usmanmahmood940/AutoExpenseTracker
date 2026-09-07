"""RAG indexer: upsert, fingerprint skip, soft-delete, no SMS in content."""

from __future__ import annotations

from datetime import date

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.db.models.rag_document import EMBEDDING_DIM, RagDocument
from app.services.embeddings import active_embedding_model, hash_embed
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


def test_utility_docs_carry_topic_keywords(api_client: TestClient) -> None:
    """Without this, `electricity` has nothing to match on a LESCO row."""
    lesco = _post_tx(api_client, merchant="LESCO", amount=5400, tx_date="2026-03-10")
    doc = _docs_for(lesco["id"])[0]
    assert "electricity" in doc.content_text
    assert "gas" not in doc.content_text

    sngpl = _post_tx(api_client, merchant="SNGPL", amount=1200, tx_date="2026-03-11")
    gas_doc = _docs_for(sngpl["id"])[0]
    assert "gas" in gas_doc.content_text
    assert "electricity" not in gas_doc.content_text


def test_unrelated_merchant_gets_no_keywords(api_client: TestClient) -> None:
    created = _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    doc = _docs_for(created["id"])[0]
    assert doc.content_text.endswith("unknown")


def test_embedding_model_is_stamped(api_client: TestClient) -> None:
    created = _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    doc = _docs_for(created["id"])[0]
    assert doc.embedding_model == active_embedding_model()


def test_doc_schema_version_forces_reembed() -> None:
    """A doc-format change must invalidate fingerprints, or reindex no-ops."""
    from app.services import rag_documents

    class _Tx:
        amount = 500
        merchant_normalized = "kfc"
        category = "Food & Dining"
        status = "active"
        type = "debit"

        def __init__(self, day: int) -> None:
            self.transaction_date = date(2026, 3, day)

    tx = _Tx(10)
    original = rag_documents.doc_fingerprint(tx)
    try:
        rag_documents.DOC_SCHEMA_VERSION += 1
        bumped = rag_documents.doc_fingerprint(tx)
    finally:
        rag_documents.DOC_SCHEMA_VERSION -= 1
    assert bumped != original
    assert rag_documents.doc_fingerprint(tx) == original


def test_stale_embedding_model_triggers_rewrite() -> None:
    """Rows from another embedding model are not comparable, so re-embed."""
    from app.db.models.rag_document import RagDocument
    from app.services.rag_indexer import _is_stale

    row = RagDocument(fingerprint="abc", embedding_model="some-old-model")
    assert _is_stale(row, "abc")

    row.embedding_model = active_embedding_model()
    assert not _is_stale(row, "abc")
    assert _is_stale(row, "different-fingerprint")


def test_legacy_null_embedding_model_is_stale() -> None:
    """Rows written before the column existed must be reindexed."""
    from app.db.models.rag_document import RagDocument
    from app.services.rag_indexer import _is_stale

    row = RagDocument(fingerprint="abc", embedding_model=None)
    assert _is_stale(row, "abc")


def test_reindex_rewrites_legacy_docs(api_client: TestClient, monkeypatch) -> None:
    """End-to-end backfill: a pre-enrichment row gains keywords and a model."""
    from uuid import UUID

    from app.services import rag_indexer

    async def fake_embed(texts: list[str]) -> list[list[float]]:
        return [hash_embed(text) for text in texts]

    monkeypatch.setattr(rag_indexer, "embed_texts", fake_embed)

    created = _post_tx(api_client, merchant="LESCO", amount=5400, tx_date="2026-03-10")
    user_id = UUID(api_client.get("/me").json()["id"])
    tx_id = created["id"]

    async def make_legacy(session):  # type: ignore[no-untyped-def]
        doc = (
            await session.execute(
                select(RagDocument).where(RagDocument.ref_id == tx_id)
            )
        ).scalar_one()
        # Mimic a row written before enrichment and before the model column.
        doc.content_text = (
            "2026-03-10 | debit | PKR 5400.00 | LESCO | Bills & Utilities | unknown"
        )
        doc.fingerprint = "legacy-fingerprint"
        doc.embedding_model = None
        await session.commit()

    run_isolated(make_legacy)

    before = _docs_for(tx_id)[0]
    assert "electricity" not in before.content_text
    assert before.embedding_model is None

    async def backfill(session):  # type: ignore[no-untyped-def]
        return await rag_indexer.reindex_users(session, user_id=user_id, full=True)

    stats = run_isolated(backfill)
    assert stats.transactions == 1

    after = _docs_for(tx_id)[0]
    assert "electricity" in after.content_text
    assert after.embedding_model == active_embedding_model()
    assert after.fingerprint != "legacy-fingerprint"
