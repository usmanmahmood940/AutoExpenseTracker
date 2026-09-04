"""Retrieval is user-scoped and ranks by cosine distance."""

from __future__ import annotations

from datetime import date
from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.api import deps
from app.core.firebase import FirebaseIdentity
from app.db.models.enums import RagDocType
from app.db.models.rag_document import RagDocument
from app.db.models.user import User
from app.main import create_app
from app.services.embeddings import hash_embed
from app.services.rag_retrieval import retrieve
from tests.conftest import run_isolated
from tests.test_transactions import _post_tx


def test_retrieval_ranks_intended_merchant(api_client: TestClient) -> None:
    _post_tx(api_client, merchant="KFC", amount=500, tx_date="2026-03-10")
    _post_tx(
        api_client,
        merchant="PSO RANGERS",
        amount=2000,
        tx_date="2026-03-11",
        category="Fuel",
    )
    user_id = UUID(api_client.get("/me").json()["id"])

    async def search(session):  # type: ignore[no-untyped-def]
        hits = await retrieve(
            session, user_id=user_id, query_text="KFC spending", limit=10
        )
        return [hit.content_text for hit in hits]

    texts = run_isolated(search)
    assert texts
    assert any("KFC" in text for text in texts)
    assert texts[0].count("KFC") >= 1


def test_retrieval_same_user_only() -> None:
    uid_a = "uid-rag-a"
    app_a = create_app()
    app_a.dependency_overrides[deps.get_current_identity] = lambda: FirebaseIdentity(
        uid=uid_a, email="a@example.com", email_verified=True, claims={}
    )
    with TestClient(app_a) as client_a:
        client_a.get("/me")
        _post_tx(client_a, merchant="KFC", amount=500, tx_date="2026-03-10")
        user_a = UUID(client_a.get("/me").json()["id"])

    uid_b = "uid-rag-b"
    app_b = create_app()
    app_b.dependency_overrides[deps.get_current_identity] = lambda: FirebaseIdentity(
        uid=uid_b, email="b@example.com", email_verified=True, claims={}
    )
    with TestClient(app_b) as client_b:
        client_b.get("/me")
        _post_tx(
            client_b,
            merchant="PSO RANGERS",
            amount=2000,
            tx_date="2026-03-11",
            category="Fuel",
        )
        user_b = UUID(client_b.get("/me").json()["id"])

    async def search(session):  # type: ignore[no-untyped-def]
        hits_a = await retrieve(
            session, user_id=user_a, query_text="PSO RANGERS", limit=10
        )
        hits_b = await retrieve(session, user_id=user_b, query_text="KFC", limit=10)
        return [hit.content_text for hit in hits_a], [
            hit.content_text for hit in hits_b
        ]

    texts_a, texts_b = run_isolated(search)
    assert all("PSO" not in text for text in texts_a)
    assert all("KFC" not in text for text in texts_b)


def test_retrieval_seeded_vectors_rank_kfc() -> None:
    """Insert fake vectors so ranking does not depend on transaction hooks."""

    async def seed_and_search(session):  # type: ignore[no-untyped-def]
        user = User(
            email=f"vec-{uuid4().hex[:8]}@example.com",
            firebase_uid=f"uid-vec-{uuid4().hex[:8]}",
            bank_senders=[],
            email_filters=[],
        )
        session.add(user)
        await session.flush()
        kfc = RagDocument(
            user_id=user.id,
            doc_type=RagDocType.transaction.value,
            content_text=(
                "2026-03-10 | debit | PKR 500.00 | KFC | Food & Dining | unknown"
            ),
            embedding=hash_embed("KFC fried chicken"),
            ref_id="kfc-ref",
            period_from=date(2026, 3, 10),
            period_to=date(2026, 3, 10),
            fingerprint="kfc",
        )
        pso = RagDocument(
            user_id=user.id,
            doc_type=RagDocType.transaction.value,
            content_text=(
                "2026-03-11 | debit | PKR 2000.00 | PSO RANGERS | Fuel | unknown"
            ),
            embedding=hash_embed("PSO petrol pump diesel"),
            ref_id="pso-ref",
            period_from=date(2026, 3, 11),
            period_to=date(2026, 3, 11),
            fingerprint="pso",
        )
        session.add_all([kfc, pso])
        await session.commit()
        hits = await retrieve(session, user_id=user.id, query_text="KFC", limit=2)
        return [hit.ref_id for hit in hits]

    ranking = run_isolated(seed_and_search)
    assert ranking[0] == "kfc-ref"
