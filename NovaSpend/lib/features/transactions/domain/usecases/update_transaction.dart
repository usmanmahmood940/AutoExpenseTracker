import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class UpdateTransaction {
  UpdateTransaction(this._repository);

  final TransactionRepository _repository;

  Future<void> call(
    String uid,
    String transactionId,
    Map<String, dynamic> fields,
  ) {
    return _repository.updateTransaction(uid, transactionId, fields);
  }
}
