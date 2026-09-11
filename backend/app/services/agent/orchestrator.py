"""Bounded Gemini tool-calling orchestrator for Ask + propose actions."""

from __future__ import annotations

import json
import logging
import re
import time
import uuid
from datetime import date, timedelta
from typing import Any

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.errors import BadRequestError, ServiceUnavailableError
from app.db.models.agent_proposal import AgentTrace
from app.db.models.user import User
from app.services import analytics as analytics_service
from app.services.agent.read_tools import READ_HANDLERS
from app.services.agent.tool_schemas import (
    ALL_TOOL_DECLARATIONS,
    READ_TOOL_NAMES,
    WRITE_TOOL_NAMES,
)
from app.services.agent.write_tools import (
    WRITE_STEP_BUILDERS,
    persist_proposal,
    proposal_to_dict,
)
from app.services.chat_question_range import resolve_ask_window
from app.services.gemini import GEMINI_MODELS, _ENDPOINT, _extract_text
from app.services.rate_limit import enforce_rate_limit
from app.services.transactions import SUMMABLE_STATUSES
from sqlalchemy import func, select
from app.db.models.transaction import Transaction

logger = logging.getLogger(__name__)

_MAX_ITERATIONS = 5
_TIMEOUT = 45.0
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

_SYSTEM = """You are NovaSpend's spending assistant.
You answer questions and propose actions about the user's personal transactions.

Rules:
- Use tools for all facts and numbers. Never invent totals or transactions.
- Prefer aggregate_spending for "how much" questions.
- Default types are debit (money you paid). Use types ["credit"] when the user
  asks how much someone paid them / money received / income.
- When listing with query_transactions for the same question, pass the same
  types filter as the aggregate call.
- Use concepts from the closed vocabulary (electricity, fast_food, fuel, …)
  when the user names a topic rather than a merchant.
- For actions (create, settle, unsettle, unmerge), call propose_* tools only.
  Never claim you already saved or settled anything.
- If multiple candidate transactions are plausible, ask the user to clarify.
- Stay on spending / NovaSpend topics only.
- Today is {today} ({weekday}). Default window: {eff_from} to {eff_to}.
- Currency: {currency}.
"""


async def _active_count(session: AsyncSession, user_id: uuid.UUID) -> int:
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


async def _gemini_turn(
    *,
    api_key: str,
    model: str,
    contents: list[dict],
    system: str,
) -> dict[str, Any]:
    body = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": contents,
        "tools": [{"functionDeclarations": ALL_TOOL_DECLARATIONS}],
        "toolConfig": {"functionCallingConfig": {"mode": "AUTO"}},
        "generationConfig": {"temperature": 0.0},
    }
    url = _ENDPOINT.format(model=model)
    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        response = await client.post(url, params={"key": api_key}, json=body)
        if response.status_code >= 400:
            raise RuntimeError(f"{response.status_code} {response.text[:400]}")
        return response.json()


def _parts_from_response(payload: dict[str, Any]) -> list[dict[str, Any]]:
    candidates = payload.get("candidates") or []
    if not candidates:
        return []
    content = candidates[0].get("content") or {}
    return list(content.get("parts") or [])


