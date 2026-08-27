"""On-demand Gemini spend narratives, cached per user + date range."""

from __future__ import annotations

import logging

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.models.ai_summary import AiSummary
from app.db.models.user import User
from app.services import analytics as analytics_service
from app.services.gemini import _ENDPOINT, GEMINI_MODELS, _extract_text
from app.services.transactions import parse_iso_date

logger = logging.getLogger(__name__)

_PROMPT = """You write one short paragraph (2-4 sentences) about a person's spending.
Use only the facts given. Mention specific merchants and amounts. Do not invent
transactions, budgets, or advice. No bullet lists. No greeting.
Currency is {currency}. Period: {date_from} to {date_to}.
Spent: {spent}. Received: {received}. Net: {net}. Transactions: {count}.
Top categories (name: amount): {categories}
Top merchants (name: amount): {merchants}
"""


async def generate_spend_narrative_text(api_key: str, prompt: str) -> tuple[str, str]:
    """Returns (narrative, model). Empty narrative if every model fails."""
    last_error = "unknown"
    async with httpx.AsyncClient(timeout=45.0) as client:
        for model_name in GEMINI_MODELS:
            try:
                url = _ENDPOINT.format(model=model_name)
                body = {
                    "contents": [
                        {"role": "user", "parts": [{"text": prompt}]},
                    ],
                    "generationConfig": {"temperature": 0.4},
                }
                response = await client.post(url, params={"key": api_key}, json=body)
                if response.status_code >= 400:
                    raise RuntimeError(f"{response.status_code} {response.text[:400]}")
                text = _extract_text(response.json())
                if text:
                    return text, model_name
            except Exception as exc:
                last_error = str(exc)
                logger.warning("Insights narrative failed on %s: %s", model_name, exc)
    logger.warning("Insights narrative unavailable: %s", last_error)
    return "", ""


def _facts_prompt(summary: dict) -> str:
    categories = summary.get("by_category") or {}
    merchants = summary.get("by_merchant") or {}
    top_categories = sorted(categories.items(), key=lambda item: item[1], reverse=True)[
        :5
    ]
    top_merchants = sorted(merchants.items(), key=lambda item: item[1], reverse=True)[
        :5
    ]
    return _PROMPT.format(
        currency=summary.get("currency") or "PKR",
        date_from=summary.get("date_from") or "",
        date_to=summary.get("date_to") or "",
        spent=summary.get("total_debit") or 0,
        received=summary.get("total_credit") or 0,
        net=summary.get("net") or 0,
        count=summary.get("transaction_count") or 0,
        categories=", ".join(f"{name}: {amount}" for name, amount in top_categories)
        or "none",
        merchants=", ".join(f"{name}: {amount}" for name, amount in top_merchants)
        or "none",
    )


async def get_narrative(
    session: AsyncSession,
    *,
    user: User,
    date_from: str,
    date_to: str,
) -> dict:
    start = parse_iso_date(date_from, "from")
    end = parse_iso_date(date_to, "to")
    cached = (
        await session.execute(
            select(AiSummary).where(
                AiSummary.user_id == user.id,
                AiSummary.date_from == start,
                AiSummary.date_to == end,
            )
        )
    ).scalar_one_or_none()
    if cached is not None:
        return {
            "narrative": cached.narrative,
            "source": "cache",
            "model": cached.model,
        }

    summary = await analytics_service.get_range_summary(
        session, user=user, date_from=date_from, date_to=date_to
    )
    if int(summary.get("transaction_count") or 0) == 0:
        return {"narrative": None, "source": "none", "model": None}

    api_key = get_settings().gemini_api_key or ""
    if not api_key:
        return {"narrative": None, "source": "none", "model": None}

    text, model = await generate_spend_narrative_text(api_key, _facts_prompt(summary))
    if not text:
        return {"narrative": None, "source": "none", "model": None}

    row = AiSummary(
        user_id=user.id,
        date_from=start,
        date_to=end,
        narrative=text,
        model=model,
    )
    session.add(row)
    await session.commit()
    return {"narrative": text, "source": "gemini", "model": model}
