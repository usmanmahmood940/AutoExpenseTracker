import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/analytics/data/datasource/backend_analytics_datasource.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/recurring_merchant_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/trend_point_entity.dart';
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

  @override
  Future<MonthlySummaryEntity> getSummary(String uid, String yearMonth) {
    return _map(_backend.fetchSummary(yearMonth));
  }

  @override
  Future<MonthlySummaryEntity> getRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    return _map(_backend.fetchRange(from: from, to: to));
  }

  @override
  Future<List<TrendPointEntity>> getTrend(
    String uid, {
    required DateTime from,
    required DateTime to,
    String? bucket,
  }) {
    return _map(_backend.fetchTrend(from: from, to: to, bucket: bucket));
  }

  @override
  Future<List<RecurringMerchantEntity>> getRecurring(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    return _map(_backend.fetchRecurring(from: from, to: to));
  }

  @override
  Future<String?> getNarrative(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    return _map(_backend.fetchNarrative(from: from, to: to));
  }

  Future<T> _map<T>(Future<T> future) async {
    try {
      return await future;
    } catch (error) {
      throwAsFailure(error);
    }
  }
}