def _function_calls(parts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls = []
    for part in parts:
        fc = part.get("functionCall")
        if isinstance(fc, dict) and fc.get("name"):
            calls.append(fc)
    return calls


def _text_from_parts(parts: list[dict[str, Any]]) -> str:
    chunks = []
    for part in parts:
        text = part.get("text")
        if isinstance(text, str) and text.strip():
            chunks.append(text.strip())
    return "\n".join(chunks).strip()


async def run_agent(
    session: AsyncSession,
    *,
    user: User,
    settings: Settings | None,
    question: str,
    date_from: str | None = None,
    date_to: str | None = None,
    history: list[dict] | None = None,
    conversation_id: str | None = None,
    request_id: str | None = None,
) -> dict[str, Any]:
    settings = settings or get_settings()
    text = (question or "").strip()
    if not text:
        raise BadRequestError("question is required.", code="question_required")

    await enforce_rate_limit(
        session,
        settings,
        scope="agent_chat",
        key=str(user.id),
        limit=getattr(settings, "agent_chat_limit_per_user", None)
        or max(10, settings.chat_ask_limit_per_user // 2),
    )
    _guardrail(text)

    active = await _active_count(session, user.id)
    if active < settings.chat_min_transactions:
        raise BadRequestError(
            "Not enough transactions to answer yet.",
            code="insufficient_data",
        )

    api_key = settings.gemini_api_key or ""
    if not api_key:
        raise ServiceUnavailableError(
            "Chat is unavailable.",
            code="gemini_unconfigured",
        )

    started = time.perf_counter()
    if date_from and date_to:
        analytics_service.parse_range(date_from, date_to)
        ui_from, ui_to = date_from, date_to
    else:
        end = date.today()
        start = end - timedelta(days=365)
        ui_from, ui_to = start.isoformat(), end.isoformat()
    selected_from, selected_to = analytics_service.parse_range(ui_from, ui_to)
    today = date.today()
    eff_from, eff_to = resolve_ask_window(
        selected_from, selected_to, text, today=today
    )

    system = _SYSTEM.format(
        today=today.isoformat(),
        weekday=today.strftime("%A"),
        eff_from=eff_from.isoformat(),
        eff_to=eff_to.isoformat(),
        currency=user.default_currency,
    )

    contents: list[dict[str, Any]] = []
    for turn in (history or [])[-3:]:
        q = str(turn.get("question") or "").strip()
        a = str(turn.get("answer") or "").strip()
        if q and a:
            contents.append({"role": "user", "parts": [{"text": q}]})
            contents.append({"role": "model", "parts": [{"text": a}]})
    contents.append(
        {
            "role": "user",
            "parts": [
                {
                    "text": (
                        f"{text}\n\n"
                        f"(Effective window: {eff_from.isoformat()} to "
                        f"{eff_to.isoformat()})"
                    )
                }
            ],
        }
    )

    model = GEMINI_MODELS[0]
    tool_trace: list[dict[str, Any]] = []
    proposal_steps: list[dict[str, Any]] = []
    citations: list[dict[str, Any]] = []
    aggregate_citations: list[dict[str, Any]] = []
    aggregate_numbers: list[float] = []
    final_answer = ""

    for _ in range(_MAX_ITERATIONS):
        try:
            payload = await _gemini_turn(
                api_key=api_key,
                model=model,
                contents=contents,
                system=system,
            )
        except Exception as exc:
            logger.warning("agent gemini turn failed: %s", exc)
            raise ServiceUnavailableError(
                "Chat is unavailable.",
                code="gemini_unavailable",
            ) from exc

        parts = _parts_from_response(payload)
        calls = _function_calls(parts)
        if not calls:
            final_answer = _text_from_parts(parts) or _extract_text(payload)
            break

        contents.append({"role": "model", "parts": parts})
        function_responses: list[dict[str, Any]] = []
        for call in calls:
            name = str(call.get("name") or "")
            args = call.get("args") or {}
            if not isinstance(args, dict):
                args = {}
            # Inject default window when model omits dates on read tools.
            if name in READ_TOOL_NAMES:
                args.setdefault("date_from", eff_from.isoformat())
                args.setdefault("date_to", eff_to.isoformat())

            if name in WRITE_TOOL_NAMES:
                builder = WRITE_STEP_BUILDERS.get(name)
                if builder is None:
                    result = {"error": f"unknown write tool {name}"}
                else:
                    try:
                        step = builder(args)
                        proposal_steps.append(step)
                        result = {
                            "status": "queued_for_confirmation",
                            "step": step,
                        }
                    except Exception as exc:
                        result = {"error": str(exc)}
            elif name in READ_HANDLERS:
                try:
                    result = await READ_HANDLERS[name](
                        session, user=user, args=args
                    )
                except Exception as exc:
                    logger.warning("read tool %s failed: %s", name, exc)
                    result = {"error": str(exc)}
                if name == "aggregate_spending":
                    sample = _citation_rows(result.get("transactions"))
                    if sample:
                        # Prefer rows that match the answered total's type filter.
                        aggregate_citations = sample
                    _collect_totals(result, aggregate_numbers)
                else:
                    _collect_citations(result, citations)
                    _collect_totals(result, aggregate_numbers)
            else:
                result = {"error": f"unknown tool {name}"}

            tool_trace.append({"name": name, "args": args, "result": result})
            function_responses.append(
                {
                    "functionResponse": {
                        "name": name,
                        "response": result,
                    }
                }
            )
        contents.append({"role": "user", "parts": function_responses})
    else:
        final_answer = final_answer or (
            "I need more information to finish that request."
        )

    proposal_payload = None
    proposal_id = None
    if proposal_steps:
        proposal = await persist_proposal(
            session,
            user=user,
            steps=proposal_steps,
            model=model,
            conversation_id=conversation_id,
        )
        proposal_payload = proposal_to_dict(proposal)
        proposal_id = proposal.id
        if not final_answer:
            final_answer = (
                "I prepared these changes for your review. "
                "Confirm to apply them."
            )

    if not final_answer:
        final_answer = "I could not produce an answer from the available data."

    latency_ms = int((time.perf_counter() - started) * 1000)
    session.add(
        AgentTrace(
            user_id=user.id,
            request_id=request_id,
            conversation_id=conversation_id,
            question=text,
            answer=final_answer,
            model=model,
            tool_calls=tool_trace,
            proposal_id=proposal_id,
            latency_ms=latency_ms,
        )
    )
    await session.commit()

    # Totals from aggregate_spending must cite matching sample rows, not a
    # separate query_transactions list that may use a different type filter.
    final_citations = _finalize_citations(aggregate_citations, citations)
    confidence = (
        "high" if final_citations or aggregate_numbers or proposal_payload else "medium"
    )
    return {
        "answer": final_answer,
        "citations": final_citations,
        "confidence": confidence,
        "source": "agent",
        "model": model,
        "filter_term": None,
        "window_from": eff_from.isoformat(),
        "window_to": eff_to.isoformat(),
        "proposal": proposal_payload,
        "tool_calls": [
            {"name": item["name"], "args": item["args"]} for item in tool_trace
        ],
    }


def _citation_rows(rows: Any) -> list[dict[str, Any]]:
    if not isinstance(rows, list):
        return []
    out: list[dict[str, Any]] = []
    for row in rows:
        if isinstance(row, dict) and row.get("transaction_id"):
            out.append(row)
    return out


def _finalize_citations(
    aggregate_citations: list[dict[str, Any]],
    other_citations: list[dict[str, Any]],
    *,
    limit: int = 8,
) -> list[dict[str, Any]]:
    preferred = aggregate_citations or other_citations
    seen: set[str] = set()
    out: list[dict[str, Any]] = []
    for row in preferred:
        tx_id = str(row.get("transaction_id") or "")
        if not tx_id or tx_id in seen:
            continue
        seen.add(tx_id)
        out.append(row)
        if len(out) >= limit:
            break
    return out


def _collect_citations(result: dict[str, Any], out: list[dict[str, Any]]) -> None:
    for key in ("transactions", "settlements", "candidates"):
        out.extend(_citation_rows(result.get(key)))
    tx = result.get("transaction")
    if isinstance(tx, dict) and tx.get("transaction_id"):
        out.append(tx)


def _collect_totals(result: dict[str, Any], out: list[float]) -> None:
    if "grand_total" in result:
        try:
            out.append(float(result["grand_total"]))
        except (TypeError, ValueError):
            pass
