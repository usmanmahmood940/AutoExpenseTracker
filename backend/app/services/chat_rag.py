"""Chat suggestions and grounded ask over analytics tools + RAG."""

from __future__ import annotations

import json
import logging
import re
import uuid
from datetime import date, timedelta

from sqlalchemy import Date, and_, cast, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.errors import BadRequestError, ServiceUnavailableError
from app.db.models.enums import TransactionStatus, TransactionType
from app.db.models.transaction import Transaction
from app.db.models.user import User
from app.services import analytics as analytics_service
from app.services.chat_query_plan import plan_merchants
from app.services.chat_question_range import resolve_ask_window
from app.services.insights_narrative import generate_spend_narrative_text
from app.services.merchant_keywords import (
    merchant_belongs_to_topics,
    terms_from_question,
    topics_from_question,
)
from app.services.money import as_money, money_float
from app.services.rag_documents import build_transaction_doc
from app.services.rag_retrieval import RagHit, retrieve, retrieve_lexical
from app.services.rate_limit import enforce_rate_limit
from app.services.spending_signals import detect_signals
from app.services.sql_like import contains_pattern
from app.services.transactions import SUMMABLE_STATUSES

logger = logging.getLogger(__name__)

_MAX_SUGGESTIONS = 5
_DEFAULT_ASK_DAYS = 365
_SHORT_WINDOW_DAYS = 3
_LONG_WINDOW_DAYS = 45
_TX_RETRIEVE_LIMIT = 8
_LEXICAL_RETRIEVE_LIMIT = 6
_MERCHANT_RETRIEVE_LIMIT = 3
_PERIOD_RETRIEVE_LIMIT = 3
_LARGEST_DEBITS = 5
_SHORT_WINDOW_TX_LIMIT = 40
_HISTORY_TURNS = 3
_HISTORY_CHARS = 500
_MATCHED_TOTALS_LIMIT = 20
_PLANNER_MERCHANT_POOL = 80

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
    r"average|net|received|category|merchant|"
    r"settled?|unsettled?|merged?|reimburse(?:ment|d)?)\b",
    re.I,
)
_SETTLEMENT_HINT = re.compile(
    r"\b(settled?|unsettled?|merged?|reimburse(?:ment|d)?)\b",
    re.I,
)

