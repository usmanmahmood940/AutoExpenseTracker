import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/get_transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/usecases/watch_transactions.dart';
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
}

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    required WatchTransactions watchTransactions,
    required GetTransactionsPage getTransactionsPage,
    required AnalyticsRepository analyticsRepository,
    required TransactionRepository transactionRepository,
  })  : _watchTransactions = watchTransactions,
        _getTransactionsPage = getTransactionsPage,
        _analyticsRepository = analyticsRepository,
        _transactionRepository = transactionRepository;

  final WatchTransactions _watchTransactions;
  final GetTransactionsPage _getTransactionsPage;
  final AnalyticsRepository _analyticsRepository;
  final TransactionRepository _transactionRepository;

  StreamSubscription<List<TransactionEntity>>? _subscription;
  StreamSubscription<MonthlySummaryEntity?>? _summarySub;
  StreamSubscription<List<TransactionEntity>>? _reviewSub;
  StreamSubscription<List<RawIngestionEntity>>? _needsParseSub;

  List<TransactionEntity> _items = [];
  TransactionFilter _filter = TransactionFilter.empty;
  HomePeriod _period = HomePeriod.thisWeek;
  MonthlySummaryEntity? _monthlySummary;
  int _pendingReviewCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _uid;

  List<TransactionEntity> get items => _filtered(_items);
  TransactionFilter get filter => _filter;
  HomePeriod get period => _period;
  int get pendingReviewCount => _pendingReviewCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
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
    final currency = _monthlySummary?.currency ??
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
    final start = _periodStart;
    TransactionEntity? best;
    for (final tx in _items) {
      final isCredit = tx.type == 'credit';
      if (isCredit != credit) continue;
      final date = _parseDate(tx);
      if (date == null || date.isBefore(start)) continue;
      if (best == null || tx.amount > best.amount) best = tx;
    }
    return best;
  }

  void start(String uid) {
    if (_uid == uid && _subscription != null) return;
    _uid = uid;
    _listenTransactions(uid);
    _listenMonthlySummary(uid);
    _listenPendingReview(uid);
  }

  void setPeriod(HomePeriod period) {
    if (_period == period) return;
    _period = period;
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
        limit: 100,
        filter: _filter.hasActiveFilters ? _filter : null,
      );
      _items = page;
      _hasMore = page.length >= 100;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final uid = _uid;
    if (uid == null || _isLoadingMore || !_hasMore || _items.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final more = await _getTransactionsPage(
        uid,
        limit: 50,
        startAfter: _items.last,
        filter: _filter.hasActiveFilters ? _filter : null,
      );
      if (more.isEmpty) {
        _hasMore = false;
      } else {
        final existingIds = _items.map((e) => e.id).toSet();
        _items = [..._items, ...more.where((t) => !existingIds.contains(t.id))];
        _hasMore = more.length >= 50;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void setFilter(TransactionFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearFilter() {
    _filter = TransactionFilter.empty;
    notifyListeners();
  }

  void setAccountFilter(String? accountIdMasked) {
    _filter = accountIdMasked == null || accountIdMasked.isEmpty
        ? _filter.copyWith(clearAccountIdMasked: true)
        : _filter.copyWith(accountIdMasked: accountIdMasked);
    notifyListeners();
  }

  Map<String, List<TransactionEntity>> groupByDay() {
    final map = <String, List<TransactionEntity>>{};
    for (final t in items) {
      map.putIfAbsent(t.transactionDate, () => []).add(t);
    }
    return map;
  }

  void _listenTransactions(String uid) {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _watchTransactions(uid, limit: 100).listen(
      (list) {
        _items = list;
        _isLoading = false;
        _hasMore = list.length >= 100;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenMonthlySummary(String uid) {
    _summarySub?.cancel();
    final yearMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _summarySub = _analyticsRepository.watchSummary(uid, yearMonth).listen(
      (summary) {
        _monthlySummary = summary;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  void _listenPendingReview(String uid) {
    _reviewSub?.cancel();
    _needsParseSub?.cancel();

    var lowConfidenceCount = 0;
    var needsParseCount = 0;

    void updateCount() {
      final next = lowConfidenceCount + needsParseCount;
      if (_pendingReviewCount != next) {
        _pendingReviewCount = next;
        notifyListeners();
      }
    }

    _reviewSub = _transactionRepository.watchNeedsReview(uid).listen(
      (list) {
        lowConfidenceCount = list.length;
        updateCount();
      },
      onError: (_) {},
    );

    _needsParseSub =
        _transactionRepository.watchIngestionsByStatus(uid, 'needs_parse').listen(
      (list) {
        needsParseCount = list.length;
        updateCount();
      },
      onError: (_) {},
    );
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
    if (fromDay != null) return DateTime(fromDay.year, fromDay.month, fromDay.day);

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
    _subscription?.cancel();
    _summarySub?.cancel();
    _reviewSub?.cancel();
    _needsParseSub?.cancel();
    super.dispose();
  }
}
