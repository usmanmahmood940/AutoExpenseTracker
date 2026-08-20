import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/http/cloud_functions_http_client.dart';
import 'package:nova_spend/features/transactions/data/models/transaction_model.dart';
import 'package:nova_spend/features/transactions/domain/entities/period_stats_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';
import 'package:uuid/uuid.dart';

// RawIngestionModel lives in transaction_model.dart

class FirestoreTransactionDatasource {
  FirestoreTransactionDatasource({
    FirebaseFirestore? firestore,
    CloudFunctionsHttpClient? functionsClient,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functionsClient = functionsClient ?? CloudFunctionsHttpClient();

  final FirebaseFirestore _db;
  final CloudFunctionsHttpClient _functionsClient;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> _txs(String uid) => _db
      .collection(AppConstants.users)
      .doc(uid)
      .collection(AppConstants.transactions);

  CollectionReference<Map<String, dynamic>> _ingestions(String uid) => _db
      .collection(AppConstants.users)
      .doc(uid)
      .collection(AppConstants.rawIngestions);

  CollectionReference<Map<String, dynamic>> _overrides(String uid) => _db
      .collection(AppConstants.users)
      .doc(uid)
      .collection(AppConstants.merchantCategoryOverrides);

  Stream<List<TransactionEntity>> watchTransactions(
    String uid, {
    int limit = 50,
  }) {
    return _txs(uid)
        .orderBy('transactionDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return _newestFirst(
            snap.docs
                .map((d) => TransactionModel.fromFirestore(d).toEntity())
                .where((t) => t.status != 'deleted'),
          );
        });
  }

