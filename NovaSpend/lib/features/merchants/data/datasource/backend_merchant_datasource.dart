import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class BackendMerchantDatasource {
  BackendMerchantDatasource({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<MerchantSummaryEntity> getMerchantSummary({
    required String merchantNormalized,
  }) async {
    try {
      final key = Uri.encodeComponent(normalizeMerchantKey(merchantNormalized));
      final json = await _api.get('/merchants/$key', requireAuth: true);
      return merchantSummaryFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<List<TransactionEntity>> getMerchantTransactions({
    required String merchantNormalized,
    int limit = 50,
    TransactionEntity? startAfter,
  }) async {
    try {
      final key = Uri.encodeComponent(normalizeMerchantKey(merchantNormalized));
      final json = await _api.get(
        '/merchants/$key/transactions',
        query: compactQuery({
          'limit': '$limit',
          'cursor': startAfter?.id,
        }),
        requireAuth: true,
      );
      final rawItems = json['items'];
      if (rawItems is! List) return const [];
      return rawItems
          .whereType<Map>()
          .map((item) => transactionFromApi(Map<String, dynamic>.from(item)))
          .toList();
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }
}
