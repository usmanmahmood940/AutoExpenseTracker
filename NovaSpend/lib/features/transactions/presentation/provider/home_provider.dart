import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
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
}

/// Max transactions fetched for the home preview feed.
const int homePageSize = 20;

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    required GetTransactionsPage getTransactionsPage,
    required AnalyticsRepository analyticsRepository,
    required TransactionRepository transactionRepository,
  }) : _getTransactionsPage = getTransactionsPage,
       _analyticsRepository = analyticsRepository,
       _transactionRepository = transactionRepository;

  final GetTransactionsPage _getTransactionsPage;
  final AnalyticsRepository _analyticsRepository;
  final TransactionRepository _transactionRepository;

  StreamSubscription<MonthlySummaryEntity?>? _summarySub;

  List<TransactionEntity> _items = [];
  TransactionFilter _filter = TransactionFilter.empty;
  HomePeriod _period = HomePeriod.thisWeek;
  MonthlySummaryEntity? _monthlySummary;
  int _pendingReviewCount = 0;
  int _totalCount = 0;
  double _totalAmount = 0;
  bool _isLoading = false;
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
  bool get hasMore => _hasMore;

  /// True when the currently selected period may have more transactions than
  /// the ones loaded in the 30-item preview. Used for the "Show more" button.
  bool get periodHasMore =>
      periodItems.length >= homePageSize && _hasMore;

  String? get error => _error;

  List<String> get availableAccounts {
    final set = <String>{};
    for (final t in _items) {
      if (t.accountIdMasked.isNotEmpty) set.add(t.accountIdMasked);
    }
    final list = set.toList()..sort();
    return list;
  }

  PeriodTotals get periodTotals {
    final currency =
        _monthlySummary?.currency ??
        (_items.isNotEmpty ? _items.first.currency : 'PKR');

    switch (_period) {
      case HomePeriod.thisMonth:
        final summary = _monthlySummary;
        if (summary != null) {
          return PeriodTotals(
            spent: summary.totalDebit,
            received: summary.totalCredit,
            currency: summary.currency,
          );
        }
        return _aggregateFrom(_startOfMonth, currency);
      case HomePeriod.thisWeek:
        return _aggregateFrom(_startOfWeek, currency);
      case HomePeriod.today:
        return _aggregateFrom(_startOfToday, currency);
    }
  }

  PeriodComparison get periodComparison {
    final current = _currentComparisonTotals;
    final previous = _previousComparisonTotals;

    return PeriodComparison(
      spentChangePercent: _percentChange(previous.spent, current.spent),
      receivedChangePercent: _percentChange(
        previous.received,
        current.received,
      ),
      netChangePercent: _percentChange(previous.net, current.net),
    );
  }

  PeriodTotals get _currentComparisonTotals {
    final currency = periodTotals.currency;
    switch (_period) {
      case HomePeriod.today:
        return _aggregateBetween(_startOfToday, _startOfToday, currency);
      case HomePeriod.thisWeek:
        return _aggregateBetween(_startOfWeek, _startOfToday, currency);
      case HomePeriod.thisMonth:
        return _aggregateBetween(_startOfMonth, _startOfToday, currency);
    }
  }

  PeriodTotals get _previousComparisonTotals {
    final currency = periodTotals.currency;
    switch (_period) {
      case HomePeriod.today:
        final yesterday = _startOfToday.subtract(const Duration(days: 1));
        return _aggregateBetween(yesterday, yesterday, currency);
      case HomePeriod.thisWeek:
        final weekStart = _startOfWeek;
        final daysElapsed = _startOfToday.difference(weekStart).inDays;
        final prevWeekStart = weekStart.subtract(const Duration(days: 7));
        final prevWeekEnd = prevWeekStart.add(Duration(days: daysElapsed));
        return _aggregateBetween(prevWeekStart, prevWeekEnd, currency);
      case HomePeriod.thisMonth:
        final now = DateTime.now();
        final prevMonthStart = DateTime(now.year, now.month - 1, 1);
        final lastDayPrevMonth = DateTime(now.year, now.month, 0);
        final sameDayPrevMonth = DateTime(now.year, now.month - 1, now.day);
        final prevMonthEnd = sameDayPrevMonth.isAfter(lastDayPrevMonth)
            ? lastDayPrevMonth
            : sameDayPrevMonth;
        return _aggregateBetween(prevMonthStart, prevMonthEnd, currency);
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

  /// Largest debit transaction within the selected period, or null if none.
  TransactionEntity? get highestSpend => _extremeInPeriod(credit: false);

  /// Largest credit transaction within the selected period, or null if none.
  TransactionEntity? get highestReceive => _extremeInPeriod(credit: true);

  TransactionEntity? _extremeInPeriod({required bool credit}) {
    TransactionEntity? best;
    for (final tx in periodItems) {
      final isCredit = tx.type == 'credit';
      if (isCredit != credit) continue;
      if (best == null || tx.amount > best.amount) best = tx;
    }
    return best;
  }

  void start(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    unawaited(refresh());
    _listenMonthlySummary(uid);
    unawaited(_loadPendingReviewCount(uid));
  }

  void setPeriod(HomePeriod period) {
    if (_period == period) return;
    _period = period;
    _invalidatePeriodCache();
    notifyListeners();
  }

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final page = await _getTransactionsPage(
        uid,
        limit: homePageSize,
        filter: _filter.hasActiveFilters ? _filter : null,
      );
      _items = page.items;
      _totalCount = page.totalCount;
      _totalAmount = page.totalAmount;
      _invalidatePeriodCache();
      _hasMore = page.hasMore;
      _error = null;
      unawaited(_loadPendingReviewCount(uid));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    final keys = map.keys.toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a);
        final db = DateTime.tryParse(b);
        if (da == null || db == null) return b.compareTo(a);
        return db.compareTo(da);
      });
    return {for (final k in keys) k: map[k]!};
  }

  void _listenMonthlySummary(String uid) {
    _summarySub?.cancel();
    final yearMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _summarySub = _analyticsRepository.watchSummary(uid, yearMonth).listen((
      summary,
    ) {
      _monthlySummary = summary;
      notifyListeners();
    }, onError: (_) {});
  }

  Future<void> _loadPendingReviewCount(String uid) async {
    try {
      final count = await _transactionRepository.getPendingReviewCount(uid);
      if (_uid != uid || _pendingReviewCount == count) return;
      _pendingReviewCount = count;
      notifyListeners();
    } catch (_) {
      // The badge is non-critical; the review screen will surface any errors.
    }
  }

  PeriodTotals _aggregateFrom(DateTime startInclusive, String currency) {
    var spent = 0.0;
    var received = 0.0;

    for (final tx in _items) {
      final date = _parseDate(tx);
      if (date == null || date.isBefore(startInclusive)) continue;
      if (tx.type == 'credit') {
        received += tx.amount;
      } else {
        spent += tx.amount;
      }
    }

    return PeriodTotals(spent: spent, received: received, currency: currency);
  }

  PeriodTotals _aggregateBetween(
    DateTime startInclusive,
    DateTime endInclusive,
    String currency,
  ) {
    var spent = 0.0;
    var received = 0.0;

    for (final tx in _items) {
      final date = _parseDate(tx);
      if (date == null) continue;
      if (date.isBefore(startInclusive) || date.isAfter(endInclusive)) continue;
      if (tx.type == 'credit') {
        received += tx.amount;
      } else {
        spent += tx.amount;
      }
    }

    return PeriodTotals(spent: spent, received: received, currency: currency);
  }

  double? _percentChange(double previous, double current) {
    if (previous == 0) {
      if (current == 0) return 0;
      return 100;
    }
    return ((current - previous) / previous.abs()) * 100;
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
    if (fromDay != null)
      return DateTime(fromDay.year, fromDay.month, fromDay.day);

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

  @override
  void dispose() {
    _summarySub?.cancel();
    super.dispose();
  }
}
