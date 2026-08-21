"""receivedAt parsing + weekday names. Port of `functions/src/dates.ts`."""

from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta, timezone

_SHORTCUT_DATE_RE = re.compile(
    r"^(\d{1,2})/(\d{1,2})/(\d{4}),\s+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)\s+GMT\s*([+-]?\d{1,2})(?::(\d{2}))?$",
    re.IGNORECASE,
)
_ISO_LIKE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}")
_SLASH_DATE_RE = re.compile(r"\d{1,2}/\d{1,2}/\d{4}")
_ISO_DATE_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")

WEEKDAYS = (
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
)


def _to_12_hour(hour: int, ampm: str) -> int:
    period = ampm.upper()
    if period == "AM":
        return 0 if hour == 12 else hour
    return 12 if hour == 12 else hour + 12


def _parse_shortcut_date(value: str) -> datetime | None:
    match = _SHORTCUT_DATE_RE.match(value)
    if not match:
        return None
    (
        day_s,
        month_s,
        year_s,
        hour_s,
        minute_s,
        second_s,
        ampm,
        tz_hour_s,
        tz_min_s,
    ) = match.groups()
    day, month, year = int(day_s), int(month_s), int(year_s)
    hour = _to_12_hour(int(hour_s), ampm)
    minute, second = int(minute_s), int(second_s)
    if not (1 <= month <= 12 and 1 <= day <= 31 and 0 <= hour <= 23):
        return None
    tz_sign = -1 if tz_hour_s.strip().startswith("-") else 1
    tz_hours_abs = abs(int(tz_hour_s))
    tz_mins = int(tz_min_s) if tz_min_s else 0
    offset = timezone(timedelta(minutes=tz_sign * (tz_hours_abs * 60 + tz_mins)))
    try:
        return datetime(year, month, day, hour, minute, second, tzinfo=offset)
    except ValueError:
        return None


def parse_received_at(value: str) -> datetime | None:
    """ISO 8601, or iOS Shortcuts `dd/mm/yyyy, h:mm:ss AM/PM GMT +5`."""
    trimmed = value.strip()
    if not trimmed:
        return None
    from_shortcut = _parse_shortcut_date(trimmed)
    if from_shortcut is not None:
        return from_shortcut
    if _ISO_LIKE_RE.match(trimmed):
        try:
            parsed = datetime.fromisoformat(trimmed.replace("Z", "+00:00"))
        except ValueError:
            return None
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=UTC)
        return parsed
    if _SLASH_DATE_RE.search(trimmed):
        return None
    try:
        parsed = datetime.fromisoformat(trimmed.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed


def day_name_from_date(iso_date: str) -> str | None:
    """Weekday for a YYYY-MM-DD calendar date (UTC noon, matching the Function)."""
    match = _ISO_DATE_RE.match(iso_date.strip())
    if not match:
        return None
    year, month, day = int(match[1]), int(match[2]), int(match[3])
    try:
        noon = datetime(year, month, day, 12, 0, 0, tzinfo=UTC)
    except ValueError:
        return None
    if noon.year != year or noon.month != month or noon.day != day:
        return None
    return WEEKDAYS[int(noon.strftime("%w"))]
