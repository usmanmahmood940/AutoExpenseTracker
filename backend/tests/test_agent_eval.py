"""Agent golden / eval-style tests (no live Gemini)."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.agent_proposal import AgentProposal, AgentProposalStatus
from app.db.models.enums import TransactionStatus, TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services.agent.executor import execute_proposal
from app.services.agent.read_tools import aggregate_spending, query_transactions
from app.services.agent.write_tools import persist_proposal
from app.services.semantic import (
    concepts_from_question_deterministic,
    seed_known_merchant_concepts,
)
from app.services.semantic.question_resolver import resolve_concepts_from_question


EVAL_CASES = [
    ("How much did I spend on electricity?", ["electricity"]),
    ("What did I spend on LESCO?", []),  # merchant-named; may be empty concepts
    ("Show settled transactions", []),
    ("Show merged transactions", []),
    ("How much did I spend on food in March?", ["restaurant"]),
    ("How much on fast food?", ["fast_food"]),
]


@pytest.mark.parametrize("question,expected", EVAL_CASES)
def test_eval_concept_resolution(question: str, expected: list[str]) -> None:
    concepts = concepts_from_question_deterministic(question)
    for tag in expected:
        assert tag in concepts, (question, concepts)


@pytest.mark.asyncio
async def test_aggregate_spending_electricity(session: AsyncSession) -> None:
    user = User(
        firebase_uid=f"uid-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@example.com",
    )
    session.add(user)
    await session.flush()
    await seed_known_merchant_concepts(session)
    session.add(
        Transaction(
            user_id=user.id,
            amount=Decimal("1200"),
            currency="PKR",
            type=TransactionType.debit,
            merchant="LESCO",
            merchant_normalized="lesco",
            category="Bills & Utilities",
            payment_method="unknown",
            transaction_date=date(2026, 3, 1),
            day="Sunday",
            dedup_key=f"eval-{uuid4().hex[:8]}",
            status=TransactionStatus.active,
        )
    )
    await session.commit()

    result = await aggregate_spending(
        session,
        user=user,
        args={
            "date_from": "2026-01-01",
            "date_to": "2026-12-31",
            "concepts": ["electricity"],
            "group_by": "merchant",
        },
    )
    assert result["grand_total"] == 1200.0
    assert result["transaction_count"] == 1
    assert len(result["transactions"]) == 1
    assert result["transactions"][0]["merchant"] == "LESCO"
    assert result["filter_types"] == ["debit"]


@pytest.mark.asyncio
async def test_aggregate_spending_credit_samples_exclude_debit(
    session: AsyncSession,
) -> None:
    user = User(
        firebase_uid=f"uid-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@example.com",
    )
    session.add(user)
    await session.flush()
    for amount, tx_type, day in (
        (Decimal("552"), TransactionType.debit, date(2026, 8, 11)),
        (Decimal("700"), TransactionType.debit, date(2026, 8, 7)),
        (Decimal("800"), TransactionType.credit, date(2026, 8, 10)),
        (Decimal("660"), TransactionType.credit, date(2026, 8, 5)),
    ):
        session.add(
            Transaction(
                user_id=user.id,
                amount=amount,
                currency="PKR",
                type=tx_type,
                merchant="W.ANJUM",
                merchant_normalized="w.anjum",
                category="Transfer",
                payment_method="unknown",
                transaction_date=day,
                day=day.strftime("%A"),
                dedup_key=f"eval-wa-{uuid4().hex[:8]}",
                status=TransactionStatus.active,
            )
        )
    await session.commit()

    result = await aggregate_spending(
        session,
        user=user,
        args={
            "date_from": "2026-01-01",
            "date_to": "2026-12-31",
            "merchants": ["W.ANJUM"],
            "types": ["credit"],
        },
    )
    assert result["grand_total"] == 1460.0
    assert result["filter_types"] == ["credit"]
    assert {row["type"] for row in result["transactions"]} == {"credit"}
    assert sum(row["amount"] for row in result["transactions"]) == 1460.0


def test_finalize_citations_prefers_aggregate_samples() -> None:
    from app.services.agent.orchestrator import _finalize_citations

    aggregate = [
        {"transaction_id": "c1", "amount": 800, "type": "credit"},
        {"transaction_id": "c2", "amount": 660, "type": "credit"},
    ]
    other = [
        {"transaction_id": "d1", "amount": 552, "type": "debit"},
        {"transaction_id": "d2", "amount": 700, "type": "debit"},
    ]
    chosen = _finalize_citations(aggregate, other)
    assert [row["transaction_id"] for row in chosen] == ["c1", "c2"]
    assert _finalize_citations([], other) == other[:8]


@pytest.mark.asyncio
async def test_query_merged_status(session: AsyncSession) -> None:
    user = User(
        firebase_uid=f"uid-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@example.com",
    )
    session.add(user)
    await session.flush()
    session.add(
        Transaction(
            user_id=user.id,
            amount=Decimal("40"),
            currency="PKR",
            type=TransactionType.credit,
            merchant="Ali",
            merchant_normalized="ali",
            category="Reimbursement",
            payment_method="unknown",
            transaction_date=date(2026, 9, 1),
            day="Tuesday",
            dedup_key=f"eval-m-{uuid4().hex[:8]}",
            status=TransactionStatus.merged,
        )
    )
    await session.commit()
    result = await query_transactions(
        session,
        user=user,
        args={
            "date_from": "2026-01-01",
            "date_to": "2026-12-31",
            "statuses": ["merged"],
        },
    )
    assert result["count"] == 1


@pytest.mark.asyncio
async def test_proposal_create_and_settle_atomic(session: AsyncSession) -> None:
    user = User(
        firebase_uid=f"uid-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@example.com",
        default_currency="PKR",
    )
    session.add(user)
    await session.flush()

    proposal = await persist_proposal(
        session,
        user=user,
        steps=[
            {
                "op": "create",
                "ref": "t1",
                "amount": 500,
                "type": "debit",
                "merchant": "Restaurant",
                "category": "Food & Dining",
                "date": "2026-09-09",
            },
            {
                "op": "create",
                "ref": "t3",
                "amount": 200,
                "type": "credit",
                "merchant": "Ali",
                "category": "Reimbursement",
                "date": "2026-09-09",
            },
            {
                "op": "settle",
                "primary_ref": "t1",
                "source_refs": ["t3"],
            },
        ],
        model="test",
    )
    executed = await execute_proposal(
        session, user_id=user.id, proposal=proposal, default_currency="PKR"
    )
    assert executed.status is AgentProposalStatus.executed
    assert executed.result is not None
    assert len(executed.result["created_transaction_ids"]) == 2

    primary_id = executed.result["settle_primary_id"]
    primary = await session.get(Transaction, __import__("uuid").UUID(primary_id))
    assert primary is not None
    assert primary.status is TransactionStatus.settled
    assert float(primary.amount) == 300.0


@pytest.mark.asyncio
async def test_proposal_expires(session: AsyncSession) -> None:
    user = User(
        firebase_uid=f"uid-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@example.com",
    )
    session.add(user)
    await session.flush()
    proposal = AgentProposal(
        user_id=user.id,
        status=AgentProposalStatus.pending_confirmation,
        intent="create",
        steps=[{"op": "create", "ref": "t1", "amount": 1, "type": "debit",
                "merchant": "X", "category": "Other", "date": "2026-09-09"}],
        summary="test",
        expires_at=datetime.now(UTC) - timedelta(minutes=1),
    )
    session.add(proposal)
    await session.commit()
    await session.refresh(proposal)

    with pytest.raises(Exception):
        await execute_proposal(session, user_id=user.id, proposal=proposal)


@pytest.mark.asyncio
async def test_resolve_concepts_no_api() -> None:
    assert await resolve_concepts_from_question(
        question="how much on pharmacy", api_key=""
    ) == ["pharmacy"]
