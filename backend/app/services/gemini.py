"""Gemini SMS → JSON. Port of `functions/src/gemini.ts` via the REST API."""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any
from zoneinfo import ZoneInfo

import httpx

from app.db.seeds.categories import FALLBACK_CATEGORY_NAME
from app.services.currencies import CURRENCIES, DEFAULT_CURRENCY, normalize_currency
from app.services.merchant_key import resolve_merchant
from app.services.payment_methods import (
    DEFAULT_PAYMENT_METHOD,
    PAYMENT_METHODS,
    normalize_payment_method,
)

logger = logging.getLogger(__name__)

# Temporary: gemini-3.1-flash-lite is returning 503 high demand.
# 2.5-flash is first, but its free tier is 20 requests/day. Callers must
# fall through this tuple on 429/503; do not pin GEMINI_MODELS[0].
GEMINI_MODELS = (
    "gemini-2.5-flash",
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash",
)
# Daily free-tier exhaustion does not recover until the quota window resets.
_quota_exhausted: set[str] = set()
MIN_PARSE_CONFIDENCE = 0.5
_KARACHI = ZoneInfo("Asia/Karachi")
_ENDPOINT = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)


@dataclass(frozen=True)
class ParsedTransaction:
    amount: float
    currency: str
    type: str
    merchant: str
    merchant_details: str | None
    category: str
    payment_method: str
    bank: str
    account_id: str
    branch: str | None
    transaction_time: str
    transaction_date: str
    external_id: str | None
    external_id_type: str
    parse_confidence: float


@dataclass(frozen=True)
class ParseOk:
    parsed: ParsedTransaction
    model: str


@dataclass(frozen=True)
class ParseFail:
    error: str
    low_confidence: bool = False


ParseResult = ParseOk | ParseFail


def format_pakistan_now(now: datetime) -> tuple[str, str]:
    if now.tzinfo is None:
        now = now.replace(tzinfo=UTC)
    local = now.astimezone(_KARACHI).replace(microsecond=0)
    current_date = local.date().isoformat()
    current_datetime = local.isoformat()
    return current_date, current_datetime


def resolve_allowed_category(raw: str, allowed_names: list[str]) -> str:
    trimmed = raw.strip()
    for name in allowed_names:
        if name == trimmed:
            return name
    lower = trimmed.lower()
    for name in allowed_names:
        if name.lower() == lower:
            return name
    for name in allowed_names:
        if name == FALLBACK_CATEGORY_NAME:
            return name
    return FALLBACK_CATEGORY_NAME


def _schema(allowed_categories: list[str]) -> dict[str, Any]:
    return {
        "type": "OBJECT",
        "properties": {
            "amount": {
                "type": "NUMBER",
                "description": "Transaction amount as a number without commas",
            },
            "currency": {
                "type": "STRING",
                "format": "enum",
                "enum": list(CURRENCIES),
            },
            "type": {"type": "STRING", "description": "debit or credit"},
            "merchant": {
                "type": "STRING",
                "description": (
                    "Primary merchant or payee. Use ATM for cash withdrawals "
                    "with no named merchant — never Unknown"
                ),
            },
            "merchantDetails": {"type": "STRING", "nullable": True},
            "category": {
                "type": "STRING",
                "format": "enum",
                "enum": allowed_categories,
            },
            "paymentMethod": {
                "type": "STRING",
                "format": "enum",
                "enum": list(PAYMENT_METHODS),
            },
            "bank": {"type": "STRING"},
            "accountId": {"type": "STRING"},
            "branch": {"type": "STRING", "nullable": True},
            "transactionTime": {"type": "STRING"},
            "transactionDate": {"type": "STRING"},
            "externalId": {"type": "STRING", "nullable": True},
            "externalIdType": {"type": "STRING"},
            "parseConfidence": {"type": "NUMBER"},
        },
        "required": [
            "amount",
            "currency",
            "type",
            "merchant",
            "category",
            "paymentMethod",
            "bank",
            "accountId",
            "transactionTime",
            "transactionDate",
            "externalIdType",
            "parseConfidence",
        ],
    }


