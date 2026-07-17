import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/features/transactions/data/models/transaction_model.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:uuid/uuid.dart';

// RawIngestionModel lives in transaction_model.dart


class FirestoreTransactionDatasource {
  FirestoreTransactionDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
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
      return snap.docs
          .map((d) => TransactionModel.fromFirestore(d).toEntity())
          .where((t) => t.status != 'deleted')
          .toList();
    });
  }

  Future<List<TransactionEntity>> getTransactionsPage(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _txs(uid).orderBy('transactionDate', descending: true);

      if (startAfter != null) {
        query = query.startAfter([startAfter.transactionDate]);
      }

      // Over-fetch so client filters still yield a usable page.
      final snap = await query.limit(limit * 3).get();
      var items = snap.docs
          .map((d) => TransactionModel.fromFirestore(d).toEntity())
          .where((t) => t.status != 'deleted')
          .toList();

      if (filter != null) {
        items = items.where((t) => _matchesFilter(t, filter)).toList();
      }

      if (items.length > limit) {
        items = items.take(limit).toList();
      }
      return items;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load transactions');
    }
  }

  Stream<List<TransactionEntity>> watchNeedsReview(String uid) {
    return _txs(uid)
        .orderBy('transactionDate', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => TransactionModel.fromFirestore(d).toEntity())
          .where(
            (t) =>
                t.status != 'deleted' &&
                t.parseConfidence < AppConstants.confidenceReviewThreshold &&
                t.reviewedAt == null,
          )
          .toList();
    });
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
        'paymentMethod': '',
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
          if (ingestion['messageId'] != null) 'messageId': ingestion['messageId'],
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
    await updateTransaction(uid, transactionId, {
      'status': 'deleted',
    });
  }

  Future<void> upsertMerchantCategoryOverride({
    required String uid,
    required String merchantKey,
    required String displayName,
    required String category,
  }) async {
    try {
      final key = normalizeMerchantKey(merchantKey);
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
