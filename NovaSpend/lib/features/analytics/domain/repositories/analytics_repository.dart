import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/recurring_merchant_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/trend_point_entity.dart';

abstract class AnalyticsRepository {
  Stream<MonthlySummaryEntity?> watchSummary(String uid, String yearMonth);

  Stream<List<MonthlySummaryEntity>> watchRecentSummaries(
    String uid, {
    int limit = 6,
  });

  Future<MonthlySummaryEntity> getSummary(String uid, String yearMonth);

  Future<MonthlySummaryEntity> getRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  });

  Future<List<TrendPointEntity>> getTrend(
    String uid, {
    required DateTime from,
    required DateTime to,
    String? bucket,
  });

  Future<List<RecurringMerchantEntity>> getRecurring(
    String uid, {
    required DateTime from,
    required DateTime to,
  });

  Future<String?> getNarrative(
    String uid, {
    required DateTime from,
    required DateTime to,
  });
}
