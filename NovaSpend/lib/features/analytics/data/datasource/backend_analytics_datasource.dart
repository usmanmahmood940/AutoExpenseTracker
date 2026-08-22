import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/analytics/domain/entities/monthly_summary_entity.dart';

class BackendAnalyticsDatasource {
  BackendAnalyticsDatasource({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Stream<MonthlySummaryEntity?> watchSummary(String yearMonth) async* {
    try {
      final json = await _api.get(
        '/analytics/summary',
        query: compactQuery({'year_month': yearMonth}),
        requireAuth: true,
      );
      yield monthlySummaryFromApi(json);
    } on ApiException catch (e) {
      throw ServerException(e.message);
    }
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
      throw ServerException(e.message);
    }
  }
}