_ASK_PROMPT = """You answer questions about the user's personal spending in NovaSpend.
Use ONLY facts from the retrieved documents and tool outputs below.
Mention specific merchants and amounts when available.
Do not invent transactions, budgets, or financial advice.
If the data is insufficient, say so.
Never quote SMS or raw message text.
Today is {today} ({weekday}).
Selected period: {ui_from} to {ui_to}.
Answer using this window: {eff_from} to {eff_to}.
Relative words like today, yesterday, and this week refer to the calendar dates above.
Do not say there is no data for today if tools or documents include {today}.
Currency: {currency}.
Tool outputs are exact SQL aggregates over the whole window; trust them.
When matched_totals is present it is the complete total for what was asked,
covering every matching transaction, so quote its numbers directly.
Only mention merchants that appear in matched_totals.by_merchant.
Retrieved documents are only examples for context. They are a partial sample,
so never add them up and never treat them as a complete list.
When settled_transactions is present it is the complete list of settlements
in the window. Merged source rows are absorbed into that primary and are not
separate spends. Do not say there are no settlements if the list is non-empty.
{history_block}Question: {question}

Tool outputs (exact numbers):
{tools}

Retrieved documents (examples only, do not sum):
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
                    Transaction.status.in_(SUMMABLE_STATUSES),
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


def _is_settlement_question(question: str) -> bool:
    return bool(_SETTLEMENT_HINT.search(question or ""))


def _navigation_reply(question: str) -> tuple[str, str] | None:
    if _ANALYTICS_HINT.search(question) or _is_settlement_question(question):
        return None
    match = _NAV.match(question.strip())
    if match is None:
        return None
    term = re.sub(r"\s+", " ", match.group(1)).strip(" ?.")
    if not term:
        return None
    answer = (
        f"Use the Activity screen and filter by “{term}”. "
        "Chat answers spending questions; it does not browse your list."
    )
    return answer, term


def _tx_filters(user_id: uuid.UUID, start: date, end: date):
    return (
        Transaction.user_id == user_id,
        Transaction.status.in_(SUMMABLE_STATUSES),
        Transaction.transaction_date >= start,
        Transaction.transaction_date <= end,
    )


def _citation_from_tx(tx: Transaction) -> dict:
    return {
        "transaction_id": str(tx.id),
        "date": tx.transaction_date.isoformat(),
        "amount": money_float(tx.amount),
        "merchant": tx.merchant,
        "category": tx.category,
        "status": tx.status.value if hasattr(tx.status, "value") else str(tx.status),
    }


def _hit_from_tx(tx: Transaction) -> RagHit:
    return RagHit(
        id=tx.id,
        doc_type="transaction",
        ref_id=str(tx.id),
        content_text=build_transaction_doc(tx),
        distance=0.0,
        period_from=tx.transaction_date,
        period_to=tx.transaction_date,
    )


async def _largest_debits(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    limit: int = _LARGEST_DEBITS,
) -> list[Transaction]:
    result = await session.execute(
        select(Transaction)
        .where(
            *_tx_filters(user.id, start, end),
            Transaction.type == TransactionType.debit,
        )
        .order_by(Transaction.amount.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


def _term_clause(terms: list[str]):
    """Match a term against the merchant only.

    Category is too coarse (one `Bills & Utilities` slug covers gas and
    electricity) and must never be part of a `%LIKE%` expansion.
    """
    clauses = []
    for term in terms:
        pattern = contains_pattern(term)
        clauses.extend(
            [
                Transaction.merchant.ilike(pattern, escape="\\"),
                Transaction.merchant_normalized.ilike(pattern, escape="\\"),
            ]
        )
    return or_(*clauses)


async def _matched_totals(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    terms: list[str],
    question: str = "",
) -> dict:
    """Exact per-merchant debit totals for every row matching `terms`.

    Uncapped by design: this is what lets "how much on electricity" answer
    correctly even when the merchant is nowhere near the top-5 by spend.
    Merchants that only matched a generic substring (CURSOR AI POWER vs
    `power`) are dropped when the question maps to a known topic.
    """
    rows = (
        await session.execute(
            select(
                Transaction.merchant,
                func.coalesce(func.sum(Transaction.amount), 0),
                func.count(Transaction.id),
                func.min(Transaction.transaction_date),
                func.max(Transaction.transaction_date),
            )
            .where(
                *_tx_filters(user.id, start, end),
                Transaction.type == TransactionType.debit,
                _term_clause(terms),
            )
            .group_by(Transaction.merchant)
            .order_by(func.coalesce(func.sum(Transaction.amount), 0).desc())
            .limit(_MATCHED_TOTALS_LIMIT)
        )
    ).all()
    topics = topics_from_question(question)
    by_merchant = [
        {
            "merchant": merchant,
            "total_debit": money_float(as_money(total)),
            "transaction_count": int(count),
            "first_date": first.isoformat() if first else None,
            "last_date": last.isoformat() if last else None,
        }
        for merchant, total, count, first, last in rows
        if merchant_belongs_to_topics(merchant, topics)
    ]
    grand = as_money(sum(as_money(item["total_debit"]) for item in by_merchant))
    return {
        "terms": terms,
        "topics": topics,
        "grand_total_debit": money_float(grand),
        "transaction_count": sum(item["transaction_count"] for item in by_merchant),
        "by_merchant": by_merchant,
    }


async def _matched_transactions(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    terms: list[str],
    question: str = "",
    limit: int = 8,
) -> list[Transaction]:
    """Individual rows behind matched_totals, newest first.

    These are the only citations the UI should show for a topic question.
    """
    topics = topics_from_question(question)
    result = await session.execute(
        select(Transaction)
        .where(
            *_tx_filters(user.id, start, end),
            Transaction.type == TransactionType.debit,
            _term_clause(terms),
        )
        .order_by(Transaction.transaction_date.desc(), Transaction.amount.desc())
        .limit(limit * 3)
    )
    out: list[Transaction] = []
    for tx in result.scalars():
        if not merchant_belongs_to_topics(tx.merchant, topics):
            continue
        out.append(tx)
        if len(out) >= limit:
            break
    return out


async def _settled_transactions(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    limit: int = 20,
) -> list[Transaction]:
    """Settled primaries in the window. Merged sources are not listed.

    Include rows whose original spend date is outside the selected range when
    they were settled (updated) inside it — "I just settled X" is about the
    settlement, not the receipt date.
    """
    in_window = or_(
        and_(
            Transaction.transaction_date >= start,
            Transaction.transaction_date <= end,
        ),
        and_(
            cast(Transaction.updated_at, Date) >= start,
            cast(Transaction.updated_at, Date) <= end,
        ),
    )
    result = await session.execute(
        select(Transaction)
        .where(
            Transaction.user_id == user.id,
            Transaction.status == TransactionStatus.settled,
            in_window,
        )
        .order_by(
            Transaction.updated_at.desc(),
            Transaction.transaction_date.desc(),
            Transaction.amount.desc(),
        )
        .limit(limit)
    )
    return list(result.scalars().all())


async def _merchant_pool(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    limit: int = _PLANNER_MERCHANT_POOL,
) -> list[str]:
    """Distinct merchants in the window, biggest spenders first."""
    rows = (
        await session.execute(
            select(Transaction.merchant)
            .where(*_tx_filters(user.id, start, end))
            .group_by(Transaction.merchant)
            .order_by(func.coalesce(func.sum(Transaction.amount), 0).desc())
            .limit(limit)
        )
    ).all()
    return [row[0] for row in rows if row[0]]


async def _resolve_terms(
    session: AsyncSession,
    *,
    user: User,
    question: str,
    start: date,
    end: date,
    api_key: str,
) -> list[str]:
    """Search terms for a question: deterministic aliases, then LLM fallback."""
    terms = terms_from_question(question)
    if terms:
        return terms
    # Status questions are answered by SQL, not merchant guessing. "settle"
    # matching analytics would otherwise send the planner looking for Cafe.
    if _is_settlement_question(question):
        return []
    if not api_key or not _ANALYTICS_HINT.search(question):
        return []
    pool = await _merchant_pool(session, user=user, start=start, end=end)
    if not pool:
        return []
    try:
        return await plan_merchants(api_key=api_key, question=question, merchants=pool)
    except Exception:
        # The planner is an optimisation; never let it fail the answer.
        logger.warning("query planner failed", exc_info=True)
        return []


async def _day_totals(
    session: AsyncSession,
    *,
    user: User,
    day: date,
) -> dict:
    rows = (
        await session.execute(
            select(
                Transaction.type,
                func.coalesce(func.sum(Transaction.amount), 0),
                func.count(Transaction.id),
            )
            .where(*_tx_filters(user.id, day, day))
            .group_by(Transaction.type)
        )
    ).all()
    debit = as_money(0)
    credit = as_money(0)
    count = 0
    for tx_type, amount, visits in rows:
        count += int(visits)
        money = as_money(amount)
        if tx_type == TransactionType.debit:
            debit = money
        elif tx_type == TransactionType.credit:
            credit = money
    return {
        "date": day.isoformat(),
        "total_debit": money_float(debit),
        "total_credit": money_float(credit),
        "transaction_count": count,
    }


async def _transactions_in_range(
    session: AsyncSession,
    *,
    user: User,
    start: date,
    end: date,
    limit: int = _SHORT_WINDOW_TX_LIMIT,
) -> list[Transaction]:
    result = await session.execute(
        select(Transaction)
        .where(*_tx_filters(user.id, start, end))
        .order_by(Transaction.amount.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def _tool_payload(
    session: AsyncSession,
    *,
    user: User,
    date_from: str,
    date_to: str,
    start: date,
    end: date,
    terms: list[str] | None = None,
    question: str = "",
) -> dict:
    summary = await analytics_service.get_range_summary(
        session, user=user, date_from=date_from, date_to=date_to
    )
    largest = await _largest_debits(session, user=user, start=start, end=end)
    payload = {
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
        "largest_debits": [_citation_from_tx(tx) for tx in largest],
    }
    if terms:
        payload["matched_totals"] = await _matched_totals(
            session,
            user=user,
            start=start,
            end=end,
            terms=terms,
            question=question,
        )
        payload["matched_transactions"] = [
            _citation_from_tx(tx)
            for tx in await _matched_transactions(
                session, user=user, start=start, end=end, terms=terms, question=question
            )
        ]
    if _is_settlement_question(question):
        payload["settled_transactions"] = [
            _citation_from_tx(tx)
            for tx in await _settled_transactions(
                session, user=user, start=start, end=end
            )
        ]
    if start == end:
        payload["day_totals"] = await _day_totals(session, user=user, day=start)
    return payload


def _dedupe_hits(*groups: list[RagHit]) -> list[RagHit]:
    """Concatenate hit groups, keeping the first occurrence of each document."""
    out: list[RagHit] = []
    seen: set[tuple[str, str]] = set()
    for group in groups:
        for hit in group:
            key = (hit.doc_type, hit.ref_id)
            if key in seen:
                continue
            seen.add(key)
            out.append(hit)
    return out


async def _ask_docs(
    session: AsyncSession,
    *,
    user: User,
    question: str,
    start: date,
    end: date,
    terms: list[str] | None = None,
) -> list[RagHit]:
    lexical_terms = list(terms or [])
    if _is_settlement_question(question) and "settled" not in lexical_terms:
        lexical_terms.append("settled")
    span = (end - start).days + 1
    if span <= _SHORT_WINDOW_DAYS:
        txs = await _transactions_in_range(session, user=user, start=start, end=end)
        return [_hit_from_tx(tx) for tx in txs]

    # Lexical first: an explicitly named merchant must never be missed because
    # cosine ranked a sibling utility higher.
    lexical = await retrieve_lexical(
        session,
        user_id=user.id,
        terms=lexical_terms,
        limit=_LEXICAL_RETRIEVE_LIMIT,
        doc_types=["transaction"],
        date_from=start,
        date_to=end,
        strict_period=True,
    )
    vector = await retrieve(
        session,
        user_id=user.id,
        query_text=question,
        limit=_TX_RETRIEVE_LIMIT,
        doc_types=["transaction"],
        date_from=start,
        date_to=end,
        strict_period=True,
    )
    groups = [lexical, vector]
    if terms:
        # Merchant rollups are lifetime totals with no period, so they stay
        # eligible under strict period filtering.
        groups.append(
            await retrieve_lexical(
                session,
                user_id=user.id,
                terms=terms,
                limit=_MERCHANT_RETRIEVE_LIMIT,
                doc_types=["merchant"],
                date_from=start,
                date_to=end,
                strict_period=True,
                periodless_doc_types=["merchant"],
            )
        )
    if span > _LONG_WINDOW_DAYS:
        groups.append(
            await retrieve(
                session,
                user_id=user.id,
                query_text=question,
                limit=_PERIOD_RETRIEVE_LIMIT,
                doc_types=["period"],
                date_from=start,
                date_to=end,
                strict_period=True,
            )
        )
    return _filter_hits(_dedupe_hits(*groups), lexical_terms, question)


def _filter_hits(hits: list[RagHit], terms: list[str], question: str) -> list[RagHit]:
    """Drop retrieved docs that do not belong to the question's topic.

    Cosine search still returns ATM / transfers as "similar spend". Those must
    not reach the prompt or the Related transactions list.
    """
    if not terms:
        return hits
    topics = topics_from_question(question)
    needles = [term.lower() for term in terms]
    out: list[RagHit] = []
    for hit in hits:
        text = (hit.content_text or "").lower()
        if not any(needle in text for needle in needles):
            continue
        if hit.doc_type == "merchant" and topics:
            name = (hit.ref_id or "").replace("_", " ")
            if not merchant_belongs_to_topics(name, topics):
                continue
        out.append(hit)
    return out


async def _citations_from_hits(
    session: AsyncSession,
    *,
    user: User,
    hits: list[RagHit],
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
        if tx is None or tx.user_id != user.id or tx.status not in SUMMABLE_STATUSES:
            continue
        citations.append(_citation_from_tx(tx))
        seen.add(hit.ref_id)
        if len(citations) >= 8:
            break
    return citations


def _merge_citations(*groups: list[dict], limit: int = 8) -> list[dict]:
    out: list[dict] = []
    seen: set[str] = set()
    for group in groups:
        for item in group:
            tid = str(item.get("transaction_id") or "")
            if not tid or tid in seen:
                continue
            seen.add(tid)
            out.append(item)
            if len(out) >= limit:
                return out
    return out


def _confidence(citation_count: int, tool_count: int) -> str:
    if citation_count >= 3 or (citation_count >= 1 and tool_count > 0):
        return "high"
    if citation_count >= 1 or tool_count > 0:
        return "medium"
    return "low"


def _resolve_range(date_from: str | None, date_to: str | None) -> tuple[str, str]:
    if date_from and date_to:
        analytics_service.parse_range(date_from, date_to)
        return date_from, date_to
    if date_from or date_to:
        raise BadRequestError(
            "Provide both `from` and `to`, or neither.",
            code="invalid_date_range",
        )
    end = date.today()
    start = end - timedelta(days=_DEFAULT_ASK_DAYS)
    return start.isoformat(), end.isoformat()


def _normalize_history(history: list[dict] | None) -> list[dict[str, str]]:
    if not history:
        return []
    out: list[dict[str, str]] = []
    for item in history[:_HISTORY_TURNS]:
        question = str(item.get("question") or "").strip()[:_HISTORY_CHARS]
        answer = str(item.get("answer") or "").strip()[:_HISTORY_CHARS]
        if question and answer:
            out.append({"question": question, "answer": answer})
    return out


def _history_block(history: list[dict[str, str]]) -> str:
    if not history:
        return ""
    lines = [
        "Recent questions in this thread (for follow-ups only; "
        "numbers must still come from tools/docs for the current window):"
    ]
    for item in history:
        lines.append(f"Q: {item['question']}")
        lines.append(f"A: {item['answer']}")
    return "\n".join(lines) + "\n"


async def ask(
    session: AsyncSession,
    *,
    user: User,
    settings: Settings | None,
    question: str,
    date_from: str | None = None,
    date_to: str | None = None,
    history: list[dict] | None = None,
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
        answer, term = nav
        return {
            "answer": answer,
            "citations": [],
            "confidence": "high",
            "source": "navigation",
            "model": None,
            "filter_term": term,
        }

    ui_from, ui_to = _resolve_range(date_from, date_to)
    selected_from, selected_to = analytics_service.parse_range(ui_from, ui_to)
    today = date.today()
    eff_from, eff_to = resolve_ask_window(selected_from, selected_to, text, today=today)
    api_key = settings.gemini_api_key or ""
    if not api_key:
        raise ServiceUnavailableError(
            "Chat is unavailable.",
            code="gemini_unconfigured",
        )
    terms = await _resolve_terms(
        session,
        user=user,
        question=text,
        start=eff_from,
        end=eff_to,
        api_key=api_key,
    )
    tools = await _tool_payload(
        session,
        user=user,
        date_from=eff_from.isoformat(),
        date_to=eff_to.isoformat(),
        start=eff_from,
        end=eff_to,
        terms=terms,
        question=text,
    )
    hits = await _ask_docs(
        session,
        user=user,
        question=text,
        start=eff_from,
        end=eff_to,
        terms=terms,
    )
    matched_citations = list(tools.get("matched_transactions") or [])
    if "settled_transactions" in tools:
        citations = list(tools.get("settled_transactions") or [])
    elif matched_citations:
        citations = matched_citations
    else:
        sql_citations = list(tools.get("largest_debits") or [])
        rag_citations = await _citations_from_hits(session, user=user, hits=hits)
        citations = _merge_citations(sql_citations, rag_citations)
    docs = "\n".join(f"- {hit.content_text}" for hit in hits) or "none"
    prompt = _ASK_PROMPT.format(
        currency=tools["range"].get("currency") or user.default_currency,
        today=today.isoformat(),
        weekday=today.strftime("%A"),
        ui_from=ui_from,
        ui_to=ui_to,
        eff_from=eff_from.isoformat(),
        eff_to=eff_to.isoformat(),
        history_block=_history_block(_normalize_history(history)),
        question=text,
        tools=json.dumps(tools, default=str),
        docs=docs,
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
        "window_from": eff_from.isoformat(),
        "window_to": eff_to.isoformat(),
    }
