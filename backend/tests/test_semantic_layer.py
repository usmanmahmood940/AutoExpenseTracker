"""Semantic layer unit tests: vocabulary, overrides, question → concepts."""

from __future__ import annotations

from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.merchant_concept import MerchantConceptOverride
from app.db.models.transaction import Transaction
from app.db.models.enums import TransactionStatus, TransactionType
from app.db.models.user import User
from app.db.seeds.concepts import canonicalize_concept, canonicalize_concepts
from app.services.semantic import (
    concepts_from_question_deterministic,
    merchants_for_concepts,
    seed_known_merchant_concepts,
    upsert_merchant_concepts,
)
from app.services.semantic.question_resolver import resolve_concepts_from_question
from decimal import Decimal
from datetime import date


def test_canonicalize_aliases() -> None:
    assert canonicalize_concept("fast food") == "fast_food"
    assert canonicalize_concept("electricity") == "electricity"
    assert canonicalize_concept("not-a-real-tag") is None
    assert canonicalize_concepts(["fast food", "bogus", "fuel"]) == [
        "fast_food",
        "fuel",
    ]


def test_question_electricity_and_fast_food() -> None:
    assert "electricity" in concepts_from_question_deterministic(
        "How much have I spent on electricity?"
    )
    assert "fast_food" in concepts_from_question_deterministic(
        "How much did I spend on fast food this year?"
    )
    assert concepts_from_question_deterministic("show me settled transactions") == []


@pytest.mark.asyncio
async def test_resolve_concepts_cached_deterministic() -> None:
    concepts = await resolve_concepts_from_question(
        question="total spent on fuel", api_key=""
    )
    assert concepts == ["fuel"]


@pytest.mark.asyncio
async def test_merchants_for_concepts_and_overrides(session: AsyncSession) -> None:
    user = User(
        id=uuid4(),
        firebase_uid=f"uid-{uuid4().hex[:8]}",
        email=f"{uuid4().hex[:8]}@example.com",
        default_currency="PKR",
    )
    session.add(user)
    await session.flush()

    await seed_known_merchant_concepts(session)
    await upsert_merchant_concepts(
        session,
        merchant_normalized="company cafeteria",
        concepts=["other"],
        model="seed",
    )

    session.add(
        MerchantConceptOverride(
            user_id=user.id,
            merchant_normalized="company cafeteria",
            concepts=["restaurant", "fast_food"],
        )
    )
    for merchant, key, amount in (
        ("LESCO", "lesco", Decimal("1000")),
        ("KFC", "kfc", Decimal("500")),
        ("Company Cafeteria", "company cafeteria", Decimal("200")),
        ("SNGPL", "sngpl", Decimal("300")),
    ):
        session.add(
            Transaction(
                user_id=user.id,
                amount=amount,
                currency="PKR",
                type=TransactionType.debit,
                merchant=merchant,
                merchant_normalized=key,
                category="Uncategorized",
                payment_method="unknown",
                transaction_date=date(2026, 9, 1),
                day="Tuesday",
                dedup_key=f"test-{key}-{uuid4().hex[:6]}",
                status=TransactionStatus.active,
            )
        )
    await session.commit()

    electricity = await merchants_for_concepts(
        session, user_id=user.id, concepts=["electricity"]
    )
    assert any("LESCO" in m for m in electricity)
    assert not any("SNGPL" in m for m in electricity)

    fast = await merchants_for_concepts(
        session, user_id=user.id, concepts=["fast_food"]
    )
    assert any("KFC" in m for m in fast)
    assert any("Cafeteria" in m for m in fast)
