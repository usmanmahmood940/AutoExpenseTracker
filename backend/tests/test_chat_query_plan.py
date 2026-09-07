"""LLM query planner: grounded picks only, and never raises."""

from __future__ import annotations

import asyncio

from app.services.chat_query_plan import _pick_valid, plan_merchants

_MERCHANTS = ["LESCO", "SNGPL", "Daraz", "KFC"]


def test_picks_are_kept_when_they_match() -> None:
    picked = _pick_valid('{"merchants": ["LESCO", "SNGPL"]}', _MERCHANTS)
    assert picked == ["LESCO", "SNGPL"]


def test_picks_match_case_insensitively_but_return_stored_casing() -> None:
    assert _pick_valid('{"merchants": ["lesco"]}', _MERCHANTS) == ["LESCO"]


def test_hallucinated_merchants_are_discarded() -> None:
    """The planner must never introduce a merchant the user does not have."""
    picked = _pick_valid(
        '{"merchants": ["LESCO", "Netflix", "K-Electric"]}', _MERCHANTS
    )
    assert picked == ["LESCO"]


def test_duplicates_collapse() -> None:
    assert _pick_valid('{"merchants": ["Daraz", "daraz"]}', _MERCHANTS) == ["Daraz"]


def test_non_string_items_are_ignored() -> None:
    assert _pick_valid('{"merchants": [1, null, "KFC"]}', _MERCHANTS) == ["KFC"]


def test_empty_and_malformed_shapes() -> None:
    assert _pick_valid('{"merchants": []}', _MERCHANTS) == []
    assert _pick_valid('{"merchants": "LESCO"}', _MERCHANTS) == []
    assert _pick_valid("{}", _MERCHANTS) == []


def test_no_api_key_skips_the_call() -> None:
    result = asyncio.run(
        plan_merchants(api_key="", question="how much on power", merchants=_MERCHANTS)
    )
    assert result == []


def test_no_merchants_skips_the_call() -> None:
    result = asyncio.run(
        plan_merchants(api_key="key", question="how much on power", merchants=[])
    )
    assert result == []


def test_blank_question_skips_the_call() -> None:
    result = asyncio.run(
        plan_merchants(api_key="key", question="   ", merchants=_MERCHANTS)
    )
    assert result == []


def test_transport_failure_returns_empty(monkeypatch) -> None:
    """A planner outage must degrade silently, not raise."""
    import httpx

    from app.services import chat_query_plan

    class BoomClient:
        def __init__(self, *args, **kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args) -> None:
            return None

        async def post(self, *args, **kwargs):
            raise httpx.ConnectError("planner unreachable")

    monkeypatch.setattr(chat_query_plan.httpx, "AsyncClient", BoomClient)
    result = asyncio.run(
        plan_merchants(
            api_key="key", question="how much on power", merchants=_MERCHANTS
        )
    )
    assert result == []