  Future<TransactionsPage> getTransactionsPage(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
  }) async {
    try {
      final response = await _functionsClient.call(
        'listTransactions',
        requireAuth: true,
        data: {
          'pageSize': limit,
          'includeAggregates': false,
          if (startAfter != null) 'cursor': startAfter.id,
        },
      );
      final rawItems = response['items'];
      if (rawItems is! List) {
        throw const ServerException('Invalid transaction page response');
      }
      var items = rawItems
          .whereType<Map>()
          .map((item) {
            final id = item['id'];
            final data = item['data'];
            if (id is! String || data is! Map) return null;
            return TransactionModel(
              id,
              Map<String, dynamic>.from(data),
            ).toEntity();
          })
          .whereType<TransactionEntity>()
          .toList()
        ..sort(TransactionEntity.compareNewestFirst);

      if (filter != null) {
        items = items.where((t) => _matchesFilter(t, filter)).toList();
      }

      if (items.length > limit) {
        items = items.take(limit).toList();
      }

      final totalCount =
          (response['totalCount'] as num?)?.toInt() ?? items.length;
      final totalAmount = (response['totalAmount'] as num?)?.toDouble() ?? 0;
      final hasMore =
          response['hasMore'] == true ||
          (response['nextCursor'] is String &&
              (response['nextCursor'] as String).isNotEmpty);

      return TransactionsPage(
        items: items,
        hasMore: hasMore,
        totalCount: totalCount,
        totalAmount: totalAmount,
      );
    } on CloudFunctionsHttpException catch (e) {
      throw ServerException(e.message);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load transactions');
    }
  }

  Future<PeriodStatsEntity> getPeriodStats({
    required String period,
    required String from,
    required String to,
  }) async {
    try {
      final response = await _functionsClient.call(
        'getPeriodStats',
        requireAuth: true,
        data: {
          'period': period,
          'from': from,
          'to': to,
        },
      );
      return _periodStatsFromResponse(response);
    } on CloudFunctionsHttpException catch (e) {
      throw ServerException(e.message);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load period stats');
    }
  }

  PeriodStatsEntity _periodStatsFromResponse(Map<String, dynamic> response) {
    PeriodHighlight? highlight(dynamic raw) {
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'];
      if (id is! String || id.isEmpty) return null;
      return PeriodHighlight(
        id: id,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        merchant: map['merchant'] as String? ?? '',
        merchantNormalized: map['merchantNormalized'] as String? ?? '',
        category: map['category'] as String? ?? 'Uncategorized',
        transactionDate: map['transactionDate'] as String? ?? '',
        type: map['type'] as String? ?? 'debit',
        currency: map['currency'] as String? ?? 'PKR',
      );
    }

    PeriodComparisonStats? comparison;
    final rawComparison = response['comparison'];
    if (rawComparison is Map) {
      final map = Map<String, dynamic>.from(rawComparison);
      comparison = PeriodComparisonStats(
        spentChangePercent:
            (map['spentChangePercent'] as num?)?.toDouble() ?? 0,
        receivedChangePercent:
            (map['receivedChangePercent'] as num?)?.toDouble() ?? 0,
        netChangePercent: (map['netChangePercent'] as num?)?.toDouble() ?? 0,
      );
    }

    return PeriodStatsEntity(
      period: response['period'] as String? ?? '',
      from: response['from'] as String? ?? '',
      to: response['to'] as String? ?? '',
      currency: response['currency'] as String? ?? 'PKR',
      spent: (response['spent'] as num?)?.toDouble() ?? 0,
      received: (response['received'] as num?)?.toDouble() ?? 0,
      net: (response['net'] as num?)?.toDouble() ?? 0,
      highestSpend: highlight(response['highestSpend']),
      highestReceive: highlight(response['highestReceive']),
      comparison: comparison,
    );
  }

  Stream<List<TransactionEntity>> watchNeedsReview(String uid) {
    return _txs(uid)
        .where('status', isEqualTo: 'needs_review')
        .orderBy('transactionDate', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
          return _newestFirst(
            snap.docs.map((d) => TransactionModel.fromFirestore(d).toEntity()),
          );
        });
  }

  Future<List<TransactionEntity>> getNeedsReview(
    String uid, {
    int limit = 50,
  }) async {
    try {
      final snap = await _txs(uid)
          .where('status', isEqualTo: 'needs_review')
          .orderBy('transactionDate', descending: true)
          .limit(limit)
          .get();
      return _newestFirst(
        snap.docs.map((d) => TransactionModel.fromFirestore(d).toEntity()),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load review queue');
    }
  }

  Future<int> getPendingReviewCount(String uid) async {
    final snapshots = await Future.wait([
      _txs(uid).where('status', isEqualTo: 'needs_review').count().get(),
      _ingestions(uid).where('status', isEqualTo: 'needs_parse').count().get(),
    ]);
    final reviewCount = snapshots[0].count ?? 0;
    final needsParseCount = snapshots[1].count ?? 0;
    return reviewCount + needsParseCount;
  }

  Stream<List<RawIngestionEntity>> watchIngestionsByStatus(
    String uid,
    String status,
  ) {
    return _ingestions(uid)
        .where('status', isEqualTo: status)
        .orderBy('receivedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => RawIngestionModel.fromFirestore(d).toEntity())
              .toList();
        });
  }

  Future<List<RawIngestionEntity>> getIngestionsByStatus(
    String uid,
    String status, {
    int limit = 50,
  }) async {
    try {
      final snap = await _ingestions(uid)
          .where('status', isEqualTo: status)
          .orderBy('receivedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => RawIngestionModel.fromFirestore(d).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load ingestions');
    }
  }

  Future<void> updateTransaction(
    String uid,
    String transactionId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(fields)
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await _txs(uid).doc(transactionId).update(payload);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update transaction');
    }
  }

  Future<String> createManualFromIngestion({
    required String uid,
    required String ingestionId,
    required Map<String, dynamic> transactionFields,
  }) async {
    try {
      final ingestionRef = _ingestions(uid).doc(ingestionId);
      final ingestionSnap = await ingestionRef.get();
      final ingestion = ingestionSnap.data() ?? {};
      final txId = _uuid.v4();
      final now = FieldValue.serverTimestamp();

      final txData = <String, dynamic>{
        'userId': uid,
        'currency': 'PKR',
        'merchantDetails': null,
        'categorySource': 'user',
        'paymentMethod': 'unknown',
        'bank': '',
        'accountId': '',
        'accountIdMasked': '',
        'branch': null,
        'transactionTime': '',
        'day': '',
        'externalId': null,
        'externalIdType': 'unknown',
        'dedupKey': 'manual_$txId',
        'smsSource': {
          'raw': ingestion['raw'] ?? '',
          'source': 'manual',
          'receivedAt': ingestion['receivedAt'] ?? now,
          if (ingestion['messageId'] != null)
            'messageId': ingestion['messageId'],
          if (ingestion['idempotencyKey'] != null)
            'idempotencyKey': ingestion['idempotencyKey'],
        },
        'parseConfidence': 1.0,
        'isAutoDetected': false,
        'isEdited': true,
        'isDuplicate': false,
        'isRecurring': false,
        'status': 'active',
        'reviewedAt': now,
        'createdAt': now,
        'updatedAt': now,
        ...transactionFields,
        'merchantNormalized': normalizeMerchantKey(
          (transactionFields['merchant'] as String?) ?? '',
        ),
      };

      final batch = _db.batch();
      batch.set(_txs(uid).doc(txId), txData);
      batch.update(ingestionRef, {
        'status': 'parsed',
        'transactionId': txId,
        'updatedAt': now,
      });
      await batch.commit();
      return txId;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create transaction');
    }
  }

  Future<void> markReviewed(String uid, String transactionId) async {
    await updateTransaction(uid, transactionId, {
      'reviewedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  Future<void> softDelete(String uid, String transactionId) async {
    await updateTransaction(uid, transactionId, {'status': 'deleted'});
  }

  Future<void> upsertMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
    required String displayName,
    required String category,
  }) async {
    try {
      final key = normalizeMerchantKey(merchantKey);
      if (key.isEmpty) return;
      final ref = _overrides(uid).doc(key);
      final existing = await ref.get();
      final now = FieldValue.serverTimestamp();
      await ref.set({
        'merchantKey': key,
        'displayName': displayName,
        'category': category,
        'updatedAt': now,
        if (!existing.exists) 'createdAt': now,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save merchant override');
    }
  }

  Future<String?> getMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) async {
    try {
      final key = normalizeMerchantKey(merchantKey);
      if (key.isEmpty) return null;
      final snap = await _overrides(uid).doc(key).get();
      if (!snap.exists) return null;
      final category = snap.data()?['category'] as String?;
      if (category == null || category.trim().isEmpty) return null;
      return category;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load merchant override');
    }
  }

  Future<void> deleteMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
  }) async {
    try {
      final key = normalizeMerchantKey(merchantKey);
      if (key.isEmpty) return;
      await _overrides(uid).doc(key).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete merchant override');
    }
  }

  List<TransactionEntity> _newestFirst(Iterable<TransactionEntity> items) {
    return items.toList()..sort(TransactionEntity.compareNewestFirst);
  }

  bool _matchesFilter(TransactionEntity t, TransactionFilter f) {
    if (f.category != null &&
        f.category!.isNotEmpty &&
        t.category != f.category) {
      return false;
    }
    if (f.bank != null && f.bank!.isNotEmpty && t.bank != f.bank) {
      return false;
    }
    if (f.type != null && f.type!.isNotEmpty && t.type != f.type) {
      return false;
    }
    if (f.accountIdMasked != null &&
        f.accountIdMasked!.isNotEmpty &&
        t.accountIdMasked != f.accountIdMasked) {
      return false;
    }
    if (f.merchantQuery != null && f.merchantQuery!.trim().isNotEmpty) {
      final q = f.merchantQuery!.trim().toLowerCase();
      if (!t.merchant.toLowerCase().contains(q)) return false;
    }
    if (f.amountMin != null && t.amount < f.amountMin!) return false;
    if (f.amountMax != null && t.amount > f.amountMax!) return false;
    if (f.dateFrom != null) {
      final d = DateTime.tryParse(t.transactionDate);
      if (d == null || d.isBefore(f.dateFrom!)) return false;
    }
    if (f.dateTo != null) {
      final d = DateTime.tryParse(t.transactionDate);
      if (d == null || d.isAfter(f.dateTo!)) return false;
    }
    return true;
  }
}
