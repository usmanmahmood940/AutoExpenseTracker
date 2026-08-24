import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';

class BackendTransactionDatasource {
  BackendTransactionDatasource({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<TransactionsPage> getTransactionsPage({
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
    String? dateFrom,
    String? dateTo,
    String sortBy = 'date',
    String orderBy = 'desc',
  }) async {
    try {
      final query = compactQuery({
        'limit': '$limit',
        'cursor': startAfter?.id,
        'date_from':
            dateFrom ??
            (filter?.dateFrom != null ? isoDate(filter!.dateFrom!) : null),
        'date_to':
            dateTo ??
            (filter?.dateTo != null ? isoDate(filter!.dateTo!) : null),
        'sort_by': sortBy,
        'order_by': orderBy,
        'type': filter?.type,
        'category': filter?.category,
        'bank': filter?.bank,
        'account_id_masked': filter?.accountIdMasked,
        'merchant_query': filter?.merchantQuery?.trim(),
        'amount_min': filter?.amountMin?.toString(),
        'amount_max': filter?.amountMax?.toString(),
      });
      final response = await _api.get(
        '/transactions',
        query: query,
        requireAuth: true,
      );
      final rawItems = response['items'];
      final items = rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => transactionFromApi(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <TransactionEntity>[];
      return TransactionsPage(
        items: items,
        hasMore:
            response['has_more'] == true ||
            (response['next_cursor'] is String &&
                (response['next_cursor'] as String).isNotEmpty),
        totalCount: (response['total_count'] as num?)?.toInt() ?? items.length,
        totalAmount: (response['total_amount'] as num?)?.toDouble() ?? 0,
      );
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<PeriodStatsEntity> getPeriodStats({
    required String period,
    required String from,
    required String to,
  }) async {
    try {
      final response = await _api.get(
        '/period-stats',
        query: compactQuery({'period': period, 'from': from, 'to': to}),
        requireAuth: true,
      );
      return periodStatsFromApi(response);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<void> updateTransaction(
    String transactionId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final body = transactionPatchFromClient(fields);
      if (body.isEmpty) return;
      await _api.patch(
        '/transactions/$transactionId',
        body: body,
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<void> markReviewed(String transactionId) async {
    try {
      await _api.post('/transactions/$transactionId/review', requireAuth: true);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<void> softDelete(String transactionId) async {
    try {
      await _api.delete('/transactions/$transactionId', requireAuth: true);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<String> createManualFromIngestion({
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  }) async {
    try {
      final created = await _api.post(
        '/transactions',
        body: transactionCreateFromClient(
          fields: transactionFields,
          ingestionId: ingestionId,
        ),
        requireAuth: true,
      );
      return created['id']?.toString() ?? '';
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<Map<String, dynamic>> getReviewQueue() async {
    try {
      return await _api.get('/review', requireAuth: true);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<List<TransactionEntity>> getNeedsReview({int limit = 50}) async {
    final queue = await getReviewQueue();
    final raw = queue['needs_review'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => transactionFromApi(Map<String, dynamic>.from(item)))
        .take(limit)
        .toList();
  }

  Future<List<RawIngestionEntity>> getIngestionsByStatus(
    String status, {
    int limit = 50,
  }) async {
    final queue = await getReviewQueue();
    final key = status == 'duplicate' ? 'duplicates' : 'needs_parse';
    final raw = queue[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ingestionFromApi(Map<String, dynamic>.from(item)))
        .where((item) => status == 'duplicate' || item.status == status)
        .take(limit)
        .toList();
  }

  Future<int> getPendingReviewCount() async {
    final queue = await getReviewQueue();
    return (queue['pending_count'] as num?)?.toInt() ?? 0;
  }

  String _overridePath(String merchantKey) {
    final key = normalizeMerchantKey(merchantKey);
    return '/merchants/${Uri.encodeComponent(key)}/category-override';
  }

  Future<void> upsertMerchantCategoryOverride({
    required String merchantKey,
    required String displayName,
    required String category,
  }) async {
    try {
      await _api.put(
        _overridePath(merchantKey),
        body: {'category': category, 'display_name': displayName},
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<String?> getMerchantCategoryOverride(String merchantKey) async {
    try {
      final json = await _api.get(
        _overridePath(merchantKey),
        requireAuth: true,
      );
      final category = json['category']?.toString();
      if (category == null || category.trim().isEmpty) return null;
      return category;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      throw e.toDataException();
    }
  }

  Future<void> deleteMerchantCategoryOverride(String merchantKey) async {
    try {
      await _api.delete(_overridePath(merchantKey), requireAuth: true);
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Future<List<TransactionEntity>> search({
    required String text,
    int limit = 50,
    String? cursor,
    String? dateFrom,
    String? dateTo,
    String? type,
    bool subscriptionsOnly = false,
    List<String>? categories,
  }) async {
    try {
      final response = await _api.get(
        '/transactions/search',
        query: compactQuery({
          'q': text,
          'limit': '$limit',
          'cursor': cursor,
          'date_from': dateFrom,
          'date_to': dateTo,
          'type': type,
          'subscriptions_only': subscriptionsOnly ? 'true' : null,
          'categories': categories == null || categories.isEmpty
              ? null
              : categories.join(','),
        }),
        requireAuth: true,
      );
      final rawItems = response['items'];
      if (rawItems is! List) return const [];
      return rawItems
          .whereType<Map>()
          .map((item) => transactionFromApi(Map<String, dynamic>.from(item)))
          .toList();
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }
}
