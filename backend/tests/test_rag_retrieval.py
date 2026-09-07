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
from app.services.rag_retrieval import retrieve, retrieve_lexical
from tests.conftest import run_isolated
from tests.test_transactions import _post_tx


def _seed_utility_docs(session, user):  # type: ignore[no-untyped-def]
    """A LESCO and an SNGPL doc carrying enrichment keywords, plus a rollup."""
    lesco = RagDocument(
        user_id=user.id,
        doc_type=RagDocType.transaction.value,
        content_text=(
            "2026-03-10 | debit | PKR 5400.00 | LESCO | Bills & Utilities | "
            "unknown | electricity electric power light bill utility"
        ),
        embedding=hash_embed("LESCO bill"),
        ref_id="lesco-tx",
        period_from=date(2026, 3, 10),
        period_to=date(2026, 3, 10),
        fingerprint="lesco",
    )
    sngpl = RagDocument(
        user_id=user.id,
        doc_type=RagDocType.transaction.value,
        content_text=(
            "2026-03-12 | debit | PKR 1200.00 | SNGPL | Bills & Utilities | "
            "unknown | gas sui gas utility"
        ),
        embedding=hash_embed("SNGPL bill"),
        ref_id="sngpl-tx",
        period_from=date(2026, 3, 12),
        period_to=date(2026, 3, 12),
        fingerprint="sngpl",
    )
    rollup = RagDocument(
        user_id=user.id,
        doc_type=RagDocType.merchant.value,
        content_text=(
            "merchant | LESCO | 6 visits | total PKR 32000.00 | "
            "avg PKR 5333.33 | last 2026-03-10 | electricity electric power"
        ),
        embedding=hash_embed("LESCO rollup"),
        ref_id="lesco-merchant",
        period_from=None,
        period_to=None,
        fingerprint="lesco-merchant",
    )
    session.add_all([lesco, sngpl, rollup])


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


def test_strict_period_skips_null_period_docs() -> None:
    async def seed_and_search(session):  # type: ignore[no-untyped-def]
        user = User(
            email=f"strict-{uuid4().hex[:8]}@example.com",
            firebase_uid=f"uid-strict-{uuid4().hex[:8]}",
            bank_senders=[],
            email_filters=[],
        )
        session.add(user)
        await session.flush()
        merchant = RagDocument(
            user_id=user.id,
            doc_type=RagDocType.merchant.value,
            content_text="merchant | KFC | 20 visits | total PKR 8000",
            embedding=hash_embed("KFC fried chicken"),
            ref_id="kfc-merchant",
            period_from=None,
            period_to=None,
            fingerprint="merchant-kfc",
        )
        tx = RagDocument(
            user_id=user.id,
            doc_type=RagDocType.transaction.value,
            content_text=(
                "2026-03-10 | debit | PKR 500.00 | KFC | Food & Dining | unknown"
            ),
            embedding=hash_embed("KFC fried chicken"),
            ref_id="kfc-tx",
            period_from=date(2026, 3, 10),
            period_to=date(2026, 3, 10),
            fingerprint="tx-kfc",
        )
        session.add_all([merchant, tx])
        await session.commit()
        loose = await retrieve(
            session,
            user_id=user.id,
            query_text="KFC",
            limit=10,
            date_from=date(2026, 1, 1),
            date_to=date(2026, 12, 31),
        )
        strict = await retrieve(
            session,
            user_id=user.id,
            query_text="KFC",
            limit=10,
            doc_types=["transaction"],
            date_from=date(2026, 1, 1),
            date_to=date(2026, 12, 31),
            strict_period=True,
        )
        return [hit.ref_id for hit in loose], [hit.doc_type for hit in strict]

    loose_ids, strict_types = run_isolated(seed_and_search)
    assert "kfc-merchant" in loose_ids
    assert strict_types
    assert all(doc_type == "transaction" for doc_type in strict_types)


def _utility_user(session):  # type: ignore[no-untyped-def]
    return User(
        email=f"util-{uuid4().hex[:8]}@example.com",
        firebase_uid=f"uid-util-{uuid4().hex[:8]}",
        bank_senders=[],
        email_filters=[],
    )


def test_lexical_finds_electricity_and_excludes_gas() -> None:
    """The whole point: `electricity` must reach LESCO and not SNGPL."""

    async def seed_and_search(session):  # type: ignore[no-untyped-def]
        user = _utility_user(session)
        session.add(user)
        await session.flush()
        _seed_utility_docs(session, user)
        await session.commit()
        hits = await retrieve_lexical(
            session,
            user_id=user.id,
            terms=["electricity", "lesco"],
            limit=10,
            doc_types=["transaction"],
            date_from=date(2026, 1, 1),
            date_to=date(2026, 12, 31),
            strict_period=True,
        )
        return [hit.ref_id for hit in hits]

    refs = run_isolated(seed_and_search)
    assert "lesco-tx" in refs
    assert "sngpl-tx" not in refs


def test_lexical_returns_nothing_without_terms() -> None:
    async def seed_and_search(session):  # type: ignore[no-untyped-def]
        user = _utility_user(session)
        session.add(user)
        await session.flush()
        _seed_utility_docs(session, user)
        await session.commit()
        return await retrieve_lexical(session, user_id=user.id, terms=[], limit=10)

    assert run_isolated(seed_and_search) == []


def test_lexical_escapes_like_metacharacters() -> None:
    async def seed_and_search(session):  # type: ignore[no-untyped-def]
        user = _utility_user(session)
        session.add(user)
        await session.flush()
        _seed_utility_docs(session, user)
        await session.commit()
        # `%` must be treated literally, not as "match everything".
        return await retrieve_lexical(session, user_id=user.id, terms=["%"], limit=10)

    assert run_isolated(seed_and_search) == []


def test_periodless_merchant_docs_survive_strict_period() -> None:
    async def seed_and_search(session):  # type: ignore[no-untyped-def]
        user = _utility_user(session)
        session.add(user)
        await session.flush()
        _seed_utility_docs(session, user)
        await session.commit()
        dropped = await retrieve_lexical(
            session,
            user_id=user.id,
            terms=["electricity"],
            limit=10,
            doc_types=["merchant"],
            date_from=date(2026, 1, 1),
            date_to=date(2026, 12, 31),
            strict_period=True,
        )
        kept = await retrieve_lexical(
            session,
            user_id=user.id,
            terms=["electricity"],
            limit=10,
            doc_types=["merchant"],
            date_from=date(2026, 1, 1),
            date_to=date(2026, 12, 31),
            strict_period=True,
            periodless_doc_types=["merchant"],
        )
        return [h.ref_id for h in dropped], [h.ref_id for h in kept]

    dropped, kept = run_isolated(seed_and_search)
    assert dropped == []
    assert "lesco-merchant" in kept


def test_vector_retrieval_degrades_when_embedding_fails(monkeypatch) -> None:
    """A dead embedding API must not take the whole answer down."""
    from app.services import rag_retrieval
    from app.services.embeddings import EmbeddingError

    async def boom(texts):  # type: ignore[no-untyped-def]
        raise EmbeddingError("gemini down")

    monkeypatch.setattr(rag_retrieval, "embed_texts", boom)

    async def search(session):  # type: ignore[no-untyped-def]
        user = _utility_user(session)
        session.add(user)
        await session.flush()
        _seed_utility_docs(session, user)
        await session.commit()
        return await retrieve(session, user_id=user.id, query_text="LESCO", limit=5)

    assert run_isolated(search) == []
