import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/recurring_merchant_entity.dart';
import 'package:nova_spend/features/analytics/domain/entities/trend_point_entity.dart';

class BackendAnalyticsDatasource {
  BackendAnalyticsDatasource({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Stream<MonthlySummaryEntity?> watchSummary(String yearMonth) async* {
    yield await fetchSummary(yearMonth);
  }

  Stream<List<MonthlySummaryEntity>> watchRecentSummaries({
    int limit = 6,
  }) async* {
    try {
      final json = await _api.get(
        '/analytics/summaries',
        query: compactQuery({'limit': '$limit'}),
        requireAuth: true,
      );
      final raw = json['items'];
      if (raw is! List) {
        yield const [];
        return;
      }
      yield raw
          .whereType<Map>()
          .map((item) => monthlySummaryFromApi(Map<String, dynamic>.from(item)))
          .toList();
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<MonthlySummaryEntity> fetchSummary(String yearMonth) async {
    try {
      final json = await _api.get(
        '/analytics/summary',
        query: compactQuery({'year_month': yearMonth}),
        requireAuth: true,
      );
      return monthlySummaryFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<MonthlySummaryEntity> fetchRange({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final json = await _api.get(
        '/analytics/range',
        query: compactQuery({
          'from': isoDate(from),
          'to': isoDate(to),
        }),
        requireAuth: true,
      );
      return monthlySummaryFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<List<TrendPointEntity>> fetchTrend({
    required DateTime from,
    required DateTime to,
    String? bucket,
  }) async {
    try {
      final json = await _api.get(
        '/analytics/trend',
        query: compactQuery({
          'from': isoDate(from),
          'to': isoDate(to),
          'bucket': bucket,
        }),
        requireAuth: true,
      );
      return trendPointsFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<List<RecurringMerchantEntity>> fetchRecurring({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final json = await _api.get(
        '/analytics/recurring',
        query: compactQuery({
          'from': isoDate(from),
          'to': isoDate(to),
        }),
        requireAuth: true,
      );
      return recurringMerchantsFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<String?> fetchNarrative({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final json = await _api.get(
        '/analytics/narrative',
        query: compactQuery({
          'from': isoDate(from),
          'to': isoDate(to),
        }),
        requireAuth: true,
      );
      return narrativeFromApi(json);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }
}
