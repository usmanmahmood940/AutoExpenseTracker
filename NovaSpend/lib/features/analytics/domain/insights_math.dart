/// Comparison, ranking, and copy facts for Insights. Pure Dart — no Flutter.
library;

import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/trend_point_entity.dart';

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

/// Net % change is misleading when the previous net was negative (sign flip).
double? displayableNetChangePercent(double currentNet, double? previousNet) {
  if (previousNet == null || previousNet < 0) return null;
  return percentChange(currentNet, previousNet);
}

class OtherCategorySpend {
  const OtherCategorySpend({required this.amount, required this.share});

  final double amount;
  final double share;
}

/// Remaining spend outside the top [limit] categories, if any.
OtherCategorySpend? otherCategorySpend(
  Map<String, double> byCategory,
  double totalSpent, {
  int limit = 5,
}) {
  final positive = byCategory.entries
      .where((entry) => entry.value.abs() > 0.0001)
      .length;
  if (positive <= limit) return null;
  final top = topEntries(byCategory, limit: limit);
  final topSum = top.fold<double>(0, (sum, entry) => sum + entry.value);
  final remainder = totalSpent - topSum;
  if (remainder.abs() <= 0.0001) return null;
  return OtherCategorySpend(
    amount: remainder,
    share: shareOfTotal(remainder, totalSpent),
  );
}

/// Maps previous-period trend debits onto [current] point indices.
List<double> alignPreviousTrendValues({
  required List<TrendPointEntity> current,
  required List<TrendPointEntity> previous,
}) {
  if (current.isEmpty) return const [];
  if (previous.isEmpty) {
    return List<double>.filled(current.length, 0);
  }
  return [
    for (var i = 0; i < current.length; i++)
      i < previous.length ? previous[i].debit : 0.0,
  ];
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

bool hasTrendChartContent(List<TrendPointEntity> points) {
  return points.where((point) => point.debit > 0.0001).length >= 3;
}

String isoDay(DateTime value) {
  final d = dateOnly(value);
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Inclusive calendar months covering [from]..[to], as `YYYY-MM`.
List<String> yearMonthsInRange(DateTime from, DateTime to) {
  final months = <String>[];
  var cursor = DateTime(from.year, from.month);
  final last = DateTime(to.year, to.month);
  while (!cursor.isAfter(last)) {
    final y = cursor.year.toString().padLeft(4, '0');
    final m = cursor.month.toString().padLeft(2, '0');
    months.add('$y-$m');
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return months;
}

Map<String, double> _sumMaps(Iterable<Map<String, double>> maps) {
  final out = <String, double>{};
  for (final map in maps) {
    map.forEach((key, value) {
      out[key] = (out[key] ?? 0) + value;
    });
  }
  return out;
}

MonthlySummaryEntity mergeMonthlySummaries(
  List<MonthlySummaryEntity> items, {
  required DateTime from,
  required DateTime to,
}) {
  var debit = 0.0;
  var credit = 0.0;
  var count = 0;
  var currency = 'PKR';
  final stats = <String, MerchantSpendStat>{};
  for (final item in items) {
    currency = item.currency;
    debit += item.totalDebit;
    credit += item.totalCredit;
    count += item.transactionCount;
    item.byMerchantStats.forEach((key, stat) {
      final existing = stats[key];
      if (existing == null) {
        stats[key] = stat;
        return;
      }
      stats[key] = MerchantSpendStat(
        amount: existing.amount + stat.amount,
        visitCount: existing.visitCount + stat.visitCount,
        merchantNormalized: existing.merchantNormalized.isNotEmpty
            ? existing.merchantNormalized
            : stat.merchantNormalized,
      );
    });
  }
  return MonthlySummaryEntity(
    yearMonth: '',
    dateFrom: isoDay(from),
    dateTo: isoDay(to),
    currency: currency,
    totalDebit: debit,
    totalCredit: credit,
    net: credit - debit,
    transactionCount: count,
    byCategory: _sumMaps(items.map((e) => e.byCategory)),
    byMerchant: _sumMaps(items.map((e) => e.byMerchant)),
    byMerchantStats: stats,
  );
}
