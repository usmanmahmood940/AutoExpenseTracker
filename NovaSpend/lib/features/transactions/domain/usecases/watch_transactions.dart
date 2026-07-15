import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class WatchTransactions {
  WatchTransactions(this._repository);

  final TransactionRepository _repository;

  Stream<List<TransactionEntity>> call(String uid, {int limit = 50}) {
    return _repository.watchTransactions(uid, limit: limit);
  }
}
