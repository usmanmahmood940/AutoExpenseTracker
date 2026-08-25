import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/search/data/datasource/firestore_search_datasource.dart';
import 'package:nova_spend/features/search/data/datasource/recent_searches_datasource.dart';
import 'package:nova_spend/features/search/domain/entities/search_page.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/transactions/data/datasource/backend_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required FirestoreSearchDatasource firestoreDatasource,
    required RecentSearchesDatasource recentSearchesDatasource,
    BackendTransactionDatasource? backend,
  }) : _firestore = firestoreDatasource,
       _recent = recentSearchesDatasource,
       _backend = backend;

  final FirestoreSearchDatasource _firestore;
  final RecentSearchesDatasource _recent;
  final BackendTransactionDatasource? _backend;

  @override
  Future<SearchPage> searchTransactions({
    required String uid,
    required SearchQuery query,
    int limit = 50,
    TransactionEntity? startAfter,
    bool includeAggregates = false,
  }) async {
    try {
      if (AppConstants.kUseBackendV1 && _backend != null) {
        return await _backend.search(
          text: query.text.trim(),
          limit: limit,
          cursor: startAfter?.id,
          dateFrom: query.dateFrom != null ? isoDate(query.dateFrom!) : null,
          dateTo: query.dateTo != null ? isoDate(query.dateTo!) : null,
          type: query.typeFilter,
          subscriptionsOnly: query.subscriptionsOnly,
          categories: query.hasCategories ? query.categories : null,
          includeAggregates: includeAggregates,
        );
      }
      final items = await _firestore.search(
        uid: uid,
        query: query,
        limit: limit,
        startAfter: startAfter,
      );
      return _pageFromItems(
        items,
        limit: limit,
        includeAggregates: includeAggregates,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }

  SearchPage _pageFromItems(
    List<TransactionEntity> items, {
    required int limit,
    required bool includeAggregates,
  }) {
    var spent = 0.0;
    var received = 0.0;
    if (includeAggregates) {
      for (final t in items) {
        if (t.type == 'credit') {
          received += t.amount;
        } else {
          spent += t.amount;
        }
      }
    }
    return SearchPage(
      items: items,
      hasMore: items.length >= limit,
      totalCount: includeAggregates ? items.length : null,
      totalSpent: includeAggregates ? spent : null,
      totalReceived: includeAggregates ? received : null,
    );
  }

  @override
  Future<List<String>> getRecentSearches() async {
    return _recent.getRecent();
  }

  @override
  Future<void> addRecentSearch(String term) {
    return _recent.add(term);
  }

  @override
  Future<void> clearRecentSearches() {
    return _recent.clear();
  }
}
