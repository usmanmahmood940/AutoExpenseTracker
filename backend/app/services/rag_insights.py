"""Cached Gemini smart insight cards from spending signals + RAG context."""

from __future__ import annotations

import json
import logging
from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.models.enums import TransactionStatus
from app.db.models.rag_insight_cache import RagInsightCache
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services import analytics as analytics_service
from app.services.insights_narrative import generate_spend_narrative_text
from app.services.money import money_float
from app.services.rag_retrieval import retrieve
from app.services.spending_signals import SpendingSignal, detect_signals
from app.services.transactions import parse_iso_date

logger = logging.getLogger(__name__)

_MAX_CARDS = 4
_MIN_CARDS = 2

_CARD_PROMPT = """You write 2-3 sentences about one spending pattern for this person.
Use only the facts given. Mention specific merchants and amounts when available.
Do not invent transactions, budgets, or advice. No bullet lists. No greeting.
Currency is {currency}. Period: {date_from} to {date_to}.
Signal: {signal_type}.
Signal facts: {params}
Range totals — spent: {spent}, received: {received}, net: {net}, transactions: {count}.
Supporting documents:
{docs}
"""


def _parse_source_updated_at(raw: str | None) -> datetime | None:
    if not raw:
        return None
    parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def _cache_is_valid(cached: RagInsightCache, summary: dict) -> bool:
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


async def _get_cached(
    session: AsyncSession,
    *,
    user: User,
    date_from: date,
    date_to: date,
) -> RagInsightCache | None:
    return (
        await session.execute(
            select(RagInsightCache).where(
                RagInsightCache.user_id == user.id,
                RagInsightCache.date_from == date_from,
                RagInsightCache.date_to == date_to,
            )
        )
    ).scalar_one_or_none()


def _title_for(signal: SpendingSignal) -> str:
    params = signal.params
    if signal.signal_type == "category_spike":
        return f"{params.get('category', 'Spending')} up {params.get('percent', 0)}%"
    if signal.signal_type == "new_recurring":
        return f"New recurring: {params.get('merchant', 'merchant')}"
    if signal.signal_type == "merchant_concentration":
        return f"Heavy spend at {params.get('merchant', 'one merchant')}"
    if signal.signal_type == "weekend_skew":
        return "Weekend spending is high"
    if signal.signal_type == "large_one_off":
        return f"Large payment at {params.get('merchant', 'a merchant')}"
    if signal.signal_type == "net_negative_swing":
        return "Net cash flow worsened"
    return signal.signal_type.replace("_", " ").title()


async def generate_card_text(api_key: str, prompt: str) -> tuple[str, str]:
    return await generate_spend_narrative_text(api_key, prompt)


async def _citations_for_signal(
    session: AsyncSession,
    *,
    user: User,
    signal: SpendingSignal,
    date_from: date,
    date_to: date,
) -> list[dict[str, Any]]:
    citations: list[dict[str, Any]] = []
    tx_id = signal.params.get("transaction_id")
    if tx_id:
        try:
            tx = await session.get(Transaction, UUID(str(tx_id)))
        except ValueError:
            tx = None
        if (
            tx is not None
            and tx.user_id == user.id
            and tx.status != TransactionStatus.deleted
        ):
            citations.append(
                {
                    "transaction_id": str(tx.id),
                    "date": tx.transaction_date.isoformat(),
                    "amount": money_float(tx.amount),
                    "merchant": tx.merchant,
                    "category": tx.category,
                }
            )
    hits = await retrieve(
        session,
        user_id=user.id,
        query_text=signal.suggested_question,
        limit=5,
        date_from=date_from,
        date_to=date_to,
    )
    seen = {item["transaction_id"] for item in citations}
    for hit in hits:
        if hit.doc_type != "transaction":
            continue
        if hit.ref_id in seen:
            continue
        try:
            tx = await session.get(Transaction, UUID(hit.ref_id))
        except ValueError:
            continue
        if (
            tx is None
            or tx.user_id != user.id
            or tx.status == TransactionStatus.deleted
        ):
            continue
        citations.append(
            {
                "transaction_id": str(tx.id),
                "date": tx.transaction_date.isoformat(),
                "amount": money_float(tx.amount),
                "merchant": tx.merchant,
                "category": tx.category,
            }
        )
        seen.add(str(tx.id))
        if len(citations) >= 3:
            break
    return citations


