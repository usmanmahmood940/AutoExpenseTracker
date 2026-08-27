/// Comparison, ranking, and copy facts for Insights. Pure Dart — no Flutter.
library;

enum InsightsPeriodPreset { thisMonth, lastMonth, thisYear }

class InsightsNarrativeFacts {
  const InsightsNarrativeFacts({
    this.spendChangePercent,
    this.topCategory,
    this.topCategoryShare,
    this.topMerchant,
    this.topMerchantAmount,
  });

  final double? spendChangePercent;
  final String? topCategory;

  /// Share of total spent, 0–1.
  final double? topCategoryShare;
  final String? topMerchant;
  final double? topMerchantAmount;

  bool get hasContent =>
      spendChangePercent != null ||
      topCategory != null ||
      topMerchant != null;
}

/// `null` when [previous] is zero so the UI can hide the badge.
double? percentChange(double current, double previous) {
  if (previous.abs() < 0.0001) return null;
  return ((current - previous) / previous.abs()) * 100.0;
}

double shareOfTotal(double amount, double total) {
  if (total.abs() < 0.0001) return 0;
  return amount / total;
}

List<MapEntry<String, double>> topEntries(
  Map<String, double> map, {
  int limit = 5,
}) {
  final list = map.entries.where((e) => e.value.abs() > 0.0001).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (list.length <= limit) return list;
  return list.take(limit).toList();
}

String merchantInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final token = parts.first;
    if (token.length == 1) return token.toUpperCase();
    return token.substring(0, 2).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime monthStart(DateTime month) => DateTime(month.year, month.month, 1);

DateTime monthEnd(DateTime month) => DateTime(month.year, month.month + 1, 0);

({DateTime from, DateTime to}) insightsRange({
  required InsightsPeriodPreset preset,
  required DateTime now,
  DateTime? month,
}) {
  final today = dateOnly(now);
  switch (preset) {
    case InsightsPeriodPreset.thisMonth:
      final m = month ?? DateTime(today.year, today.month);
      return (from: monthStart(m), to: monthEnd(m));
    case InsightsPeriodPreset.lastMonth:
      final m = month ?? DateTime(today.year, today.month - 1);
      return (from: monthStart(m), to: monthEnd(m));
    case InsightsPeriodPreset.thisYear:
      return (from: DateTime(today.year, 1, 1), to: today);
  }
}

({DateTime from, DateTime to}) previousInsightsRange({
  required InsightsPeriodPreset preset,
  required DateTime from,
  required DateTime to,
}) {
  if (preset == InsightsPeriodPreset.thisYear) {
    return (
      from: DateTime(from.year - 1, from.month, from.day),
      to: DateTime(to.year - 1, to.month, to.day),
    );
  }
  final prevMonth = DateTime(from.year, from.month - 1);
  return (from: monthStart(prevMonth), to: monthEnd(prevMonth));
}

InsightsNarrativeFacts narrativeFacts({
  required double spent,
  required int transactionCount,
  required Map<String, double> byCategory,
  required Map<String, double> byMerchant,
  double? previousSpent,
}) {
  if (transactionCount <= 0 && spent.abs() < 0.0001) {
    return const InsightsNarrativeFacts();
  }
  final categories = topEntries(byCategory, limit: 1);
  final merchants = topEntries(byMerchant, limit: 1);
  final topCategory = categories.isEmpty ? null : categories.first;
  final topMerchant = merchants.isEmpty ? null : merchants.first;
  return InsightsNarrativeFacts(
    spendChangePercent: previousSpent == null
        ? null
        : percentChange(spent, previousSpent),
    topCategory: topCategory?.key,
    topCategoryShare: topCategory == null
        ? null
        : shareOfTotal(topCategory.value, spent),
    topMerchant: topMerchant?.key,
    topMerchantAmount: topMerchant?.value,
  );
}

int compactYAxisInterval(double maxY) {
  if (maxY <= 0) return 1;
  if (maxY <= 1000) return 250;
  if (maxY <= 5000) return 1000;
  if (maxY <= 20000) return 4000;
  if (maxY <= 100000) return 20000;
  return 50000;
}

String compactAxisLabel(double value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    final m = value / 1000000;
    return m == m.roundToDouble() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    final k = value / 1000;
    return k == k.roundToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
  }
  return value.round().toString();
}
