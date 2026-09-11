"""Semantic layer: closed vocabulary ↔ merchants ↔ question concepts."""

from __future__ import annotations

import logging
import re
import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.merchant_concept import MerchantConcept, MerchantConceptOverride
from app.db.models.transaction import Transaction
from app.db.seeds.concepts import (
    CONCEPT_ALIASES,
    CONCEPT_SET,
    CONCEPT_VOCABULARY,
    KNOWN_MERCHANT_CONCEPTS,
    canonicalize_concept,
    canonicalize_concepts,
)
from app.services.merchant_key import normalize_merchant_key

logger = logging.getLogger(__name__)

_TOKEN = re.compile(r"[a-z0-9]+")

# Category display name → concepts (coarse fallback when merchant unknown).
_CATEGORY_CONCEPTS: dict[str, tuple[str, ...]] = {
    "food & dining": ("restaurant", "fast_food"),
    "groceries": ("groceries",),
    "fuel": ("fuel",),
    "transport": ("transportation", "ride_hailing"),
    "shopping": ("shopping",),
    "entertainment": ("entertainment",),
    "bills & utilities": ("utilities", "bills"),
    "health": ("healthcare", "pharmacy"),
    "education": ("education",),
    "travel": ("travel",),
    "subscriptions": ("subscriptions",),
    "rent": ("rent",),
    "insurance": ("insurance",),
}


def _tokens(text: str) -> list[str]:
    return _TOKEN.findall((text or "").lower())


def _has_phrase(haystack: list[str], phrase: str) -> bool:
    needle = _tokens(phrase)
    if not needle or not haystack:
        return False
    span = len(needle)
    for start in range(len(haystack) - span + 1):
        if haystack[start : start + span] == needle:
            return True
    return False


def concepts_from_question_deterministic(question: str) -> list[str]:
    """Map a question onto closed vocabulary without an LLM call."""
    tokens = _tokens(question)
    if not tokens:
        return []
    found: list[str] = []

    def add(concept: str) -> None:
        if concept in CONCEPT_SET and concept not in found:
            found.append(concept)

    # Multi-word aliases first (fast food, light bill, …).
    for alias, concept in sorted(
        CONCEPT_ALIASES.items(), key=lambda item: -len(item[0])
    ):
        if _has_phrase(tokens, alias):
            add(concept)

    for concept in CONCEPT_VOCABULARY:
        if _has_phrase(tokens, concept.replace("_", " ")) or _has_phrase(
            tokens, concept
        ):
            add(concept)

    return found


def seed_concepts_for_merchant(merchant_normalized: str) -> list[str] | None:
    """Return bootstrap concepts when the merchant is in the known map."""
    key = normalize_merchant_key(merchant_normalized)
    if key in KNOWN_MERCHANT_CONCEPTS:
        return list(KNOWN_MERCHANT_CONCEPTS[key])
    # Prefix / contained known keys (e.g. "lesco bill payment").
    tokens = _tokens(key)
    for known, concepts in KNOWN_MERCHANT_CONCEPTS.items():
        if _has_phrase(tokens, known):
            return list(concepts)
    return None


async def upsert_merchant_concepts(
    session: AsyncSession,
    *,
    merchant_normalized: str,
    concepts: list[str],
    model: str,
) -> MerchantConcept:
    key = normalize_merchant_key(merchant_normalized)
    clean = canonicalize_concepts(concepts)
    now = datetime.now(UTC)
    stmt = (
        pg_insert(MerchantConcept)
        .values(
            merchant_normalized=key,
            concepts=clean,
            model=model,
            resolved_at=now,
        )
        .on_conflict_do_update(
            index_elements=[MerchantConcept.merchant_normalized],
            set_={
                "concepts": clean,
                "model": model,
                "resolved_at": now,
            },
        )
        .returning(MerchantConcept)
    )
    row = (await session.execute(stmt)).scalar_one()
    return row


