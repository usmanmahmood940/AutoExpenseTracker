import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/transactions/data/datasource/backend_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/domain/entities/parsed_transaction_draft.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({required BackendTransactionDatasource backend})
    : _backend = backend;

  final BackendTransactionDatasource _backend;

  @override
  Future<TransactionsPage> getTransactionsPage(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
    String? dateFrom,
    String? dateTo,
    String sortBy = 'date',
    String orderBy = 'desc',
  }) async {
    try {
      return await _backend.getTransactionsPage(
        limit: limit,
        startAfter: startAfter,
        filter: filter,
        dateFrom: dateFrom,
        dateTo: dateTo,
        sortBy: sortBy,
        orderBy: orderBy,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<PeriodStatsEntity> getPeriodStats({
    required String period,
    required String from,
    required String to,
  }) async {
    try {
      return await _backend.getPeriodStats(period: period, from: from, to: to);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<void> updateTransaction(
    String uid,
    String transactionId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _backend.updateTransaction(transactionId, fields);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<List<TransactionEntity>> getNeedsReview(
    String uid, {
    int limit = 50,
  }) async {
    try {
      return await _backend.getNeedsReview(limit: limit);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<List<RawIngestionEntity>> getIngestionsByStatus(
    String uid,
    String status, {
    int limit = 50,
  }) async {
    try {
      return await _backend.getIngestionsByStatus(status, limit: limit);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<int> getPendingReviewCount(String uid) {
    return _backend.getPendingReviewCount();
  }

  @override
  Future<String> createManualFromIngestion({
    required String uid,
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  }) async {
    try {
      return await _backend.createManualFromIngestion(
        ingestionId: ingestionId,
        transactionFields: transactionFields,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<String> createTransaction({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    try {
      return await _backend.createTransaction(fields);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<ParsedTransactionDraft> parseText({
    required String uid,
    required String raw,
  }) async {
    try {
      return await _backend.parseText(raw);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<TransactionEntity> getTransaction(
    String uid,
    String transactionId,
  ) async {
    try {
      return await _backend.getTransaction(transactionId);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<void> markReviewed(String uid, String transactionId) async {
    try {
      await _backend.markReviewed(transactionId);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<void> softDelete(String uid, String transactionId) async {
    try {
      await _backend.softDelete(transactionId);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<void> upsertMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
    required String displayName,
    required String category,
  }) async {
    try {
      await _backend.upsertMerchantCategoryOverride(
        merchantKey: merchantKey,
        displayName: displayName,
        category: category,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<String?> getMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) async {
    try {
      return await _backend.getMerchantCategoryOverride(merchantKey);
    } catch (e) {
      throwAsFailure(e);
    }
  }

  @override
  Future<void> deleteMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) async {
    try {
      await _backend.deleteMerchantCategoryOverride(merchantKey);
    } catch (e) {
      throwAsFailure(e);
    }
  }
}
