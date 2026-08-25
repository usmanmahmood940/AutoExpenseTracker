import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/search/data/datasource/recent_searches_datasource.dart';
import 'package:nova_spend/features/search/domain/entities/search_page.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/transactions/data/datasource/backend_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required RecentSearchesDatasource recentSearchesDatasource,
    required BackendTransactionDatasource backend,
  }) : _recent = recentSearchesDatasource,
       _backend = backend;

  final RecentSearchesDatasource _recent;
  final BackendTransactionDatasource _backend;

  @override
  Future<SearchPage> searchTransactions({
    required String uid,
    required SearchQuery query,
    int limit = 50,
    TransactionEntity? startAfter,
    bool includeAggregates = false,
  }) async {
    try {
      return await _backend.search(
        text: query.text.trim(),
        limit: limit,
        cursor: startAfter?.id,
        dateFrom: query.dateFrom != null ? isoDate(query.dateFrom!) : null,
        dateTo: query.dateTo != null ? isoDate(query.dateTo!) : null,
        type: query.typeFilter,
        subscriptionsOnly: query.subscriptionsOnly,
        categories: query.hasCategories ? query.categories : null,
        amountMin: query.amountMin,
        amountMax: query.amountMax,
        paymentMethods: query.hasPaymentMethods ? query.paymentMethods : null,
        sources: query.hasSources ? query.sources : null,
        sortBy: query.sort.apiSortBy,
        orderBy: query.sort.apiOrderBy,
        includeAggregates: includeAggregates,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<List<String>> listPaymentMethods() async {
    try {
      return await _backend.listPaymentMethods();
    } catch (e) {
      throwAsFailure(e);
    }
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
