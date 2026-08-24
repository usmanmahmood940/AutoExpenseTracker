import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/domain/entities/transaction_sort.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/search/domain/usecases/search_transactions.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider({
    required SearchTransactions searchTransactions,
    required SearchRepository searchRepository,
  }) : _searchTransactions = searchTransactions,
       _searchRepository = searchRepository;

  final SearchTransactions _searchTransactions;
  final SearchRepository _searchRepository;

  SearchQuery query = SearchQuery.empty;
  List<TransactionEntity> results = [];
  List<String> recentSearches = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  bool hasSearched = false;
  String? error;

  String? _uid;
  Timer? _debounce;

  Future<void> start(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    recentSearches = await _searchRepository.getRecentSearches();
    notifyListeners();
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

  void setSort(TransactionSort sort) {
    if (query.sort == sort) return;
    query = query.copyWith(sort: sort);
    if (results.isNotEmpty) {
      results = sortTransactions(results, sort);
    }
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
      final page = await _searchTransactions(uid: uid, query: query, limit: 50);
      results = sortTransactions(page, query.sort);
      hasMore = page.length >= 50;

      if (saveRecent && query.hasText) {
        await _searchRepository.addRecentSearch(query.text);
        recentSearches = await _searchRepository.getRecentSearches();
      }
    } catch (e) {
      error = e.toString();
      results = [];
      hasMore = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final uid = _uid;
    if (uid == null || isLoadingMore || !hasMore || results.isEmpty) {
      return;
    }

    isLoadingMore = true;
    notifyListeners();

    try {
      final more = await _searchTransactions(
        uid: uid,
        query: query,
        limit: 50,
        startAfter: results.last,
      );
      if (more.isEmpty) {
        hasMore = false;
      } else {
        final existing = results.map((e) => e.id).toSet();
        results = sortTransactions([
          ...results,
          ...more.where((t) => !existing.contains(t.id)),
        ], query.sort);
        hasMore = more.length >= 50;
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
