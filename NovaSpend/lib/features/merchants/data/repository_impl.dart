import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/merchants/data/datasource/backend_merchant_datasource.dart';
import 'package:nova_spend/features/merchants/data/datasource/firestore_merchant_datasource.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class MerchantRepositoryImpl implements MerchantRepository {
  MerchantRepositoryImpl({
    required FirestoreMerchantDatasource datasource,
    BackendMerchantDatasource? backend,
  })  : _datasource = datasource,
        _backend = backend;

  final FirestoreMerchantDatasource _datasource;
  final BackendMerchantDatasource? _backend;

  bool get _useBackend => AppConstants.kUseBackendV1 && _backend != null;

  @override
  Future<MerchantSummaryEntity> getMerchantSummary({
    required String uid,
    required String merchantNormalized,
    String? displayNameHint,
  }) async {
    try {
      if (_useBackend) {
        return await _backend!.getMerchantSummary(
          merchantNormalized: merchantNormalized,
        );
      }
      return await _datasource.getMerchantSummary(
        uid: uid,
        merchantNormalized: merchantNormalized,
        displayNameHint: displayNameHint,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
      if (_useBackend) {
        return await _backend!.getMerchantTransactions(
          merchantNormalized: merchantNormalized,
          limit: limit,
          startAfter: startAfter,
        );
      }
      return await _datasource.getMerchantTransactions(
        uid: uid,
        merchantNormalized: merchantNormalized,
        limit: limit,
        startAfter: startAfter,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
