"""Quota errors must fall through GEMINI_MODELS instead of failing the feature."""

from __future__ import annotations

import json

from app.services.gemini import (
    GEMINI_MODELS,
    ParseOk,
    generate_content,
    parse_transaction,
)

_QUOTA = (
    '{"error":{"code":429,"message":"You exceeded your current quota. '
    "Quota exceeded for metric: "
    "generativelanguage.googleapis.com/generate_content_free_tier_requests, "
    'limit: 20, model: gemini-2.5-flash","status":"RESOURCE_EXHAUSTED"}}'
)


def _parsed_json() -> str:
    return json.dumps(
        {
            "amount": 500,
            "currency": "PKR",
            "type": "debit",
            "merchant": "KFC",
            "merchantDetails": None,
            "category": "Food",
            "paymentMethod": "unknown",
            "bank": "Unknown",
            "accountId": "Unknown",
            "branch": None,
            "transactionTime": "2026-09-23T20:15:00+05:00",
            "transactionDate": "2026-09-23",
            "externalId": None,
            "externalIdType": "unknown",
            "parseConfidence": 0.9,
        }
    )


def _ok_payload() -> dict:
    return {"candidates": [{"content": {"parts": [{"text": _parsed_json()}]}}]}


class _Response:
    def __init__(
        self, status_code: int, text: str, payload: dict | None = None
    ) -> None:
        self.status_code = status_code
        self.text = text
        self._payload = payload or {}

    def json(self) -> dict:
        return self._payload


def _install_client(monkeypatch, calls: list[str]) -> None:
    class Client:
        def __init__(self, *args, **kwargs) -> None:
            del args, kwargs

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args) -> None:
            return None

        async def post(self, url, headers=None, json=None):
            del headers, json
            calls.append(url)
            if GEMINI_MODELS[0] in url:
                return _Response(429, _QUOTA)
            return _Response(200, "", _ok_payload())

    async def no_sleep(_seconds: float) -> None:
        return None

    monkeypatch.setattr("app.services.gemini._quota_exhausted", set())
    monkeypatch.setattr("app.services.gemini.httpx.AsyncClient", Client)
    monkeypatch.setattr("app.services.gemini.asyncio.sleep", no_sleep)


async def test_daily_quota_429_falls_back_to_next_model(monkeypatch) -> None:
    calls: list[str] = []
    _install_client(monkeypatch, calls)

    result = await parse_transaction("test-key", "spent 500 at KFC", ["Food"])

    assert isinstance(result, ParseOk)
    assert result.model == GEMINI_MODELS[1]
    assert GEMINI_MODELS[0] in calls[0]
    assert GEMINI_MODELS[1] in calls[1]
    assert result.parsed.merchant == "KFC"
    assert result.parsed.amount == 500


async def test_exhausted_model_is_skipped_on_the_next_call(monkeypatch) -> None:
    calls: list[str] = []
    _install_client(monkeypatch, calls)

    first, first_model = await generate_content("test-key", {"contents": []})
    second, second_model = await generate_content("test-key", {"contents": []})

    assert first_model == GEMINI_MODELS[1]
    assert second_model == GEMINI_MODELS[1]
    assert first["candidates"]
    assert second["candidates"]
    assert sum(GEMINI_MODELS[0] in url for url in calls) == 1
    assert calls[-1].find(GEMINI_MODELS[0]) == -1
