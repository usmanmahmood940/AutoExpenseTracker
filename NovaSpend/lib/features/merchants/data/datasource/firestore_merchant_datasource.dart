import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/transactions/data/models/transaction_model.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class FirestoreMerchantDatasource {
  FirestoreMerchantDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _txs(String uid) => _db
      .collection(AppConstants.users)
      .doc(uid)
      .collection(AppConstants.transactions);

  Future<MerchantSummaryEntity> getMerchantSummary({
    required String uid,
    required String merchantNormalized,
    String? displayNameHint,
  }) async {
    final key = normalizeMerchantKey(merchantNormalized);
    final matches = await _collectMatching(
      uid: uid,
      merchantNormalized: key,
      maxScan: 500,
    );

    final debits = matches.where((t) => t.type == 'debit').toList();
    final currency = matches.isNotEmpty
        ? matches.first.currency
        : 'PKR';
    final displayName = matches.isNotEmpty
        ? matches.first.merchant
        : (displayNameHint ?? merchantNormalized);

    final totalSpent = debits.fold<double>(0, (acc, t) => acc + t.amount);
    final visitCount = debits.length;
    final averageSpent = visitCount == 0 ? 0.0 : totalSpent / visitCount;

    final yearMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final thisMonthDebits = debits.where((t) {
      final d = DateTime.tryParse(t.transactionDate);
      if (d == null) return false;
      return DateFormat('yyyy-MM').format(d) == yearMonth;
    }).toList();

    return MerchantSummaryEntity(
      merchantNormalized: key,
      displayName: displayName,
      currency: currency,
      totalSpent: totalSpent,
      visitCount: visitCount,
      averageSpent: averageSpent,
      thisMonthSpent:
          thisMonthDebits.fold<double>(0, (acc, t) => acc + t.amount),
      thisMonthVisits: thisMonthDebits.length,
    );
  }

  Future<List<TransactionEntity>> getMerchantTransactions({
    required String uid,
    required String merchantNormalized,
    int limit = 50,
    TransactionEntity? startAfter,
  }) async {
    final key = normalizeMerchantKey(merchantNormalized);

    // Prefer indexed query once Phase C writes merchantNormalized.
    try {
      Query<Map<String, dynamic>> query = _txs(uid)
          .where('merchantNormalized', isEqualTo: key)
          .orderBy('transactionDate', descending: true);

      if (startAfter != null) {
        query = query.startAfter([startAfter.transactionDate]);
      }

      final snap = await query.limit(limit).get();
      final indexed = snap.docs
          .map((d) => TransactionModel.fromFirestore(d).toEntity())
          .where((t) => t.status != 'deleted')
          .toList();

      // Non-empty indexed hit — field is populated.
      if (indexed.isNotEmpty) return indexed;

      // Empty first page may mean field not backfilled yet.
      if (startAfter != null) return indexed;
    } on FirebaseException {
      // Missing composite index — use client-side match.
    }

    return _getMerchantTransactionsClientSide(
      uid: uid,
      merchantNormalized: key,
      limit: limit,
      startAfter: startAfter,
    );
  }

  Future<List<TransactionEntity>> _getMerchantTransactionsClientSide({
    required String uid,
    required String merchantNormalized,
    required int limit,
    TransactionEntity? startAfter,
  }) async {
    try {
      final matches = <TransactionEntity>[];
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      var pages = 0;

      if (startAfter != null) {
        final startDoc = await _txs(uid).doc(startAfter.id).get();
        if (startDoc.exists) cursor = startDoc;
      }

      while (matches.length < limit && pages < 10) {
        Query<Map<String, dynamic>> query =
            _txs(uid).orderBy('transactionDate', descending: true);
        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }
        final snap = await query.limit(80).get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          final tx = TransactionModel.fromFirestore(doc).toEntity();
          if (tx.status == 'deleted') continue;
          if (_matchesMerchant(tx, merchantNormalized)) {
            matches.add(tx);
            if (matches.length >= limit) break;
          }
        }

        cursor = snap.docs.last;
        pages++;
        if (snap.docs.length < 80) break;
      }

      return matches;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load merchant transactions');
    }
  }

  Future<List<TransactionEntity>> _collectMatching({
    required String uid,
    required String merchantNormalized,
    required int maxScan,
  }) async {
    try {
      // Indexed path first.
      try {
        final snap = await _txs(uid)
            .where('merchantNormalized', isEqualTo: merchantNormalized)
            .orderBy('transactionDate', descending: true)
            .limit(maxScan)
            .get();
        final indexed = snap.docs
            .map((d) => TransactionModel.fromFirestore(d).toEntity())
            .where((t) => t.status != 'deleted')
            .toList();
        if (indexed.isNotEmpty) return indexed;
      } on FirebaseException {
        // Fall through to scan.
      }

      final matches = <TransactionEntity>[];
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      var scanned = 0;

      while (scanned < maxScan) {
        Query<Map<String, dynamic>> query =
            _txs(uid).orderBy('transactionDate', descending: true);
        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }
        final batchSize = (maxScan - scanned).clamp(1, 100);
        final snap = await query.limit(batchSize).get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          scanned++;
          final tx = TransactionModel.fromFirestore(doc).toEntity();
          if (tx.status == 'deleted') continue;
          if (_matchesMerchant(tx, merchantNormalized)) {
            matches.add(tx);
          }
        }

        cursor = snap.docs.last;
        if (snap.docs.length < batchSize) break;
      }

      return matches;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load merchant summary');
    }
  }

  bool _matchesMerchant(TransactionEntity tx, String merchantNormalized) {
    final stored = tx.merchantNormalized;
    if (stored != null && stored.isNotEmpty) {
      return normalizeMerchantKey(stored) == merchantNormalized;
    }
    return normalizeMerchantKey(tx.merchant) == merchantNormalized;
  }
}
