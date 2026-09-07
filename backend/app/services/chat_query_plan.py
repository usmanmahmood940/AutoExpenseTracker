"""LLM fallback that maps a question onto merchants the user actually has.

The deterministic alias map in `merchant_keywords` covers the known topics at
zero cost. This planner only runs when that finds nothing, and it picks from a
supplied merchant list rather than free-forming names, so its output is always
grounded in real data. Any failure degrades to an empty plan.
"""

from __future__ import annotations

import json
import logging

import httpx

from app.services.gemini import _ENDPOINT, GEMINI_MODELS, _extract_text

logger = logging.getLogger(__name__)

_TIMEOUT = 12.0
_MAX_MERCHANTS = 80
_MAX_PICKS = 12

_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "merchants": {
            "type": "ARRAY",
            "items": {"type": "STRING"},
        }
    },
    "required": ["merchants"],
}

_PROMPT = """Pick which merchants from the list are relevant to the question.

Rules:
- Choose ONLY from the provided list. Never invent a name.
- Copy names exactly as given.
- Include a merchant only if it clearly belongs to what the question asks about.
- If the question names a spending topic, include every merchant of that topic.
- If nothing is clearly relevant, return an empty list.

Question: {question}

Merchants:
{merchants}
"""


def _pick_valid(raw: str, merchants: list[str]) -> list[str]:
    """Keep only picks that exactly match a supplied merchant, case-insensitive."""
    payload = json.loads(raw)
    picked = payload.get("merchants")
    if not isinstance(picked, list):
        return []
    by_lower = {name.lower(): name for name in merchants}
    out: list[str] = []
    for item in picked:
        if not isinstance(item, str):
            continue
        match = by_lower.get(item.strip().lower())
        if match is not None and match not in out:
            out.append(match)
    return out[:_MAX_PICKS]


async def plan_merchants(
    *,
    api_key: str,
    question: str,
    merchants: list[str],
) -> list[str]:
    """Merchants from `merchants` relevant to `question`; empty on any failure."""
    text = (question or "").strip()
    candidates = [name for name in dict.fromkeys(merchants) if name.strip()]
    if not api_key or not text or not candidates:
        return []
    candidates = candidates[:_MAX_MERCHANTS]
    body = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "text": _PROMPT.format(
                            question=text,
                            merchants="\n".join(f"- {name}" for name in candidates),
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
            return _pick_valid(_extract_text(response.json()), candidates)
    except Exception as exc:
        logger.warning("query planner unavailable: %s", exc)
        return []
