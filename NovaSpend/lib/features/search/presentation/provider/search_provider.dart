import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/core/constants/payment_methods.dart';
import 'package:nova_spend/core/provider/safe_change_notifier.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/domain/entities/transaction_sort.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/search/domain/usecases/search_transactions.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class SearchProvider extends SafeChangeNotifier {
  SearchProvider({
    required SearchTransactions searchTransactions,
    required SearchRepository searchRepository,
  }) : _searchTransactions = searchTransactions,
       _searchRepository = searchRepository;

  final SearchTransactions _searchTransactions;
  final SearchRepository _searchRepository;

  static const int pageSize = 20;

  SearchQuery query = SearchQuery.empty;
  List<TransactionEntity> results = [];
  List<String> recentSearches = [];
  List<String> paymentMethods = kPaymentMethods;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  bool hasSearched = false;
  String? error;

  /// Full-match totals from the first search page (not the loaded rows).
  int matchCount = 0;
  double matchSpent = 0;
  double matchReceived = 0;

  String? _uid;
  Timer? _debounce;
  Future<void>? _paymentMethodsFuture;

  /// Last item in server page order (before client-side sort).
  TransactionEntity? _pageCursor;

  Future<void> start(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    recentSearches = await _searchRepository.getRecentSearches();
    notifyListeners();
    unawaited(ensurePaymentMethods());
  }

  /// Reloads the current query if Activity has already been fetched.
  void reloadIfLoaded() {
    if (_uid == null || !hasSearched) return;
    unawaited(runSearch(saveRecent: false));
  }

  /// Loads the Activity list once if it has never been fetched.
  /// Does not clear filters — tab switches keep the last query.
  void ensureLoaded() {
    if (_uid == null || hasSearched) return;
    unawaited(runSearch(saveRecent: false));
  }

  /// Clears search text, date range, sort, and other filters, then reloads.
  void resetAllFilters() {
    if (query == SearchQuery.empty && hasSearched) return;
    query = SearchQuery.empty;
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  Future<void> ensurePaymentMethods() {
    return _paymentMethodsFuture ??= _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final items = await _searchRepository.listPaymentMethods();
      if (items.isEmpty) return;
      if (listEquals(paymentMethods, items)) return;
      paymentMethods = List<String>.unmodifiable(items);
      notifyListeners();
    } catch (_) {
      // Keep the canonical client catalog if the request fails.
    }
  }

  void setText(String text) {
    if (query.text == text) return;
    query = query.copyWith(text: text);
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(runSearch(saveRecent: false));
    });
  }

  void submitText(String text) {
    _debounce?.cancel();
    query = query.copyWith(text: text);
    unawaited(runSearch(saveRecent: true));
  }

  void setDateRange(DateRangeValue range) {
    if (range.sameAs(
      preset: query.datePreset,
      from: query.dateFrom,
      to: query.dateTo,
    )) {
      return;
    }
    query = query.copyWith(
      datePreset: range.preset,
      dateFrom: range.from,
      dateTo: range.to,
    );
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void clearDateRange() {
    if (!query.hasDateRange) return;
    query = query.copyWith(clearDateRange: true);
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void setCategories(List<String> categories) {
    final next = List<String>.unmodifiable([...categories]..sort());
    if (listEquals(query.categories, next)) return;
    query = query.copyWith(categories: next, clearCategories: next.isEmpty);
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void clearCategories() {
    if (!query.hasCategories) return;
    query = query.copyWith(clearCategories: true);
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void setSort(TransactionSort sort) {
    if (query.sort == sort) return;
    query = query.copyWith(sort: sort);
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void toggleDebits() {
    final next = !query.debitsOnly;
    query = query.copyWith(
      debitsOnly: next,
      creditsOnly: next ? false : query.creditsOnly,
    );
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void toggleCredits() {
    final next = !query.creditsOnly;
    query = query.copyWith(
      creditsOnly: next,
      debitsOnly: next ? false : query.debitsOnly,
    );
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void toggleSubscriptions() {
    query = query.copyWith(subscriptionsOnly: !query.subscriptionsOnly);
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void applySheetFilters({
    double? amountMin,
    double? amountMax,
    String? type,
    List<String> paymentMethods = const [],
    List<String> sources = const [],
    bool subscriptionsOnly = false,
  }) {
    final methods = List<String>.unmodifiable([...paymentMethods]..sort());
    final nextSources = List<String>.unmodifiable([...sources]..sort());
    final next = query.copyWith(
      amountMin: amountMin,
      amountMax: amountMax,
      clearAmountMin: amountMin == null,
      clearAmountMax: amountMax == null,
      debitsOnly: type == 'debit',
      creditsOnly: type == 'credit',
      paymentMethods: methods,
      clearPaymentMethods: methods.isEmpty,
      sources: nextSources,
      clearSources: nextSources.isEmpty,
      subscriptionsOnly: subscriptionsOnly,
    );
    if (next == query) return;
    query = next;
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void clearSheetFilters() {
    if (!query.hasSheetFilters) return;
    query = query.copyWith(
      clearAmountMin: true,
      clearAmountMax: true,
      debitsOnly: false,
      creditsOnly: false,
      clearPaymentMethods: true,
      clearSources: true,
      subscriptionsOnly: false,
    );
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void applyActivityFilters({
    required DateRangeValue range,
    List<String> categories = const [],
    bool subscriptionsOnly = false,
  }) {
    _debounce?.cancel();
    query = SearchQuery(
      datePreset: range.preset,
      dateFrom: range.from,
      dateTo: range.to,
      categories: List<String>.unmodifiable([...categories]..sort()),
      subscriptionsOnly: subscriptionsOnly,
    );
    notifyListeners();
    unawaited(runSearch(saveRecent: false));
  }

  void applyRecent(String term) {
    _debounce?.cancel();
    query = query.copyWith(text: term);
    notifyListeners();
    unawaited(runSearch(saveRecent: true));
  }

  Future<void> clearRecent() async {
    await _searchRepository.clearRecentSearches();
    recentSearches = [];
    notifyListeners();
  }

  Future<void> runSearch({required bool saveRecent}) async {
    final uid = _uid;
    if (uid == null) return;

    isLoading = true;
    hasSearched = true;
    error = null;
    notifyListeners();

    try {
      final page = await _searchTransactions(
        uid: uid,
        query: query,
        limit: pageSize,
        includeAggregates: true,
      );
      _pageCursor = page.items.isEmpty ? null : page.items.last;
      results = sortTransactions(page.items, query.sort);
      hasMore = page.hasMore;
      matchCount = page.totalCount ?? page.items.length;
      final fallback = _spendTotals(page.items);
      matchSpent = page.totalSpent ?? fallback.spent;
      matchReceived = page.totalReceived ?? fallback.received;

      if (saveRecent && query.hasText) {
        await _searchRepository.addRecentSearch(query.text);
        recentSearches = await _searchRepository.getRecentSearches();
      }
    } catch (e) {
      error = e.toString();
      results = [];
      _pageCursor = null;
      hasMore = false;
      matchCount = 0;
      matchSpent = 0;
      matchReceived = 0;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final uid = _uid;
    final cursor = _pageCursor;
    if (uid == null ||
        isLoading ||
        isLoadingMore ||
        !hasMore ||
        cursor == null) {
      return;
    }

    isLoadingMore = true;
    notifyListeners();

    try {
      final more = await _searchTransactions(
        uid: uid,
        query: query,
        limit: pageSize,
        startAfter: cursor,
      );
      if (more.items.isEmpty) {
        hasMore = false;
      } else {
        _pageCursor = more.items.last;
        final existing = results.map((e) => e.id).toSet();
        results = sortTransactions([
          ...results,
          ...more.items.where((t) => !existing.contains(t.id)),
        ], query.sort);
        hasMore = more.hasMore;
        error = null;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

({double spent, double received}) _spendTotals(List<TransactionEntity> txs) {
  var spent = 0.0;
  var received = 0.0;
  for (final t in txs) {
    if (t.type == 'credit') {
      received += t.amount;
    } else {
      spent += t.amount;
    }
  }
  return (spent: spent, received: received);
}