async def seed_known_merchant_concepts(session: AsyncSession) -> int:
    """Upsert bootstrap rows for KNOWN_MERCHANT_CONCEPTS. Idempotent."""
    count = 0
    for key, concepts in KNOWN_MERCHANT_CONCEPTS.items():
        await upsert_merchant_concepts(
            session,
            merchant_normalized=key,
            concepts=list(concepts),
            model="seed",
        )
        count += 1
    return count


async def ensure_merchant_concepts(
    session: AsyncSession,
    *,
    merchant_normalized: str,
) -> MerchantConcept | None:
    """Return existing row, or seed from known map. Does not call Gemini."""
    key = normalize_merchant_key(merchant_normalized)
    if not key:
        return None
    existing = await session.get(MerchantConcept, key)
    if existing is not None:
        return existing
    seeded = seed_concepts_for_merchant(key)
    if seeded is None:
        return None
    return await upsert_merchant_concepts(
        session, merchant_normalized=key, concepts=seeded, model="seed"
    )


async def get_merchant_concepts_map(
    session: AsyncSession,
    *,
    user_id: uuid.UUID | None,
    merchant_keys: list[str],
) -> dict[str, list[str]]:
    """Effective concepts per merchant: override → global."""
    keys = [normalize_merchant_key(k) for k in merchant_keys if k]
    keys = list(dict.fromkeys(keys))
    if not keys:
        return {}
    rows = (
        await session.execute(
            select(MerchantConcept).where(MerchantConcept.merchant_normalized.in_(keys))
        )
    ).scalars().all()
    out: dict[str, list[str]] = {
        row.merchant_normalized: list(row.concepts or []) for row in rows
    }
    if user_id is not None:
        overrides = (
            await session.execute(
                select(MerchantConceptOverride).where(
                    MerchantConceptOverride.user_id == user_id,
                    MerchantConceptOverride.merchant_normalized.in_(keys),
                )
            )
        ).scalars().all()
        for row in overrides:
            out[row.merchant_normalized] = list(row.concepts or [])
    return out


async def merchants_for_concepts(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    concepts: list[str],
    date_from=None,
    date_to=None,
) -> list[str]:
    """Distinct merchants the user has that match any of `concepts`."""
    clean = canonicalize_concepts(concepts)
    if not clean:
        return []

    # User overrides that include any requested concept.
    override_rows = (
        await session.execute(
            select(MerchantConceptOverride.merchant_normalized).where(
                MerchantConceptOverride.user_id == user_id,
                MerchantConceptOverride.concepts.overlap(clean),
            )
        )
    ).all()
    override_keys = {row[0] for row in override_rows}

    global_rows = (
        await session.execute(
            select(MerchantConcept.merchant_normalized).where(
                MerchantConcept.concepts.overlap(clean)
            )
        )
    ).all()
    global_keys = {row[0] for row in global_rows}

    # Merchants with an override that does NOT include the concept must be
    # excluded even if the global row matches.
    blocking = (
        await session.execute(
            select(MerchantConceptOverride.merchant_normalized).where(
                MerchantConceptOverride.user_id == user_id,
                ~MerchantConceptOverride.concepts.overlap(clean),
            )
        )
    ).all()
    blocked = {row[0] for row in blocking}

    candidate_keys = (override_keys | global_keys) - blocked
    if not candidate_keys:
        return []

    stmt = (
        select(Transaction.merchant)
        .where(
            Transaction.user_id == user_id,
            Transaction.merchant_normalized.in_(candidate_keys),
        )
        .group_by(Transaction.merchant)
    )
    if date_from is not None:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to is not None:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    rows = (await session.execute(stmt)).all()
    return [row[0] for row in rows if row[0]]


def concepts_from_category(category: str) -> list[str]:
    key = (category or "").strip().lower()
    return list(_CATEGORY_CONCEPTS.get(key, ()))


__all__ = [
    "CONCEPT_SET",
    "CONCEPT_VOCABULARY",
    "canonicalize_concept",
    "canonicalize_concepts",
    "concepts_from_category",
    "concepts_from_question_deterministic",
    "ensure_merchant_concepts",
    "get_merchant_concepts_map",
    "merchants_for_concepts",
    "seed_concepts_for_merchant",
    "seed_known_merchant_concepts",
    "upsert_merchant_concepts",
]
