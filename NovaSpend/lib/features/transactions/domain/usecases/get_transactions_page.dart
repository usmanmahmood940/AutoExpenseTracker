import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class GetTransactionsPage {
  GetTransactionsPage(this._repository);

  final TransactionRepository _repository;

  Future<List<TransactionEntity>> call(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
  }) {
    return _repository.getTransactionsPage(
      uid,
      limit: limit,
      startAfter: startAfter,
      filter: filter,
    );
  }
}
