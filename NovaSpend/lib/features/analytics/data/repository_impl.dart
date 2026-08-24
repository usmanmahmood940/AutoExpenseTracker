import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/analytics/data/datasource/backend_analytics_datasource.dart';
import 'package:nova_spend/features/analytics/data/datasource/firestore_analytics_datasource.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl({
    required FirestoreAnalyticsDatasource datasource,
    BackendAnalyticsDatasource? backend,
  })  : _datasource = datasource,
        _backend = backend;

  final FirestoreAnalyticsDatasource _datasource;
  final BackendAnalyticsDatasource? _backend;

  bool get _useBackend => AppConstants.kUseBackendV1 && _backend != null;

  @override
  Stream<MonthlySummaryEntity?> watchSummary(String uid, String yearMonth) {
    final source = _useBackend
        ? _backend!.watchSummary(yearMonth)
        : _datasource.watchSummary(uid, yearMonth);
    return mapStreamFailures(source);
  }

  @override
  Stream<List<MonthlySummaryEntity>> watchRecentSummaries(
    String uid, {
    int limit = 6,
  }) {
    final source = _useBackend
        ? _backend!.watchRecentSummaries(limit: limit)
        : _datasource.watchRecentSummaries(uid, limit: limit);
    return mapStreamFailures(source);
  }
}
