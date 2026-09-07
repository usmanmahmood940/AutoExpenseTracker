"""Relative dates in Ask questions set the answer window."""

from __future__ import annotations

from datetime import date

from app.services.chat_question_range import question_window, resolve_ask_window


def test_question_window_today_and_iso() -> None:
    today = date(2026, 9, 7)
    assert question_window("biggest of today", today=today) == (today, today)
    assert question_window("spend on 2026-03-10", today=today) == (
        date(2026, 3, 10),
        date(2026, 3, 10),
    )
    assert question_window("why did food jump?", today=today) is None


def test_question_window_weeks() -> None:
    today = date(2026, 9, 7)  # Monday
    assert question_window("this week", today=today) == (
        date(2026, 9, 7),
        date(2026, 9, 13),
    )
    assert question_window("last week", today=today) == (
        date(2026, 8, 31),
        date(2026, 9, 6),
    )
    yesterday = date(2026, 9, 6)
    assert question_window("yesterday", today=today) == (yesterday, yesterday)


def test_question_window_month_and_year() -> None:
    today = date(2026, 9, 7)
    assert question_window("what did I spend this month", today=today) == (
        date(2026, 9, 1),
        today,
    )
    assert question_window("compare last month", today=today) == (
        date(2026, 8, 1),
        date(2026, 8, 31),
    )
    assert question_window("totals this year", today=today) == (
        date(2026, 1, 1),
        today,
    )


def test_resolve_today_wins_over_selected_range() -> None:
    today = date(2026, 9, 7)
    start, end = resolve_ask_window(
        date(2026, 8, 1),
        date(2026, 8, 31),
        "tell me my biggest transaction of today",
        today=today,
    )
    assert (start, end) == (today, today)


def test_resolve_without_phrase_keeps_selected() -> None:
    today = date(2026, 9, 7)
    start, end = resolve_ask_window(
        date(2025, 9, 7),
        today,
        "Why did food spending jump?",
        today=today,
    )
    assert (start, end) == (date(2025, 9, 7), today)
