"""receivedAt parsing — ISO and iOS Shortcuts locale format."""

from __future__ import annotations

from datetime import UTC

from app.services.dates import day_name_from_date, parse_received_at


def test_iso_with_offset() -> None:
    parsed = parse_received_at("2026-07-06T11:27:00+05:00")
    assert parsed is not None
    assert parsed.year == 2026
    assert parsed.month == 7
    assert parsed.day == 6
    assert parsed.hour == 11


def test_shortcut_locale_date() -> None:
    parsed = parse_received_at("10/07/2026, 6:02:00 PM GMT +5")
    assert parsed is not None
    utc = parsed.astimezone(UTC)
    # 18:02 PKT = 13:02 UTC
    assert utc.day == 10
    assert utc.month == 7
    assert utc.hour == 13
    assert utc.minute == 2


def test_slash_date_without_time_is_rejected() -> None:
    assert parse_received_at("10/07/2026") is None


def test_day_name_matches_js_utc_noon() -> None:
    assert day_name_from_date("2026-07-10") == "Friday"
    assert day_name_from_date("not-a-date") is None
