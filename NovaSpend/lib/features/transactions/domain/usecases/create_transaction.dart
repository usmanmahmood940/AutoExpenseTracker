import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class CreateTransaction {
  CreateTransaction(this._repository);

  final TransactionRepository _repository;

  Future<String> call({
    required String uid,
    required Map<String, dynamic> fields,
  }) {
    return _repository.createTransaction(uid: uid, fields: fields);
  }
}
