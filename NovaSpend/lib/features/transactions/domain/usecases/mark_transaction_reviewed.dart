import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class MarkTransactionReviewed {
  MarkTransactionReviewed(this._repository);

  final TransactionRepository _repository;

  Future<void> call(String uid, String transactionId) {
    return _repository.markReviewed(uid, transactionId);
  }
}
