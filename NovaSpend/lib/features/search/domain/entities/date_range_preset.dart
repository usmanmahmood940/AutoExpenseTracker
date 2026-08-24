import 'package:intl/intl.dart';

/// Preset options for the Activity date-range filter sheet.
enum DateRangePreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  custom,
}

/// Inclusive calendar date range (date-only, local).
class DateRangeValue {
  const DateRangeValue({
    required this.preset,
    required this.from,
    required this.to,
  });

  final DateRangePreset preset;
  final DateTime from;
  final DateTime to;

  /// Formats like `Aug 4 – Aug 10, 2026`, or `Aug 4, 2026` for a single day.
  String formatSubtitle() {
    if (from.year == to.year && from.month == to.month && from.day == to.day) {
      return DateFormat('MMM d, y').format(from);
    }
    final sameYear = from.year == to.year;
    final left = DateFormat('MMM d').format(from);
    final right = sameYear
        ? DateFormat('MMM d, y').format(to)
        : DateFormat('MMM d, y').format(to);
    return '$left – $right';
  }
}

/// Resolves a [DateRangePreset] into inclusive from/to calendar days.
DateRangeValue resolveDateRange(
  DateRangePreset preset, {
  DateTime? now,
  DateTime? customFrom,
  DateTime? customTo,
}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);

  switch (preset) {
    case DateRangePreset.today:
      return DateRangeValue(preset: preset, from: today, to: today);
    case DateRangePreset.yesterday:
      final y = today.subtract(const Duration(days: 1));
      return DateRangeValue(preset: preset, from: y, to: y);
    case DateRangePreset.thisWeek:
      final start = today.subtract(Duration(days: today.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return DateRangeValue(preset: preset, from: start, to: end);
    case DateRangePreset.lastWeek:
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final start = thisWeekStart.subtract(const Duration(days: 7));
      final end = thisWeekStart.subtract(const Duration(days: 1));
      return DateRangeValue(preset: preset, from: start, to: end);
    case DateRangePreset.thisMonth:
      final start = DateTime(today.year, today.month, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return DateRangeValue(preset: preset, from: start, to: end);
    case DateRangePreset.lastMonth:
      final start = DateTime(today.year, today.month - 1, 1);
      final end = DateTime(today.year, today.month, 0);
      return DateRangeValue(preset: preset, from: start, to: end);
    case DateRangePreset.last3Months:
      final start = DateTime(today.year, today.month - 2, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return DateRangeValue(preset: preset, from: start, to: end);
    case DateRangePreset.thisYear:
      final start = DateTime(today.year, 1, 1);
      final end = DateTime(today.year, 12, 31);
      return DateRangeValue(preset: preset, from: start, to: end);
    case DateRangePreset.custom:
      final from = _dateOnly(customFrom ?? today);
      final to = _dateOnly(customTo ?? from);
      return DateRangeValue(
        preset: preset,
        from: from.isBefore(to) ? from : to,
        to: from.isBefore(to) ? to : from,
      );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
