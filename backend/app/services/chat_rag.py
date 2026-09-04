"""Chat suggestions and grounded ask over analytics tools + RAG."""

from __future__ import annotations

import json
import logging
import re
import uuid
from datetime import date, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.errors import BadRequestError, ServiceUnavailableError
from app.db.models.enums import TransactionStatus
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services import analytics as analytics_service
from app.services.insights_narrative import generate_spend_narrative_text
from app.services.money import money_float
from app.services.rag_retrieval import retrieve
from app.services.rate_limit import enforce_rate_limit
from app.services.spending_signals import detect_signals

logger = logging.getLogger(__name__)

_MAX_SUGGESTIONS = 5
_DEFAULT_ASK_DAYS = 365

_OFF_TOPIC = re.compile(
    r"\b(weather|forecast|stock market|invest(?:ing|ment)?s?|crypto|"
    r"legal advice|lawyer|medical|diagnos|recipe|joke|python code|"
    r"write (?:me )?a (?:poem|essay)|who (?:is|are) the president)\b",
    re.I,
)
_ADVICE = re.compile(
    r"\b(should I (?:buy|sell|invest|quit)|tax advice|legal advice|"
    r"financial advice|what (?:stocks|crypto) should)\b",
    re.I,
)
_NAV = re.compile(
    r"^\s*(?:please\s+)?(?:show|list|filter|find|open)\s+(?:me\s+)?(?:my\s+)?"
    r"(?:transactions?\s+(?:for|at|from)\s+)?(.+?)\s*$",
    re.I,
)
_ANALYTICS_HINT = re.compile(
    r"\b(why|how much|total|spent|spend|compare|increase|jump|trend|"
    r"average|net|received|category|merchant)\b",
    re.I,
)

_ASK_PROMPT = """You answer questions about the user's personal spending in NovaSpend.
Use ONLY facts from the retrieved documents and tool outputs below.
Mention specific merchants and amounts when available.
Do not invent transactions, budgets, or financial advice.
If the data is insufficient, say so.
Never quote SMS or raw message text.
Currency: {currency}. Period: {date_from} to {date_to}.
Question: {question}

Tool outputs (exact numbers):
{tools}

Retrieved documents:
{docs}
"""


async def generate_chat_answer(api_key: str, prompt: str) -> tuple[str, str]:
    return await generate_spend_narrative_text(api_key, prompt)


async def get_suggestions(
    session: AsyncSession,
    *,
    user: User,
    date_from: str,
    date_to: str,
) -> dict:
    analytics_service.parse_range(date_from, date_to)
    signals = await detect_signals(
        session, user=user, date_from=date_from, date_to=date_to
    )
    seen: set[str] = set()
    suggestions: list[dict[str, str]] = []
    for signal in signals:
        question = signal.suggested_question.strip()
        if not question or question in seen:
            continue
        seen.add(question)
        suggestions.append({"question": question, "signal_type": signal.signal_type})
        if len(suggestions) >= _MAX_SUGGESTIONS:
            break
    return {"suggestions": suggestions, "source": "signals"}


async def _active_transaction_count(
    session: AsyncSession, *, user_id: uuid.UUID
) -> int:
    return int(
        (
            await session.execute(
                select(func.count())
                .select_from(Transaction)
                .where(
                    Transaction.user_id == user_id,
                    Transaction.status == TransactionStatus.active,
                )
            )
        ).scalar_one()
        or 0
    )


def _guardrail(question: str) -> None:
    text = question.strip()
    if _OFF_TOPIC.search(text) or _ADVICE.search(text):
        raise BadRequestError(
            "This question is outside spending insights.",
            code="chat_off_topic",
        )


def _navigation_reply(question: str) -> str | None:
    if _ANALYTICS_HINT.search(question):
        return None
    match = _NAV.match(question.strip())
    if match is None:
        return None
    term = re.sub(r"\s+", " ", match.group(1)).strip(" ?.")
    if not term:
        return None
    return (
        f"Use the Activity screen and filter by “{term}”. "
        "Chat answers spending questions; it does not browse your list."
    )


