/**
 * Parse receivedAt from ISO 8601 or iOS Shortcuts locale format.
 *
 * Shortcuts often send: "dd/mm/yyyy, h:mm:ss AM/PM GMT +5"
 * Native Date.parse treats slash dates as mm/dd (US), which swaps day/month.
 */

const SHORTCUT_DATE_RE =
  /^(\d{1,2})\/(\d{1,2})\/(\d{4}),\s+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)\s+GMT\s*([+-]?\d{1,2})(?::(\d{2}))?$/i;

const ISO_LIKE_RE = /^\d{4}-\d{2}-\d{2}/;

function to12Hour(hour: number, ampm: string): number {
  const period = ampm.toUpperCase();
  if (period === 'AM') {
    return hour === 12 ? 0 : hour;
  }
  return hour === 12 ? 12 : hour + 12;
}

function parseShortcutDate(value: string): Date | null {
  const match = value.match(SHORTCUT_DATE_RE);
  if (!match) {
    return null;
  }

  const [, dayStr, monthStr, yearStr, hourStr, minuteStr, secondStr, ampm, tzHourStr, tzMinStr] =
    match;

  const day = Number(dayStr);
  const month = Number(monthStr);
  const year = Number(yearStr);
  const hour = to12Hour(Number(hourStr), ampm);
  const minute = Number(minuteStr);
  const second = Number(secondStr);

  if (
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31 ||
    hour < 0 ||
    hour > 23
  ) {
    return null;
  }

  const tzSign = tzHourStr.trim().startsWith('-') ? -1 : 1;
  const tzHoursAbs = Math.abs(Number(tzHourStr));
  const tzMins = tzMinStr ? Number(tzMinStr) : 0;
  const offsetMinutes = tzSign * (tzHoursAbs * 60 + tzMins);

  // Local wall time in the given offset → UTC
  const utcMs =
    Date.UTC(year, month - 1, day, hour, minute, second) -
    offsetMinutes * 60 * 1000;

  const date = new Date(utcMs);
  return Number.isNaN(date.getTime()) ? null : date;
}

/** Returns a valid Date, or null if the string cannot be parsed safely. */
export function parseReceivedAt(value: string): Date | null {
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  const fromShortcut = parseShortcutDate(trimmed);
  if (fromShortcut) {
    return fromShortcut;
  }

  // ISO 8601 (and other unambiguous year-first forms)
  if (ISO_LIKE_RE.test(trimmed)) {
    const date = new Date(trimmed);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  // Reject remaining slash dates — Date.parse would assume mm/dd
  if (/\d{1,2}\/\d{1,2}\/\d{4}/.test(trimmed)) {
    return null;
  }

  const date = new Date(trimmed);
  return Number.isNaN(date.getTime()) ? null : date;
}

const WEEKDAYS = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
] as const;

/** Weekday name for a YYYY-MM-DD calendar date (e.g. 2026-07-10 → Friday). */
export function dayNameFromDate(isoDate: string): string | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(isoDate.trim());
  if (!match) {
    return null;
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  // Noon UTC avoids DST / timezone edge cases for calendar-day weekday.
  const date = new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
  if (
    Number.isNaN(date.getTime()) ||
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }

  return WEEKDAYS[date.getUTCDay()];
}
