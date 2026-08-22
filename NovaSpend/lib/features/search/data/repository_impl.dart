import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/search/data/datasource/firestore_search_datasource.dart';
import 'package:nova_spend/features/search/data/datasource/recent_searches_datasource.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/transactions/data/datasource/backend_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required FirestoreSearchDatasource firestoreDatasource,
    required RecentSearchesDatasource recentSearchesDatasource,
    BackendTransactionDatasource? backend,
  })  : _firestore = firestoreDatasource,
        _recent = recentSearchesDatasource,
        _backend = backend;

  final FirestoreSearchDatasource _firestore;
  final RecentSearchesDatasource _recent;
  final BackendTransactionDatasource? _backend;

  @override
  Future<List<TransactionEntity>> searchTransactions({
    required String uid,
    required SearchQuery query,
    int limit = 50,
    TransactionEntity? startAfter,
  }) async {
    try {
      if (AppConstants.kUseBackendV1 && _backend != null) {
        if (!query.hasActiveFilters) return const [];
        return await _backend.search(
          text: query.text.trim(),
          limit: limit,
          cursor: startAfter?.id,
          dateFrom: query.dateFrom != null ? isoDate(query.dateFrom!) : null,
          dateTo: query.dateTo != null ? isoDate(query.dateTo!) : null,
          type: query.typeFilter,
          subscriptionsOnly: query.subscriptionsOnly,
        );
      }
      return await _firestore.search(
        uid: uid,
        query: query,
        limit: limit,
        startAfter: startAfter,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
