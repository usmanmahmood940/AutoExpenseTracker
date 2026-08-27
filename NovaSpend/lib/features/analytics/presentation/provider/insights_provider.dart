import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/recurring_merchant_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/trend_point_entity.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';

class InsightsProvider extends ChangeNotifier {
  InsightsProvider({required AnalyticsRepository repository})
      : _repository = repository;

  final AnalyticsRepository _repository;

  InsightsPeriodPreset preset = InsightsPeriodPreset.thisMonth;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _chevronOverride = false;

  MonthlySummaryEntity? summary;
  MonthlySummaryEntity? previousSummary;
  List<TrendPointEntity> trend = const [];
  List<RecurringMerchantEntity> recurring = const [];
  String? aiNarrative;
  bool isLoading = true;
  bool isLoadingExtras = false;
  String? error;
  String? _uid;
  int _loadToken = 0;

  /// Production Cloud Run may not have `/analytics/range` yet. After the first
  /// failure we sum monthly `/analytics/summary` and skip the new extras.
  bool _rangeUnavailable = false;

  DateTime get month => _month;
  String get yearMonth => DateFormat('yyyy-MM').format(_month);

  ({DateTime from, DateTime to}) get range {
    return insightsRange(
      preset: _chevronOverride
          ? InsightsPeriodPreset.thisMonth
          : preset,
      now: DateTime.now(),
      month: _month,
    );
  }

  DateRangeValue get activityDateRange {
    final bounds = range;
    return DateRangeValue(
      preset: DateRangePreset.custom,
      from: bounds.from,
      to: bounds.to,
    );
  }

  double? get spentChangePercent {
    final current = summary;
    final previous = previousSummary;
    if (current == null || previous == null) return null;
    return percentChange(current.totalDebit, previous.totalDebit);
  }

  double? get receivedChangePercent {
    final current = summary;
    final previous = previousSummary;
    if (current == null || previous == null) return null;
    return percentChange(current.totalCredit, previous.totalCredit);
  }

  double? get netChangePercent {
    final current = summary;
    final previous = previousSummary;
    if (current == null || previous == null) return null;
    return percentChange(current.net, previous.net);
  }

  InsightsNarrativeFacts get templateFacts {
    final current = summary;
    if (current == null) return const InsightsNarrativeFacts();
    return narrativeFacts(
      spent: current.totalDebit,
      transactionCount: current.transactionCount,
      byCategory: current.byCategory,
      byMerchant: current.byMerchant,
      previousSpent: previousSummary?.totalDebit,
    );
  }

  bool get isEmpty {
    final current = summary;
    if (current == null) return true;
    return current.transactionCount == 0 &&
        current.totalDebit.abs() < 0.0001 &&
        current.totalCredit.abs() < 0.0001;
  }

  void start(String uid) {
    _uid = uid;
    unawaitedLoad();
  }

  void setPreset(InsightsPeriodPreset next) {
    if (preset == next && !_chevronOverride) return;
    preset = next;
    _chevronOverride = false;
    final now = DateTime.now();
    if (next == InsightsPeriodPreset.thisMonth) {
      _month = DateTime(now.year, now.month);
    } else if (next == InsightsPeriodPreset.lastMonth) {
      _month = DateTime(now.year, now.month - 1);
    }
    unawaitedLoad();
    notifyListeners();
  }

  void previousMonth() {
    if (preset == InsightsPeriodPreset.thisYear && !_chevronOverride) {
      return;
    }
    _month = DateTime(_month.year, _month.month - 1);
    _chevronOverride = true;
    unawaitedLoad();
    notifyListeners();
  }

  void nextMonth() {
    if (preset == InsightsPeriodPreset.thisYear && !_chevronOverride) {
      return;
    }
    final now = DateTime.now();
    final candidate = DateTime(_month.year, _month.month + 1);
    if (candidate.isAfter(DateTime(now.year, now.month))) return;
    _month = candidate;
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    if (_month == thisMonth) {
      preset = InsightsPeriodPreset.thisMonth;
      _chevronOverride = false;
    } else if (_month == lastMonth) {
      preset = InsightsPeriodPreset.lastMonth;
      _chevronOverride = false;
    } else {
      _chevronOverride = true;
    }
    unawaitedLoad();
    notifyListeners();
  }

