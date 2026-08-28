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
  final Map<String, MonthlySummaryEntity> _summaryCache = {};
  final Map<String, MonthlySummaryEntity?> _previousSummaryCache = {};

  InsightsPeriodPreset preset = InsightsPeriodPreset.thisMonth;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _chevronOverride = false;

  MonthlySummaryEntity? summary;
  MonthlySummaryEntity? previousSummary;
  List<TrendPointEntity> trend = const [];
  List<TrendPointEntity> previousTrend = const [];
  List<RecurringMerchantEntity> recurring = const [];
  String? aiNarrative;
  bool isLoading = true;
  bool isLoadingExtras = false;
  bool isLoadingNarrative = false;
  String? error;
  String? _uid;
  int _loadToken = 0;
  String? _narrativeRangeKey;

  /// Production Cloud Run may not have `/analytics/range` yet. After the first
  /// failure we sum monthly `/analytics/summary` for range summaries.
  bool _rangeUnavailable = false;

  bool get chevronOverride => _chevronOverride;

  InsightsPeriodPreset? get selectedPreset =>
      _chevronOverride ? null : preset;

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
    return displayableNetChangePercent(current.net, previous.net);
  }

  int? get transactionCountChange {
    final current = summary;
    final previous = previousSummary;
    if (current == null || previous == null) return null;
    return current.transactionCount - previous.transactionCount;
  }

  bool get canGoNextMonth {
    if (preset == InsightsPeriodPreset.thisYear && !_chevronOverride) {
      return false;
    }
    final now = DateTime.now();
    final candidate = DateTime(_month.year, _month.month + 1);
    return !candidate.isAfter(DateTime(now.year, now.month));
  }

  List<double> get previousTrendValues {
    return alignPreviousTrendValues(
      current: trend,
      previous: previousTrend,
    );
  }

  ({DateTime from, DateTime to}) get previousRange {
    final bounds = range;
    return previousInsightsRange(
      preset: _chevronOverride ? InsightsPeriodPreset.thisMonth : preset,
      from: bounds.from,
      to: bounds.to,
    );
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

  Future<void> refresh() async {
    _clearCaches();
    await _load(forceRefresh: true);
  }

  void retry() => unawaitedLoad();

  void unawaitedLoad() {
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final uid = _uid;
    if (uid == null) return;
    final token = ++_loadToken;
    error = null;
    isLoading = true;
    trend = const [];
    recurring = const [];
    previousTrend = const [];

    final bounds = range;
    final rangeKey = _rangeKey(bounds);
    if (_narrativeRangeKey != rangeKey) {
      aiNarrative = null;
      _narrativeRangeKey = null;
    }
    notifyListeners();

    final previous = previousInsightsRange(
      preset: _chevronOverride ? InsightsPeriodPreset.thisMonth : preset,
      from: bounds.from,
      to: bounds.to,
    );

    try {
      if (preset == InsightsPeriodPreset.thisYear && !_chevronOverride) {
        final currentFuture = _rangeOrMonthly(
          uid,
          bounds,
          forceRefresh: forceRefresh,
        );
        final previousFuture = _rangeOrMonthly(
          uid,
          previous,
          forceRefresh: forceRefresh,
        );
        summary = await currentFuture;
        previousSummary = await previousFuture;
        if (summary == null) {
          throw StateError('year_summary_unavailable');
        }
      } else {
        final prevMonth = DateTime(_month.year, _month.month - 1);
        final prevYm = DateFormat('yyyy-MM').format(prevMonth);
        final currentFuture = _cachedSummary(
          uid,
          bounds,
          () => _repository.getSummary(uid, yearMonth),
          forceRefresh: forceRefresh,
        );
        final previousFuture = _cachedPreviousSummary(
          uid,
          previous,
          () => _tryPreviousMonth(uid, prevYm),
          forceRefresh: forceRefresh,
        );
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
    ({DateTime from, DateTime to}) bounds, {
    bool forceRefresh = false,
  }) async {
    return _cachedSummary(
      uid,
      bounds,
      () async {
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
        return _summaryFromMonths(uid, bounds);
      },
      forceRefresh: forceRefresh,
    );
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
    isLoadingNarrative = true;
    notifyListeners();

    final rangeKey = _rangeKey(bounds);
    final previousBounds = previousRange;
    final trendFuture = _tryTrend(uid, bounds);
    final previousTrendFuture = _tryTrend(uid, previousBounds);
    final recurringFuture = _tryRecurring(uid, bounds);
    final narrativeFuture = _tryNarrative(uid, bounds);

    final results = await Future.wait([
      trendFuture,
      previousTrendFuture,
      recurringFuture,
    ]);
    trend = results[0] as List<TrendPointEntity>;
    previousTrend = results[1] as List<TrendPointEntity>;
    recurring = results[2] as List<RecurringMerchantEntity>;
    if (token != _loadToken) return;

    isLoadingExtras = false;
    notifyListeners();

    aiNarrative = await narrativeFuture;
    if (token != _loadToken) return;
    _narrativeRangeKey = rangeKey;
    isLoadingNarrative = false;
    notifyListeners();
  }

  Future<MonthlySummaryEntity?> _cachedSummary(
    String uid,
    ({DateTime from, DateTime to}) bounds,
    Future<MonthlySummaryEntity?> Function() fetch, {
    bool forceRefresh = false,
  }) async {
    final key = _rangeKey(bounds);
    if (!forceRefresh && _summaryCache.containsKey(key)) {
      return _summaryCache[key];
    }
    final result = await fetch();
    if (result != null) {
      _summaryCache[key] = result;
    }
    return result;
  }

  Future<MonthlySummaryEntity?> _cachedPreviousSummary(
    String uid,
    ({DateTime from, DateTime to}) bounds,
    Future<MonthlySummaryEntity?> Function() fetch, {
    bool forceRefresh = false,
  }) async {
    final key = _rangeKey(bounds);
    if (!forceRefresh && _previousSummaryCache.containsKey(key)) {
      return _previousSummaryCache[key];
    }
    final result = await fetch();
    _previousSummaryCache[key] = result;
    return result;
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

  Future<String?> _tryNarrative(
    String uid,
    ({DateTime from, DateTime to}) bounds,
  ) async {
    try {
      return await _repository.getNarrative(
        uid,
        from: bounds.from,
        to: bounds.to,
      );
    } catch (_) {
      return null;
    }
  }

  void _clearCaches() {
    _summaryCache.clear();
    _previousSummaryCache.clear();
  }

  String _rangeKey(({DateTime from, DateTime to}) bounds) {
    final from = DateFormat('yyyy-MM-dd').format(bounds.from);
    final to = DateFormat('yyyy-MM-dd').format(bounds.to);
    return '$from|$to';
  }

  @override
  void dispose() {
    _loadToken++;
    super.dispose();
  }
}
