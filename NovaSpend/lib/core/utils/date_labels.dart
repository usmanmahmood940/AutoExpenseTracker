import 'package:intl/intl.dart';

/// Human day label for a `yyyy-MM-dd` (or ISO) date key: "Today", "Yesterday",
/// or a formatted date like "Feb 12, 2026". [today]/[yesterday] are injected so
/// the caller can pass localized strings.
String relativeDayLabel(
  String dateKey, {
  required String today,
  required String yesterday,
}) {
  final parsed = DateTime.tryParse(dateKey);
  if (parsed == null) return dateKey;

  final now = DateTime.now();
  final d = DateTime(parsed.year, parsed.month, parsed.day);
  final t = DateTime(now.year, now.month, now.day);
  final diff = t.difference(d).inDays;

  if (diff == 0) return today;
  if (diff == 1) return yesterday;
  return DateFormat.yMMMd().format(parsed);
}

/// Formats a stored transaction time (e.g. "16:20", "16:20:00", or an ISO
/// timestamp) into a friendly clock label like "04:20 PM". Returns an empty
/// string when the input can't be understood.
String formatClockTime(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';

  final iso = DateTime.tryParse(value);
  if (iso != null) return DateFormat('hh:mm a').format(iso);

  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  if (match != null) {
    final hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    if (hour < 24 && minute < 60) {
      final dt = DateTime(2000, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    }
  }

  return value;
}
