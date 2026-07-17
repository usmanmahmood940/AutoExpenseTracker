import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

abstract class SearchRepository {
  Future<List<TransactionEntity>> searchTransactions({
    required String uid,
    required SearchQuery query,
    int limit = 50,
    TransactionEntity? startAfter,
  });

  Future<List<String>> getRecentSearches();

  Future<void> addRecentSearch(String term);

  Future<void> clearRecentSearches();
}
