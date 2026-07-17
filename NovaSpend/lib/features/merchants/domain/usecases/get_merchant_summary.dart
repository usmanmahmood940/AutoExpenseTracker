import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/merchants/domain/repositories/merchant_repository.dart';

class GetMerchantSummary {
  GetMerchantSummary(this._repository);

  final MerchantRepository _repository;

  Future<MerchantSummaryEntity> call({
    required String uid,
    required String merchantNormalized,
    String? displayNameHint,
  }) {
    return _repository.getMerchantSummary(
      uid: uid,
      merchantNormalized: merchantNormalized,
      displayNameHint: displayNameHint,
    );
  }
}