def _system_prompt(
    allowed_categories: list[str], current_date: str, current_datetime: str
) -> str:
    category_list = ", ".join(allowed_categories)
    currencies = ", ".join(CURRENCIES)
    methods = ", ".join(PAYMENT_METHODS)
    return (
        "You parse transaction text into structured JSON. Inputs may be Pakistani "
        "bank SMS/email alerts OR short natural-language descriptions written by "
        'users (e.g. "spent 200 at KFC", "salary 150000", "received 500 from Ali").\n\n'
        "Rules:\n"
        '- Amounts must be numbers without commas (e.g. 5990.00 not "5,990.00").\n'
        f"- currency: MUST be exactly one of: [{currencies}]. Usually "
        f"{DEFAULT_CURRENCY} for Pakistani bank SMS; use another code only when "
        "clearly stated.\n"
        '- type must be lowercase "debit" or "credit". Infer from wording when '
        "needed (spent/paid/charged → debit; received/salary/credited → credit).\n"
        "- Dates must use ISO format: transactionDate as YYYY-MM-DD, "
        "transactionTime as ISO 8601 with +05:00 for Pakistan.\n"
        "- If the input is a manual/natural-language entry and does not specify a "
        "date or time, use exactly this current date/time supplied by the "
        f"application: transactionDate={current_date}, "
        f'transactionTime={current_datetime}. Never invent another "today" and '
        "never use placeholders.\n"
        "- If a bank message includes a date/time, prefer those values from the "
        "message.\n"
        "- merchant: required. For cash withdrawal / ATM with no named merchant, "
        'use "ATM" — never "Unknown". Put ATM location in merchantDetails when '
        "present.\n"
        '- Use "Unknown" for missing merchantDetails, branch, bank, or accountId '
        "when not inferable.\n"
        f"- paymentMethod: MUST be exactly one of: [{methods}].\n"
        f"  If not inferable, use {DEFAULT_PAYMENT_METHOD}.\n"
        "- accountId should preserve masking from bank messages (e.g. xxx1215).\n"
        "- externalIdType: use tid for TID, ref for reference numbers, stan for "
        "STAN, unknown otherwise (typical for manual entries).\n"
        f"- category: MUST be exactly one of these values: [{category_list}].\n"
        "  Income: salary, employer/company, investment only. Person-to-person "
        "(named individual, P2P, IBFT/Raast) → Transfer, never Income.\n"
        f"  If none fit, use {FALLBACK_CATEGORY_NAME}.\n"
        "- parseConfidence: 0.0-1.0 based on how clearly fields were extracted."
    )


def _normalize(raw: dict[str, Any], allowed_categories: list[str]) -> ParsedTransaction:
    details = raw.get("merchantDetails")
    branch = raw.get("branch")
    external_id = raw.get("externalId")
    category = resolve_allowed_category(
        str(raw.get("category") or FALLBACK_CATEGORY_NAME),
        allowed_categories,
    )
    payment_method = normalize_payment_method(
        str(raw.get("paymentMethod") or DEFAULT_PAYMENT_METHOD)
    )
    return ParsedTransaction(
        amount=float(raw.get("amount") or 0),
        currency=normalize_currency(str(raw.get("currency") or DEFAULT_CURRENCY)),
        type=str(raw.get("type") or "debit").lower(),
        merchant=resolve_merchant(
            str(raw.get("merchant") or ""),
            category=category,
            payment_method=payment_method,
        ),
        merchant_details=(
            None if details is None or details == "Unknown" else str(details)
        ),
        category=category,
        payment_method=payment_method,
        bank=str(raw.get("bank") or "Unknown"),
        account_id=str(raw.get("accountId") or "Unknown"),
        branch=None if branch is None or branch == "Unknown" else str(branch),
        transaction_time=str(raw.get("transactionTime") or ""),
        transaction_date=str(raw.get("transactionDate") or ""),
        external_id=(
            None
            if external_id is None or external_id == "Unknown"
            else str(external_id)
        ),
        external_id_type=str(raw.get("externalIdType") or "unknown").lower(),
        parse_confidence=float(raw.get("parseConfidence") or 0),
    )


