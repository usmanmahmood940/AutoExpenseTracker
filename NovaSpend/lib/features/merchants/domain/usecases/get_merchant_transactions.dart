import 'package:nova_spend/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class GetMerchantTransactions {
  GetMerchantTransactions(this._repository);

  final MerchantRepository _repository;

  Future<List<TransactionEntity>> call({
    required String uid,
    required String merchantNormalized,
    int limit = 50,
    TransactionEntity? startAfter,
  }) {
    return _repository.getMerchantTransactions(
      uid: uid,
      merchantNormalized: merchantNormalized,
      limit: limit,
      startAfter: startAfter,
    );
  }
}
