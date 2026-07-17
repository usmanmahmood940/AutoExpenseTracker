import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class SearchTransactions {
  SearchTransactions(this._repository);

  final SearchRepository _repository;

  Future<List<TransactionEntity>> call({
    required String uid,
    required SearchQuery query,
    int limit = 50,
    TransactionEntity? startAfter,
  }) {
    return _repository.searchTransactions(
      uid: uid,
      query: query,
      limit: limit,
      startAfter: startAfter,
    );
  }
}
