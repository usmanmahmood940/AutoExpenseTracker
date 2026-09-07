"""Resolve the Ask window from relative dates in the question."""

from __future__ import annotations

import calendar
import re
from datetime import date, timedelta

_ISO_DAY = re.compile(r"\b(20\d{2}-\d{2}-\d{2})\b")
_TODAY = re.compile(r"\btoday'?s?\b", re.I)
_YESTERDAY = re.compile(r"\byesterday\b", re.I)
_THIS_WEEK = re.compile(r"\bthis week\b", re.I)
_LAST_WEEK = re.compile(r"\blast week\b", re.I)
_THIS_MONTH = re.compile(r"\bthis month\b", re.I)
_LAST_MONTH = re.compile(r"\blast month\b", re.I)
_THIS_YEAR = re.compile(r"\bthis year\b", re.I)


def _week_bounds(day: date) -> tuple[date, date]:
    monday = day - timedelta(days=day.weekday())
    return monday, monday + timedelta(days=6)


def _month_bounds(year: int, month: int) -> tuple[date, date]:
    last = calendar.monthrange(year, month)[1]
    return date(year, month, 1), date(year, month, last)


def question_window(question: str, *, today: date) -> tuple[date, date] | None:
    """Return a calendar window implied by the question, or None."""
    text = question or ""
    iso = _ISO_DAY.search(text)
    if iso:
        try:
            parsed = date.fromisoformat(iso.group(1))
        except ValueError:
            parsed = None
        if parsed is not None:
            return parsed, parsed
    if _TODAY.search(text):
        return today, today
    if _YESTERDAY.search(text):
        yesterday = today - timedelta(days=1)
        return yesterday, yesterday
    if _THIS_WEEK.search(text):
        return _week_bounds(today)
    if _LAST_WEEK.search(text):
        this_monday, _ = _week_bounds(today)
        last_sunday = this_monday - timedelta(days=1)
        return _week_bounds(last_sunday)
    if _THIS_MONTH.search(text):
        start, _ = _month_bounds(today.year, today.month)
        return start, today
    if _LAST_MONTH.search(text):
        first_this, _ = _month_bounds(today.year, today.month)
        last_day_prev = first_this - timedelta(days=1)
        return _month_bounds(last_day_prev.year, last_day_prev.month)
    if _THIS_YEAR.search(text):
        return date(today.year, 1, 1), today
    return None


def resolve_ask_window(
    selected_from: date,
    selected_to: date,
    question: str,
    *,
    today: date,
) -> tuple[date, date]:
    """Use the question's window when present; otherwise the request range."""
    implied = question_window(question, today=today)
    if implied is None:
        return selected_from, selected_to
    return implied
