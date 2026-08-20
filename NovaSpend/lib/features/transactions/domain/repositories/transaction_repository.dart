import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';

abstract class TransactionRepository {
  Stream<List<TransactionEntity>> watchTransactions(
    String uid, {
    int limit = 50,
  });

  Future<TransactionsPage> getTransactionsPage(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
  });

  /// Period overview + highlights from the getPeriodStats cloud function.
  Future<PeriodStatsEntity> getPeriodStats({
    required String period,
    required String from,
    required String to,
  });

  Future<void> updateTransaction(
    String uid,
    String transactionId,
    Map<String, dynamic> fields,
  );

  Stream<List<TransactionEntity>> watchNeedsReview(String uid);

  /// One-shot review queue page (no long-lived listener).
  Future<List<TransactionEntity>> getNeedsReview(String uid, {int limit = 50});

  Stream<List<RawIngestionEntity>> watchIngestionsByStatus(
    String uid,
    String status,
  );

  /// One-shot ingestion queue page (no long-lived listener).
  Future<List<RawIngestionEntity>> getIngestionsByStatus(
    String uid,
    String status, {
    int limit = 50,
  });

  /// Count review items once without opening long-lived collection listeners.
  Future<int> getPendingReviewCount(String uid);

  Future<String> createManualFromIngestion({
    required String uid,
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  });

  Future<void> markReviewed(String uid, String transactionId);

  Future<void> softDelete(String uid, String transactionId);

  Future<void> upsertMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
    required String displayName,
    required String category,
  });

  /// Returns the remembered category for [merchantKey], or null if none.
  Future<String?> getMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  });

  Future<void> deleteMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  });
}
