import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class GetPeriodStats {
  GetPeriodStats(this._repository);

  final TransactionRepository _repository;

  Future<PeriodStatsEntity> call({
    required String period,
    required String from,
    required String to,
  }) {
    return _repository.getPeriodStats(
      period: period,
      from: from,
      to: to,
    );
  }
}
