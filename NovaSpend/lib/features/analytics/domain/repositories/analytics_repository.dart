import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';

abstract class AnalyticsRepository {
  Stream<MonthlySummaryEntity?> watchSummary(String uid, String yearMonth);

  Stream<List<MonthlySummaryEntity>> watchRecentSummaries(
    String uid, {
    int limit = 6,
  });
}