  void retry() => unawaitedLoad();

  void unawaitedLoad() {
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    final token = ++_loadToken;
    error = null;
    isLoading = true;
    aiNarrative = null;
    trend = const [];
    recurring = const [];
    notifyListeners();

    final bounds = range;
    final previous = previousInsightsRange(
      preset: _chevronOverride ? InsightsPeriodPreset.thisMonth : preset,
      from: bounds.from,
      to: bounds.to,
    );

    try {
      if (preset == InsightsPeriodPreset.thisYear && !_chevronOverride) {
        final currentFuture = _rangeOrMonthly(uid, bounds);
        final previousFuture = _rangeOrMonthly(uid, previous);
        summary = await currentFuture;
        previousSummary = await previousFuture;
        if (summary == null) {
          throw StateError('year_summary_unavailable');
        }
      } else {
        final prevMonth = DateTime(_month.year, _month.month - 1);
        final prevYm = DateFormat('yyyy-MM').format(prevMonth);
        final currentFuture = _repository.getSummary(uid, yearMonth);
        final previousFuture = _tryPreviousMonth(uid, prevYm);
        summary = await currentFuture;
        previousSummary = await previousFuture;
      }
      if (token != _loadToken) return;
      error = null;
    } catch (e) {
      if (token != _loadToken) return;
      error = e.toString();
      summary = null;
      previousSummary = null;
    } finally {
      if (token == _loadToken) {
        isLoading = false;
        notifyListeners();
      }
    }

    if (token != _loadToken || summary == null) return;
    if (_rangeUnavailable) return;
    await _loadExtras(uid, token, bounds);
  }

  Future<MonthlySummaryEntity?> _tryPreviousMonth(
    String uid,
    String yearMonth,
  ) async {
    try {
      return await _repository.getSummary(uid, yearMonth);
    } catch (_) {
      return null;
    }
  }

  /// Prefer `/analytics/range`; if it is not deployed yet, sum monthly
  /// `/analytics/summary` rows for the same window.
  Future<MonthlySummaryEntity?> _rangeOrMonthly(
    String uid,
    ({DateTime from, DateTime to}) bounds,
  ) async {
    if (!_rangeUnavailable) {
      try {
        return await _repository.getRange(
          uid,
          from: bounds.from,
          to: bounds.to,
        );
      } catch (_) {
        _rangeUnavailable = true;
      }
    }
    try {
      return await _summaryFromMonths(uid, bounds);
    } catch (_) {
      return null;
    }
  }

  Future<MonthlySummaryEntity> _summaryFromMonths(
    String uid,
    ({DateTime from, DateTime to}) bounds,
  ) async {
    final months = yearMonthsInRange(bounds.from, bounds.to);
    final items = await Future.wait(
      months.map((yearMonth) => _repository.getSummary(uid, yearMonth)),
    );
    return mergeMonthlySummaries(
      items,
      from: bounds.from,
      to: bounds.to,
    );
  }

  Future<void> _loadExtras(
    String uid,
    int token,
    ({DateTime from, DateTime to}) bounds,
  ) async {
    isLoadingExtras = true;
    notifyListeners();
    final trendFuture = _tryTrend(uid, bounds);
    final recurringFuture = _tryRecurring(uid, bounds);
    trend = await trendFuture;
    recurring = await recurringFuture;
    if (token != _loadToken) return;
    isLoadingExtras = false;
    notifyListeners();

    try {
      aiNarrative = await _repository.getNarrative(
        uid,
        from: bounds.from,
        to: bounds.to,
      );
    } catch (_) {
      aiNarrative = null;
    }
    if (token != _loadToken) return;
    notifyListeners();
  }

  Future<List<TrendPointEntity>> _tryTrend(
    String uid,
    ({DateTime from, DateTime to}) bounds,
  ) async {
    try {
      return await _repository.getTrend(
        uid,
        from: bounds.from,
        to: bounds.to,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<RecurringMerchantEntity>> _tryRecurring(
    String uid,
    ({DateTime from, DateTime to}) bounds,
  ) async {
    try {
      return await _repository.getRecurring(
        uid,
        from: bounds.from,
        to: bounds.to,
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _loadToken++;
    super.dispose();
  }
}