async def _tool_payload(
    session: AsyncSession,
    *,
    user: User,
    date_from: str,
    date_to: str,
) -> dict:
    summary = await analytics_service.get_range_summary(
        session, user=user, date_from=date_from, date_to=date_to
    )
    return {
        "range": {
            "from": summary.get("date_from"),
            "to": summary.get("date_to"),
            "currency": summary.get("currency"),
            "total_debit": summary.get("total_debit"),
            "total_credit": summary.get("total_credit"),
            "net": summary.get("net"),
            "transaction_count": summary.get("transaction_count"),
        },
        "by_category": summary.get("by_category") or {},
        "top_merchants_spent": summary.get("top_merchants_spent") or [],
    }


async def _citations_from_hits(
    session: AsyncSession,
    *,
    user: User,
    hits,
) -> list[dict]:
    citations: list[dict] = []
    seen: set[str] = set()
    for hit in hits:
        if hit.doc_type != "transaction":
            continue
        if hit.ref_id in seen:
            continue
        try:
            tx = await session.get(Transaction, uuid.UUID(hit.ref_id))
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
        seen.add(hit.ref_id)
        if len(citations) >= 8:
            break
    return citations


def _confidence(citation_count: int, tool_count: int) -> str:
    if citation_count >= 3 or (citation_count >= 1 and tool_count > 0):
        return "high"
    if citation_count >= 1 or tool_count > 0:
        return "medium"
    return "low"


def _resolve_range(date_from: str | None, date_to: str | None) -> tuple[str, str, bool]:
    if date_from and date_to:
        analytics_service.parse_range(date_from, date_to)
        return date_from, date_to, True
    if date_from or date_to:
        raise BadRequestError(
            "Provide both `from` and `to`, or neither.",
            code="invalid_date_range",
        )
    end = date.today()
    start = end - timedelta(days=_DEFAULT_ASK_DAYS)
    return start.isoformat(), end.isoformat(), False


async def ask(
    session: AsyncSession,
    *,
    user: User,
    settings: Settings | None,
    question: str,
    date_from: str | None = None,
    date_to: str | None = None,
) -> dict:
    settings = settings or get_settings()
    text = (question or "").strip()
    if not text:
        raise BadRequestError("question is required.", code="question_required")

    await enforce_rate_limit(
        session,
        settings,
        scope="chat_ask",
        key=str(user.id),
        limit=settings.chat_ask_limit_per_user,
    )

    _guardrail(text)

    active = await _active_transaction_count(session, user_id=user.id)
    if active < settings.chat_min_transactions:
        raise BadRequestError(
            "Not enough transactions to answer yet.",
            code="insufficient_data",
        )

    nav = _navigation_reply(text)
    if nav is not None:
        return {
            "answer": nav,
            "citations": [],
            "confidence": "high",
            "source": "navigation",
            "model": None,
        }

    range_from, range_to, scoped = _resolve_range(date_from, date_to)
    tools = await _tool_payload(
        session, user=user, date_from=range_from, date_to=range_to
    )
    hits = await retrieve(
        session,
        user_id=user.id,
        query_text=text,
        limit=10,
        date_from=date.fromisoformat(range_from) if scoped else None,
        date_to=date.fromisoformat(range_to) if scoped else None,
    )
    citations = await _citations_from_hits(session, user=user, hits=hits)
    docs = "\n".join(f"- {hit.content_text}" for hit in hits) or "none"
    prompt = _ASK_PROMPT.format(
        currency=tools["range"].get("currency") or user.default_currency,
        date_from=range_from,
        date_to=range_to,
        question=text,
        tools=json.dumps(tools, default=str),
        docs=docs,
    )

    api_key = settings.gemini_api_key or ""
    if not api_key:
        raise ServiceUnavailableError(
            "Chat is unavailable.",
            code="gemini_unconfigured",
        )
    answer, model = await generate_chat_answer(api_key, prompt)
    if not answer:
        raise ServiceUnavailableError(
            "Chat is unavailable.",
            code="gemini_unavailable",
        )
    tool_count = int(tools["range"].get("transaction_count") or 0)
    return {
        "answer": answer,
        "citations": citations,
        "confidence": _confidence(len(citations), tool_count),
        "source": "gemini",
        "model": model,
    }
