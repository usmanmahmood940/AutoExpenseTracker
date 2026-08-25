import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/merchants/data/datasource/backend_merchant_datasource.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class MerchantRepositoryImpl implements MerchantRepository {
  MerchantRepositoryImpl({
    required BackendMerchantDatasource backend,
  }) : _backend = backend;

  final BackendMerchantDatasource _backend;

  @override
  Future<MerchantSummaryEntity> getMerchantSummary({
    required String uid,
    required String merchantNormalized,
    String? displayNameHint,
  }) async {
    try {
      return await _backend.getMerchantSummary(
        merchantNormalized: merchantNormalized,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<List<TransactionEntity>> getMerchantTransactions({
    required String uid,
    required String merchantNormalized,
    int limit = 50,
    TransactionEntity? startAfter,
  }) async {
    try {
      return await _backend.getMerchantTransactions(
        merchantNormalized: merchantNormalized,
        limit: limit,
        startAfter: startAfter,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }
}
