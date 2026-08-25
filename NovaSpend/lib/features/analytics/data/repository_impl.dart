import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/analytics/data/datasource/backend_analytics_datasource.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl({
    required BackendAnalyticsDatasource backend,
  }) : _backend = backend;

  final BackendAnalyticsDatasource _backend;

  @override
  Stream<MonthlySummaryEntity?> watchSummary(String uid, String yearMonth) {
    return mapStreamFailures(_backend.watchSummary(yearMonth));
  }

  @override
  Stream<List<MonthlySummaryEntity>> watchRecentSummaries(
    String uid, {
    int limit = 6,
  }) {
    return mapStreamFailures(_backend.watchRecentSummaries(limit: limit));
  }
}