async def _build_cards(
    session: AsyncSession,
    *,
    user: User,
    summary: dict,
    date_from: date,
    date_to: date,
    signals: list[SpendingSignal],
    api_key: str,
) -> tuple[list[dict[str, Any]], str]:
    cards: list[dict[str, Any]] = []
    model = ""
    chosen = signals[:_MAX_CARDS]
    if len(chosen) < _MIN_CARDS:
        chosen = signals
    docs_by_signal: dict[str, str] = {}
    for signal in chosen:
        hits = await retrieve(
            session,
            user_id=user.id,
            query_text=signal.suggested_question,
            limit=8,
            date_from=date_from,
            date_to=date_to,
        )
        docs_by_signal[signal.signal_type + signal.suggested_question] = (
            "\n".join(f"- {hit.content_text}" for hit in hits) or "none"
        )
        prompt = _CARD_PROMPT.format(
            currency=summary.get("currency") or user.default_currency,
            date_from=date_from.isoformat(),
            date_to=date_to.isoformat(),
            signal_type=signal.signal_type,
            params=json.dumps(signal.params, default=str),
            spent=summary.get("total_debit") or 0,
            received=summary.get("total_credit") or 0,
            net=summary.get("net") or 0,
            count=summary.get("transaction_count") or 0,
            docs=docs_by_signal[signal.signal_type + signal.suggested_question],
        )
        text, used_model = await generate_card_text(api_key, prompt)
        if not text:
            continue
        model = used_model or model
        cards.append(
            {
                "title": _title_for(signal),
                "body": text,
                "signal_type": signal.signal_type,
                "citations": await _citations_for_signal(
                    session,
                    user=user,
                    signal=signal,
                    date_from=date_from,
                    date_to=date_to,
                ),
            }
        )
    return cards, model


def _apply_cache_row(
    row: RagInsightCache,
    *,
    cards: list[dict[str, Any]],
    model: str,
    summary: dict,
) -> None:
    row.cards = cards
    row.model = model
    row.transaction_count = int(summary.get("transaction_count") or 0)
    row.source_updated_at = _parse_source_updated_at(summary.get("source_updated_at"))
    row.generated_at = datetime.now(UTC)


async def get_smart_cards(
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
        return {"cards": [], "source": "none", "model": None}

    cached = await _get_cached(session, user=user, date_from=start, date_to=end)
    if cached is not None and _cache_is_valid(cached, summary):
        return {"cards": cached.cards, "source": "cache", "model": cached.model}

    api_key = get_settings().gemini_api_key or ""
    if not api_key:
        return {"cards": [], "source": "none", "model": None}

    signals = await detect_signals(
        session, user=user, date_from=date_from, date_to=date_to
    )
    if not signals:
        return {"cards": [], "source": "none", "model": None}

    cards, model = await _build_cards(
        session,
        user=user,
        summary=summary,
        date_from=start,
        date_to=end,
        signals=signals,
        api_key=api_key,
    )
    if not cards:
        return {"cards": [], "source": "none", "model": None}

    if cached is not None:
        _apply_cache_row(cached, cards=cards, model=model, summary=summary)
    else:
        session.add(
            RagInsightCache(
                user_id=user.id,
                date_from=start,
                date_to=end,
                cards=cards,
                model=model,
                transaction_count=int(summary.get("transaction_count") or 0),
                source_updated_at=_parse_source_updated_at(
                    summary.get("source_updated_at")
                ),
            )
        )
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        cached = await _get_cached(session, user=user, date_from=start, date_to=end)
        if cached is not None and _cache_is_valid(cached, summary):
            return {"cards": cached.cards, "source": "cache", "model": cached.model}
        raise
    return {"cards": cards, "source": "gemini", "model": model}
