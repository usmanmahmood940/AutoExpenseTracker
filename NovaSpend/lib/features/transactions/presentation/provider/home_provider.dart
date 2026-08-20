import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/get_period_stats.dart';
import 'package:nova_spend/features/transactions/domain/usecases/get_transactions_page.dart';
import 'package:nova_spend/features/transactions/presentation/home_period.dart';

class PeriodTotals {
  const PeriodTotals({
    required this.spent,
    required this.received,
    required this.currency,
  });

  final double spent;
  final double received;
  final String currency;

  double get net => received - spent;

  static const empty = PeriodTotals(spent: 0, received: 0, currency: 'PKR');
}

class PeriodComparison {
  const PeriodComparison({
    this.spentChangePercent,
    this.receivedChangePercent,
    this.netChangePercent,
  });

  final double? spentChangePercent;
  final double? receivedChangePercent;
  final double? netChangePercent;

  static const empty = PeriodComparison();
}

/// Max transactions fetched for the home preview feed.
const int homePageSize = 20;

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    required GetTransactionsPage getTransactionsPage,
    required GetPeriodStats getPeriodStats,
    required TransactionRepository transactionRepository,
  }) : _getTransactionsPage = getTransactionsPage,
       _getPeriodStats = getPeriodStats,
       _transactionRepository = transactionRepository;

  final GetTransactionsPage _getTransactionsPage;
  final GetPeriodStats _getPeriodStats;
  final TransactionRepository _transactionRepository;

  List<TransactionEntity> _items = [];
  TransactionFilter _filter = TransactionFilter.empty;
  HomePeriod _period = HomePeriod.thisWeek;
  final Map<HomePeriod, PeriodStatsEntity> _periodStats = {};
  int _pendingReviewCount = 0;
  int _totalCount = 0;
  double _totalAmount = 0;
  bool _isLoading = false;
  bool _isPeriodStatsLoading = false;
  bool _hasMore = true;
  String? _error;
  String? _uid;

  List<TransactionEntity>? _periodItemsCache;

  List<TransactionEntity> get items => _filtered(_items);

  /// Transactions visible for the selected period (Today / This Week / This Month).
  List<TransactionEntity> get periodItems {
    final cached = _periodItemsCache;
    if (cached != null) return cached;

    final start = _periodStart;
    final result = items.where((tx) {
      final date = _parseDate(tx);
      return date != null && !date.isBefore(start);
    }).toList();
    _periodItemsCache = result;
    return result;
  }

  void _invalidatePeriodCache() {
    _periodItemsCache = null;
  }

  TransactionFilter get filter => _filter;
  HomePeriod get period => _period;
  int get pendingReviewCount => _pendingReviewCount;
  int get totalCount => _totalCount;
  double get totalAmount => _totalAmount;
  bool get isLoading => _isLoading;
  bool get isPeriodStatsLoading => _isPeriodStatsLoading;
  bool get hasMore => _hasMore;

  /// True when the currently selected period may have more transactions than
  /// the ones loaded in the preview. Used for the "Show more" button.
  bool get periodHasMore =>
      periodItems.length >= homePageSize && _hasMore;

  String? get error => _error;

  PeriodStatsEntity? get currentPeriodStats => _periodStats[_period];

  List<String> get availableAccounts {
    final set = <String>{};
    for (final t in _items) {
      if (t.accountIdMasked.isNotEmpty) set.add(t.accountIdMasked);
    }
    final list = set.toList()..sort();
    return list;
  }

  PeriodTotals get periodTotals {
    final stats = currentPeriodStats;
    if (stats != null) {
      return PeriodTotals(
        spent: stats.spent,
        received: stats.received,
        currency: stats.currency,
      );
    }
    return PeriodTotals.empty;
  }

  PeriodComparison get periodComparison {
    if (_period == HomePeriod.today) return PeriodComparison.empty;
    final comparison = currentPeriodStats?.comparison;
    if (comparison == null) return PeriodComparison.empty;
    return PeriodComparison(
      spentChangePercent: comparison.spentChangePercent,
      receivedChangePercent: comparison.receivedChangePercent,
      netChangePercent: comparison.netChangePercent,
    );
  }

  /// Largest debit in the selected period (from getPeriodStats).
  PeriodHighlight? get highestSpend => currentPeriodStats?.highestSpend;

  /// Largest credit in the selected period (from getPeriodStats).
  PeriodHighlight? get highestReceive => currentPeriodStats?.highestReceive;

  void start(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final uid = _uid;
    if (uid == null) return;

    _isLoading = true;
    _isPeriodStatsLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadTransactionsPage(uid),
        _loadAllPeriodStats(),
        _loadPendingReviewCount(uid),
      ]);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isPeriodStatsLoading = false;
      notifyListeners();
    }
  }

  void setPeriod(HomePeriod period) {
    if (_period == period) return;
    _period = period;
    _invalidatePeriodCache();
    notifyListeners();
  }

  /// Pull-to-refresh: reloads the feed and stats for the **current** period only.
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    _isLoading = true;
    _isPeriodStatsLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadTransactionsPage(uid),
        _loadPeriodStats(_period),
        _loadPendingReviewCount(uid),
      ]);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isPeriodStatsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTransactionsPage(String uid) async {
    final page = await _getTransactionsPage(
      uid,
      limit: homePageSize,
      filter: _filter.hasActiveFilters ? _filter : null,
    );
    _items = List<TransactionEntity>.from(page.items)
      ..sort(TransactionEntity.compareNewestFirst);
    _totalCount = page.totalCount;
    _totalAmount = page.totalAmount;
    _invalidatePeriodCache();
    _hasMore = page.hasMore;
  }

  Future<void> _loadAllPeriodStats() async {
    await Future.wait([
      for (final period in HomePeriod.values) _loadPeriodStatsSafely(period),
    ]);
  }

  Future<void> _loadPeriodStatsSafely(HomePeriod period) async {
    try {
      await _loadPeriodStats(period);
    } catch (_) {
      // Keep other periods; UI falls back to zeros until refresh.
    }
  }

  Future<void> _loadPeriodStats(HomePeriod period) async {
    final range = _dateRangeFor(period);
    final stats = await _getPeriodStats(
      period: _periodApiValue(period),
      from: range.from,
      to: range.to,
    );
    _periodStats[period] = stats;
  }

  String _periodApiValue(HomePeriod period) {
    return switch (period) {
      HomePeriod.today => 'today',
      HomePeriod.thisWeek => 'week',
      HomePeriod.thisMonth => 'month',
    };
  }

  ({String from, String to}) _dateRangeFor(HomePeriod period) {
    final fmt = DateFormat('yyyy-MM-dd');
    final to = _startOfToday;
    final from = switch (period) {
      HomePeriod.today => _startOfToday,
      HomePeriod.thisWeek => _startOfWeek,
      HomePeriod.thisMonth => _startOfMonth,
    };
    return (from: fmt.format(from), to: fmt.format(to));
  }

  void setFilter(TransactionFilter filter) {
    _filter = filter;
    _invalidatePeriodCache();
    notifyListeners();
  }

  void clearFilter() {
    _filter = TransactionFilter.empty;
    _invalidatePeriodCache();
    notifyListeners();
  }

  void setAccountFilter(String? accountIdMasked) {
    _filter = accountIdMasked == null || accountIdMasked.isEmpty
        ? _filter.copyWith(clearAccountIdMasked: true)
        : _filter.copyWith(accountIdMasked: accountIdMasked);
    _invalidatePeriodCache();
    notifyListeners();
  }

  Map<String, List<TransactionEntity>> groupByDay() {
    final map = <String, List<TransactionEntity>>{};
    for (final t in periodItems) {
      map.putIfAbsent(t.transactionDate, () => []).add(t);
    }
    for (final txs in map.values) {
      txs.sort(TransactionEntity.compareNewestFirst);
    }
    final keys = map.keys.toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a);
        final db = DateTime.tryParse(b);
        if (da == null || db == null) return b.compareTo(a);
        return db.compareTo(da);
      });
    return {for (final k in keys) k: map[k]!};
  }

  Future<void> _loadPendingReviewCount(String uid) async {
    try {
      _pendingReviewCount = await _transactionRepository.getPendingReviewCount(
        uid,
      );
      notifyListeners();
    } catch (_) {
      // Non-fatal — banner simply stays hidden on failure.
    }
  }

  DateTime get _periodStart {
    switch (_period) {
      case HomePeriod.thisMonth:
        return _startOfMonth;
      case HomePeriod.thisWeek:
        return _startOfWeek;
      case HomePeriod.today:
        return _startOfToday;
    }
  }

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _startOfWeek {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  DateTime get _startOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime? _parseDate(TransactionEntity tx) {
    final parsed = DateTime.tryParse(tx.transactionDate);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);

    final fromDay = DateTime.tryParse(tx.day);
    if (fromDay != null) {
      return DateTime(fromDay.year, fromDay.month, fromDay.day);
    }

    return null;
  }

  List<TransactionEntity> _filtered(List<TransactionEntity> source) {
    if (!_filter.hasActiveFilters) return source;
    return source.where(_matches).toList();
  }

  bool _matches(TransactionEntity t) {
    final f = _filter;
    if (f.category != null &&
        f.category!.isNotEmpty &&
        t.category != f.category) {
      return false;
    }
    if (f.bank != null && f.bank!.isNotEmpty && t.bank != f.bank) {
      return false;
    }
    if (f.type != null && f.type!.isNotEmpty && t.type != f.type) {
      return false;
    }
    if (f.accountIdMasked != null &&
        f.accountIdMasked!.isNotEmpty &&
        t.accountIdMasked != f.accountIdMasked) {
      return false;
    }
    if (f.merchantQuery != null && f.merchantQuery!.trim().isNotEmpty) {
      final q = f.merchantQuery!.trim().toLowerCase();
      if (!t.merchant.toLowerCase().contains(q)) return false;
    }
    if (f.amountMin != null && t.amount < f.amountMin!) return false;
    if (f.amountMax != null && t.amount > f.amountMax!) return false;
    if (f.dateFrom != null) {
      final d = _parseDate(t);
      if (d == null || d.isBefore(f.dateFrom!)) return false;
    }
    if (f.dateTo != null) {
      final d = _parseDate(t);
      if (d == null || d.isAfter(f.dateTo!)) return false;
    }
    return true;
  }
}
