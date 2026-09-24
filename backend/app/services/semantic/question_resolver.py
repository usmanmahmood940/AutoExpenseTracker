"""Resolve natural-language questions into closed concept tags."""

from __future__ import annotations

import json
import logging
from functools import lru_cache

from app.db.seeds.concepts import CONCEPT_VOCABULARY, canonicalize_concepts
from app.services.gemini import _extract_text, generate_content
from app.services.semantic import concepts_from_question_deterministic

logger = logging.getLogger(__name__)

_TIMEOUT = 10.0

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

_PROMPT = """Map the user spending question to concept tags from this vocabulary:
{vocab}

Rules:
- Return only tags from the vocabulary.
- Prefer specific tags (fast_food over restaurant) when the question is specific.
- If the question names a status (settled, merged) or is not about a spending
  topic, return an empty list.
- Do not invent tags.

Question: {question}
"""


@lru_cache(maxsize=256)
def _cache_key(question: str) -> str:
    return " ".join((question or "").lower().split())


_QUESTION_CONCEPT_CACHE: dict[str, tuple[str, ...]] = {}


async def resolve_concepts_from_question(
    *,
    question: str,
    api_key: str = "",
) -> list[str]:
    """Deterministic first; Gemini only when that finds nothing."""
    text = (question or "").strip()
    if not text:
        return []
    key = _cache_key(text)
    cached = _QUESTION_CONCEPT_CACHE.get(key)
    if cached is not None:
        return list(cached)

    deterministic = concepts_from_question_deterministic(text)
    if deterministic:
        _QUESTION_CONCEPT_CACHE[key] = tuple(deterministic)
        return deterministic

    if not api_key:
        return []

    body = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "text": _PROMPT.format(
                            vocab=", ".join(CONCEPT_VOCABULARY),
                            question=text,
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
    try:
        response_payload, _model = await generate_content(
            api_key, body, request_timeout=_TIMEOUT
        )
        payload = json.loads(_extract_text(response_payload) or "{}")
        raw = payload.get("concepts") if isinstance(payload, dict) else None
        if not isinstance(raw, list):
            return []
        clean = canonicalize_concepts([str(item) for item in raw])
        _QUESTION_CONCEPT_CACHE[key] = tuple(clean)
        return clean
    except Exception as exc:
        logger.warning("question concept resolve failed: %s", exc)
        return []
