import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/search/data/datasource/firestore_search_datasource.dart';
import 'package:nova_spend/features/search/data/datasource/recent_searches_datasource.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required FirestoreSearchDatasource firestoreDatasource,
    required RecentSearchesDatasource recentSearchesDatasource,
  })  : _firestore = firestoreDatasource,
        _recent = recentSearchesDatasource;

  final FirestoreSearchDatasource _firestore;
  final RecentSearchesDatasource _recent;

  @override
  Future<List<TransactionEntity>> searchTransactions({
    required String uid,
    required SearchQuery query,
    int limit = 50,
    TransactionEntity? startAfter,
  }) async {
    try {
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
