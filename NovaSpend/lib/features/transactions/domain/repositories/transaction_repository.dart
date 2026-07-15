import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';

abstract class TransactionRepository {
  Stream<List<TransactionEntity>> watchTransactions(String uid, {int limit = 50});

  Future<List<TransactionEntity>> getTransactionsPage(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
  });

  Future<void> updateTransaction(
    String uid,
    String transactionId,
    Map<String, dynamic> fields,
  );

  Stream<List<TransactionEntity>> watchNeedsReview(String uid);

  Stream<List<RawIngestionEntity>> watchIngestionsByStatus(
    String uid,
    String status,
  );

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
}
