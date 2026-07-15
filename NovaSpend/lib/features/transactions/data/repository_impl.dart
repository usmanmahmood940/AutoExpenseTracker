import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/transactions/data/datasource/firestore_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({required FirestoreTransactionDatasource datasource})
      : _datasource = datasource;

  final FirestoreTransactionDatasource _datasource;

  @override
  Stream<List<TransactionEntity>> watchTransactions(String uid, {int limit = 50}) {
    return _datasource.watchTransactions(uid, limit: limit);
  }

  @override
  Future<List<TransactionEntity>> getTransactionsPage(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
  }) async {
    try {
      return await _datasource.getTransactionsPage(
        uid,
        limit: limit,
        startAfter: startAfter,
        filter: filter,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateTransaction(
    String uid,
    String transactionId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _datasource.updateTransaction(uid, transactionId, fields);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<TransactionEntity>> watchNeedsReview(String uid) {
    return _datasource.watchNeedsReview(uid);
  }

  @override
  Stream<List<RawIngestionEntity>> watchIngestionsByStatus(
    String uid,
    String status,
  ) {
    return _datasource.watchIngestionsByStatus(uid, status);
  }

  @override
  Future<String> createManualFromIngestion({
    required String uid,
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  }) async {
    try {
      return await _datasource.createManualFromIngestion(
        uid: uid,
        ingestionId: ingestionId,
        transactionFields: transactionFields,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> markReviewed(String uid, String transactionId) async {
    try {
      await _datasource.markReviewed(uid, transactionId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> softDelete(String uid, String transactionId) async {
    try {
      await _datasource.softDelete(uid, transactionId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
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
      await _datasource.upsertMerchantCategoryOverride(
        uid: uid,
        merchantKey: merchantKey,
        displayName: displayName,
        category: category,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
