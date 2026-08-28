"""On-demand Gemini spend narratives, cached per user + date range."""

from __future__ import annotations

import logging
from datetime import UTC, date, datetime

import httpx
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
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


def _parse_source_updated_at(raw: str | None) -> datetime | None:
    if not raw:
        return None
    parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def _cache_is_valid(cached: AiSummary, summary: dict) -> bool:
    expected_count = int(summary.get("transaction_count") or 0)
    if cached.transaction_count != expected_count:
        return False
    summary_updated = _parse_source_updated_at(summary.get("source_updated_at"))
    cached_updated = cached.source_updated_at
    if summary_updated is None and cached_updated is None:
        return True
    if summary_updated is None or cached_updated is None:
        return False
    return summary_updated == cached_updated.astimezone(UTC)


async def _get_cached_narrative(
    session: AsyncSession,
    *,
    user: User,
    date_from: date,
    date_to: date,
) -> AiSummary | None:
    return (
        await session.execute(
            select(AiSummary).where(
                AiSummary.user_id == user.id,
                AiSummary.date_from == date_from,
                AiSummary.date_to == date_to,
            )
        )
    ).scalar_one_or_none()


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


def _apply_narrative_row(
    row: AiSummary,
    *,
    narrative: str,
    model: str,
    summary: dict,
) -> None:
    row.narrative = narrative
    row.model = model
    row.transaction_count = int(summary.get("transaction_count") or 0)
    row.source_updated_at = _parse_source_updated_at(summary.get("source_updated_at"))
    row.generated_at = datetime.now(UTC)


async def get_narrative(
    session: AsyncSession,
    *,
    user: User,
    date_from: str,
    date_to: str,
) -> dict:
    start = parse_iso_date(date_from, "from")
    end = parse_iso_date(date_to, "to")

    summary = await analytics_service.get_range_summary(
        session, user=user, date_from=date_from, date_to=date_to
    )
    if int(summary.get("transaction_count") or 0) == 0:
        return {"narrative": None, "source": "none", "model": None}

    cached = await _get_cached_narrative(
        session, user=user, date_from=start, date_to=end
    )
    if cached is not None and _cache_is_valid(cached, summary):
        return {
            "narrative": cached.narrative,
            "source": "cache",
            "model": cached.model,
        }

    api_key = get_settings().gemini_api_key or ""
    if not api_key:
        return {"narrative": None, "source": "none", "model": None}

    text, model = await generate_spend_narrative_text(api_key, _facts_prompt(summary))
    if not text:
        return {"narrative": None, "source": "none", "model": None}

    if cached is not None:
        _apply_narrative_row(cached, narrative=text, model=model, summary=summary)
    else:
        row = AiSummary(
            user_id=user.id,
            date_from=start,
            date_to=end,
            narrative=text,
            model=model,
            transaction_count=int(summary.get("transaction_count") or 0),
            source_updated_at=_parse_source_updated_at(
                summary.get("source_updated_at")
            ),
        )
        session.add(row)

    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        cached = await _get_cached_narrative(
            session, user=user, date_from=start, date_to=end
        )
        if cached is not None and _cache_is_valid(cached, summary):
            return {
                "narrative": cached.narrative,
                "source": "cache",
                "model": cached.model,
            }
        raise
    return {"narrative": text, "source": "gemini", "model": model}
