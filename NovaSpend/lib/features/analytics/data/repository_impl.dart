import 'package:nova_spend/features/analytics/data/datasource/firestore_analytics_datasource.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl({required FirestoreAnalyticsDatasource datasource})
      : _datasource = datasource;

  final FirestoreAnalyticsDatasource _datasource;

  @override
  Stream<MonthlySummaryEntity?> watchSummary(String uid, String yearMonth) {
    return _datasource.watchSummary(uid, yearMonth);
  }

  @override
  Stream<List<MonthlySummaryEntity>> watchRecentSummaries(
    String uid, {
    int limit = 6,
  }) {
    return _datasource.watchRecentSummaries(uid, limit: limit);
  }
}