def _is_retryable(message: str) -> bool:
    lower = message.lower()
    return (
        "429" in message
        or "RESOURCE_EXHAUSTED" in message
        or "503" in message
        or "UNAVAILABLE" in message
        or "404" in message
        or "high demand" in lower
        or "service unavailable" in lower
        or "no longer available" in lower
        or "not found" in lower
    )


def _extract_text(payload: dict[str, Any]) -> str:
    candidates = payload.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini returned no candidates")
    parts = ((candidates[0].get("content") or {}).get("parts")) or []
    texts = [str(part.get("text") or "") for part in parts]
    text = "".join(texts).strip()
    if not text:
        raise RuntimeError("Gemini returned an empty response")
    return text


def _mark_quota_exhausted(model_name: str, message: str) -> None:
    lower = message.lower()
    if (
        "free_tier" in lower
        or "quota exceeded" in lower
        or "exceeded your current quota" in lower
    ):
        _quota_exhausted.add(model_name)


async def generate_content(
    api_key: str,
    body: dict[str, Any],
    *,
    request_timeout: float = 45.0,
) -> tuple[dict[str, Any], str]:
    """POST generateContent, walking GEMINI_MODELS on retryable errors.

    Returns (response JSON, model name). Raises RuntimeError when every
    candidate fails. A daily-quota 429 is remembered so later calls skip it.
    """
    last_error = "Unknown Gemini error"
    models = [name for name in GEMINI_MODELS if name not in _quota_exhausted]
    if not models:
        models = list(GEMINI_MODELS)

    async with httpx.AsyncClient(timeout=request_timeout) as client:
        for index, model_name in enumerate(models):
            try:
                url = _ENDPOINT.format(model=model_name)
                response = await client.post(
                    url,
                    headers={"x-goog-api-key": api_key},
                    json=body,
                )
                if response.status_code >= 400:
                    raise RuntimeError(f"{response.status_code} {response.text[:500]}")
                if index > 0:
                    logger.warning(
                        "gemini_fallback_ok",
                        extra={"model": model_name, "skipped": models[:index]},
                    )
                return response.json(), model_name
            except Exception as exc:
                message = str(exc)
                last_error = f"[{model_name}] {message}"
                if _is_retryable(message):
                    _mark_quota_exhausted(model_name, message)
                    # `message` is reserved on LogRecord; using it as extra
                    # raises KeyError and aborts the fallback loop.
                    logger.warning(
                        "gemini_model_retry",
                        extra={"model": model_name, "detail": message},
                    )
                    await asyncio.sleep(1.5)
                    continue
                logger.error(
                    "gemini_model_failed",
                    extra={"model": model_name, "detail": message},
                )
                raise RuntimeError(last_error) from exc

    logger.error("gemini_models_exhausted", extra={"detail": last_error})
    raise RuntimeError(last_error)


async def parse_transaction(
    api_key: str,
    raw_message: str,
    allowed_categories: list[str],
    now: datetime | None = None,
) -> ParseResult:
    if not allowed_categories:
        return ParseFail(error="No allowed categories configured")
    if not api_key:
        return ParseFail(error="Gemini is not configured (GEMINI_API_KEY)")

    current_date, current_datetime = format_pakistan_now(now or datetime.now(UTC))
    body = {
        "systemInstruction": {
            "parts": [
                {
                    "text": _system_prompt(
                        allowed_categories, current_date, current_datetime
                    )
                }
            ]
        },
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "text": (
                            f"Current date/time: {current_datetime}\n\n"
                            f"Parse this transaction message:\n\n{raw_message}"
                        )
                    }
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json",
            "responseSchema": _schema(allowed_categories),
        },
    }
    try:
        payload, model_name = await generate_content(api_key, body)
        text = _extract_text(payload)
        parsed = _normalize(json.loads(text), allowed_categories)
    except Exception as exc:
        return ParseFail(error=str(exc))
    if parsed.parse_confidence < MIN_PARSE_CONFIDENCE:
        return ParseFail(
            error=f"Low parse confidence: {parsed.parse_confidence}",
            low_confidence=True,
        )
    return ParseOk(parsed=parsed, model=model_name)
