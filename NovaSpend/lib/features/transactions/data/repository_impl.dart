import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/transactions/data/datasource/backend_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/data/datasource/firestore_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({
    required FirestoreTransactionDatasource datasource,
    BackendTransactionDatasource? backend,
  })  : _datasource = datasource,
        _backend = backend;

  final FirestoreTransactionDatasource _datasource;
  final BackendTransactionDatasource? _backend;

  bool get _useBackend => AppConstants.kUseBackendV1 && _backend != null;

  @override
  Stream<List<TransactionEntity>> watchTransactions(
    String uid, {
    int limit = 50,
  }) {
    if (_useBackend) {
      return Stream.fromFuture(
        _backend!.getTransactionsPage(limit: limit).then((page) => page.items),
      );
    }
    return _datasource.watchTransactions(uid, limit: limit);
  }

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
      if (_useBackend) {
        return await _backend!.getTransactionsPage(
          limit: limit,
          startAfter: startAfter,
          filter: filter,
          dateFrom: dateFrom,
          dateTo: dateTo,
          sortBy: sortBy,
          orderBy: orderBy,
        );
      }
      return await _datasource.getTransactionsPage(
        uid,
        limit: limit,
        startAfter: startAfter,
        filter: filter,
        dateFrom: dateFrom,
        dateTo: dateTo,
        sortBy: sortBy,
        orderBy: orderBy,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<PeriodStatsEntity> getPeriodStats({
    required String period,
    required String from,
    required String to,
  }) async {
    try {
      if (_useBackend) {
        return await _backend!.getPeriodStats(
          period: period,
          from: from,
          to: to,
        );
      }
      return await _datasource.getPeriodStats(
        period: period,
        from: from,
        to: to,
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
      if (_useBackend) {
        await _backend!.updateTransaction(transactionId, fields);
        return;
      }
      await _datasource.updateTransaction(uid, transactionId, fields);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<TransactionEntity>> watchNeedsReview(String uid) {
    if (_useBackend) {
      return Stream.fromFuture(_backend!.getNeedsReview());
    }
    return _datasource.watchNeedsReview(uid);
  }

  @override
  Future<List<TransactionEntity>> getNeedsReview(
    String uid, {
    int limit = 50,
  }) async {
    try {
      if (_useBackend) {
        return await _backend!.getNeedsReview(limit: limit);
      }
      return await _datasource.getNeedsReview(uid, limit: limit);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<RawIngestionEntity>> watchIngestionsByStatus(
    String uid,
    String status,
  ) {
    if (_useBackend) {
      return Stream.fromFuture(_backend!.getIngestionsByStatus(status));
    }
    return _datasource.watchIngestionsByStatus(uid, status);
  }

  @override
  Future<List<RawIngestionEntity>> getIngestionsByStatus(
    String uid,
    String status, {
    int limit = 50,
  }) async {
    try {
      if (_useBackend) {
        return await _backend!.getIngestionsByStatus(status, limit: limit);
      }
      return await _datasource.getIngestionsByStatus(uid, status, limit: limit);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<int> getPendingReviewCount(String uid) {
    if (_useBackend) {
      return _backend!.getPendingReviewCount();
    }
    return _datasource.getPendingReviewCount(uid);
  }

  @override
  Future<String> createManualFromIngestion({
    required String uid,
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  }) async {
    try {
      if (_useBackend) {
        return await _backend!.createManualFromIngestion(
          ingestionId: ingestionId,
          transactionFields: transactionFields,
        );
      }
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
      if (_useBackend) {
        await _backend!.markReviewed(transactionId);
        return;
      }
      await _datasource.markReviewed(uid, transactionId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> softDelete(String uid, String transactionId) async {
    try {
      if (_useBackend) {
        await _backend!.softDelete(transactionId);
        return;
      }
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
    if (_useBackend) {
      // Ingest applies category from the transaction PATCH; no client override
      // table API yet.
      return;
    }
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

  @override
  Future<String?> getMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) async {
    if (_useBackend) return null;
    try {
      return await _datasource.getMerchantCategoryOverride(
        uid: uid,
        merchantKey: merchantKey,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) async {
    if (_useBackend) return;
    try {
      await _datasource.deleteMerchantCategoryOverride(
        uid: uid,
        merchantKey: merchantKey,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
