"""Write-time / offline merchant concept enrichment via Gemini."""

from __future__ import annotations

import json
import logging
from datetime import date

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.db.models.merchant_concept import MerchantConcept
from app.db.models.transaction import Transaction
from app.db.seeds.concepts import CONCEPT_VOCABULARY, canonicalize_concepts
from app.services.gemini import GEMINI_MODELS, _ENDPOINT, _extract_text
from app.services.merchant_key import normalize_merchant_key
from app.services.semantic import (
    ensure_merchant_concepts,
    seed_concepts_for_merchant,
    upsert_merchant_concepts,
)

logger = logging.getLogger(__name__)

_TIMEOUT = 15.0
_MAX_BATCH = 40

_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "concepts": {
            "type": "ARRAY",
            "items": {"type": "STRING"},
        }
    },
    "required": ["concepts"],
}

_PROMPT = """Classify this merchant from a Pakistani bank SMS / expense tracker.

Return only concept tags from this closed vocabulary:
{vocab}

Rules:
- Pick 1–4 tags that clearly apply.
- Prefer specific tags (electricity over utilities) when sure.
- If nothing fits, return ["other"].
- Never invent tags outside the vocabulary.

Merchant: {merchant}
"""


async def classify_merchant_concepts(
    *,
    api_key: str,
    merchant: str,
) -> list[str]:
    """Ask Gemini for closed-vocabulary concepts for one merchant."""
    text = (merchant or "").strip()
    if not api_key or not text:
        return []
    body = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "text": _PROMPT.format(
                            vocab=", ".join(CONCEPT_VOCABULARY),
                            merchant=text,
                        )
                    }
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0.0,
            "responseMimeType": "application/json",
            "responseSchema": _SCHEMA,
        },
    }
    url = _ENDPOINT.format(model=GEMINI_MODELS[0])
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.post(url, params={"key": api_key}, json=body)
            if response.status_code >= 400:
                raise RuntimeError(f"{response.status_code} {response.text[:300]}")
            payload = json.loads(_extract_text(response.json()) or "{}")
            raw = payload.get("concepts") if isinstance(payload, dict) else None
            if not isinstance(raw, list):
                return []
            clean = canonicalize_concepts([str(item) for item in raw])
            return clean or ["other"]
    except Exception as exc:
        logger.warning("merchant concept classify failed: %s", exc)
        return []


async def enrich_merchant_if_needed(
    session: AsyncSession,
    *,
    merchant_normalized: str,
    display_name: str | None = None,
    settings: Settings | None = None,
) -> None:
    """Ensure merchant_concepts has a row; seed first, else Gemini."""
    key = normalize_merchant_key(merchant_normalized)
    if not key:
        return
    existing = await session.get(MerchantConcept, key)
    if existing is not None:
        return
    seeded = await ensure_merchant_concepts(session, merchant_normalized=key)
    if seeded is not None:
        await session.commit()
        return
    settings = settings or get_settings()
    api_key = settings.gemini_api_key or ""
    concepts = await classify_merchant_concepts(
        api_key=api_key, merchant=display_name or key
    )
    if not concepts:
        # Persist empty-ish placeholder as other so we do not re-call forever.
        concepts = ["other"]
    await upsert_merchant_concepts(
        session,
        merchant_normalized=key,
        concepts=concepts,
        model=GEMINI_MODELS[0] if api_key else "fallback",
    )
    await session.commit()


async def backfill_merchant_concepts(
    session: AsyncSession,
    *,
    settings: Settings | None = None,
    limit: int = 200,
) -> dict[str, int]:
    """Classify distinct merchants missing from merchant_concepts."""
    settings = settings or get_settings()
    existing = set(
        (
            await session.execute(select(MerchantConcept.merchant_normalized))
        ).scalars().all()
    )
    rows = (
        await session.execute(
            select(Transaction.merchant_normalized, Transaction.merchant)
            .group_by(Transaction.merchant_normalized, Transaction.merchant)
            .order_by(Transaction.merchant_normalized)
            .limit(limit * 3)
        )
    ).all()
    pending: list[tuple[str, str]] = []
    seen: set[str] = set()
    for key, display in rows:
        norm = normalize_merchant_key(key or "")
        if not norm or norm in existing or norm in seen:
            continue
        seen.add(norm)
        pending.append((norm, display or norm))
        if len(pending) >= limit:
            break

    seeded = 0
    classified = 0
    failed = 0
    for key, display in pending[:_MAX_BATCH]:
        known = seed_concepts_for_merchant(key)
        if known is not None:
            await upsert_merchant_concepts(
                session, merchant_normalized=key, concepts=known, model="seed"
            )
            seeded += 1
            continue
        concepts = await classify_merchant_concepts(
            api_key=settings.gemini_api_key or "", merchant=display
        )
        if not concepts:
            concepts = ["other"]
            failed += 1
        else:
            classified += 1
        await upsert_merchant_concepts(
            session,
            merchant_normalized=key,
            concepts=concepts,
            model=GEMINI_MODELS[0] if settings.gemini_api_key else "fallback",
        )
    await session.commit()
    return {
        "pending": len(pending),
        "seeded": seeded,
        "classified": classified,
        "failed": failed,
        "as_of": date.today().isoformat(),
    }
