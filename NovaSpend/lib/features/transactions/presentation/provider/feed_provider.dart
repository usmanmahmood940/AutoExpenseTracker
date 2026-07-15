import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/usecases/get_transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/usecases/watch_transactions.dart';

class FeedProvider extends ChangeNotifier {
  FeedProvider({
    required WatchTransactions watchTransactions,
    required GetTransactionsPage getTransactionsPage,
  })  : _watchTransactions = watchTransactions,
        _getTransactionsPage = getTransactionsPage;

  final WatchTransactions _watchTransactions;
  final GetTransactionsPage _getTransactionsPage;

  StreamSubscription<List<TransactionEntity>>? _subscription;

  List<TransactionEntity> _items = [];
  TransactionFilter _filter = TransactionFilter.empty;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _uid;

  List<TransactionEntity> get items => _filtered(_items);
  TransactionFilter get filter => _filter;
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

  void start(String uid) {
    if (_uid == uid && _subscription != null) return;
    _uid = uid;
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
      final d = DateTime.tryParse(t.transactionDate);
      if (d == null || d.isBefore(f.dateFrom!)) return false;
    }
    if (f.dateTo != null) {
      final d = DateTime.tryParse(t.transactionDate);
      if (d == null || d.isAfter(f.dateTo!)) return false;
    }
    return true;
  }

  Map<String, List<TransactionEntity>> groupByDay() {
    final map = <String, List<TransactionEntity>>{};
    for (final t in items) {
      map.putIfAbsent(t.transactionDate, () => []).add(t);
    }
    return map;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
