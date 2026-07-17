import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

abstract class MerchantRepository {
  Future<MerchantSummaryEntity> getMerchantSummary({
    required String uid,
    required String merchantNormalized,
    String? displayNameHint,
  });

  Future<List<TransactionEntity>> getMerchantTransactions({
    required String uid,
    required String merchantNormalized,
    int limit = 50,
    TransactionEntity? startAfter,
  });
}
