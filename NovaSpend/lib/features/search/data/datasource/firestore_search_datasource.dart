import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/features/search/domain/entities/search_query.dart';
import 'package:nova_spend/features/transactions/data/models/transaction_model.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class FirestoreSearchDatasource {
  FirestoreSearchDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _txs(String uid) => _db
      .collection(AppConstants.users)
      .doc(uid)
      .collection(AppConstants.transactions);

  Future<List<TransactionEntity>> search({
    required String uid,
    required SearchQuery query,
    int limit = 50,
    TransactionEntity? startAfter,
  }) async {
    if (!query.hasActiveFilters) return const [];

    // Prefer indexed merchant prefix when text-only (or text + soft filters).
    if (query.hasText &&
        !query.subscriptionsOnly &&
        query.typeFilter == null &&
        !query.thisMonth) {
      try {
        final prefix = normalizeMerchantKey(query.text);
        if (prefix.isNotEmpty) {
          Query<Map<String, dynamic>> q = _txs(uid)
              .where('merchantNormalized', isGreaterThanOrEqualTo: prefix)
              .where('merchantNormalized', isLessThan: '$prefix\uf8ff')
              .orderBy('merchantNormalized')
              .orderBy('transactionDate', descending: true);

          if (startAfter != null) {
            q = q.startAfter([
              startAfter.resolvedMerchantKey,
              startAfter.transactionDate,
            ]);
          }

          final snap = await q.limit(limit).get();
          final indexed = snap.docs
              .map((d) => TransactionModel.fromFirestore(d).toEntity())
              .where((t) => t.status != 'deleted')
              .toList();
          if (indexed.isNotEmpty) return indexed;
        }
      } on FirebaseException {
        // Fall through to client-side scan.
      }
    }

    return _searchClientSide(
      uid: uid,
      query: query,
      limit: limit,
      startAfter: startAfter,
    );
  }

  Future<List<TransactionEntity>> _searchClientSide({
    required String uid,
    required SearchQuery query,
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

      Query<Map<String, dynamic>> base() {
        Query<Map<String, dynamic>> q = _txs(uid);

        // Apply one structured equality filter when possible to reduce scan size.
        if (query.subscriptionsOnly) {
          q = q.where('isRecurring', isEqualTo: true);
        } else if (query.typeFilter != null) {
          q = q.where('type', isEqualTo: query.typeFilter);
        }

        return q.orderBy('transactionDate', descending: true);
      }

      while (matches.length < limit && pages < 12) {
        Query<Map<String, dynamic>> q = base();
        if (cursor != null) {
          q = q.startAfterDocument(cursor);
        }

        final snap = await q.limit(80).get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          final tx = TransactionModel.fromFirestore(doc).toEntity();
          if (tx.status == 'deleted') continue;
          if (_matches(tx, query)) {
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
      // Missing index for structured filter — plain date scan + client filter.
      if (e.code == 'failed-precondition') {
        return _scanAllClientSide(
          uid: uid,
          query: query,
          limit: limit,
          startAfter: startAfter,
        );
      }
      throw ServerException(e.message ?? 'Search failed');
    }
  }

  Future<List<TransactionEntity>> _scanAllClientSide({
    required String uid,
    required SearchQuery query,
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

      while (matches.length < limit && pages < 12) {
        Query<Map<String, dynamic>> q =
            _txs(uid).orderBy('transactionDate', descending: true);
        if (cursor != null) {
          q = q.startAfterDocument(cursor);
        }

        final snap = await q.limit(80).get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          final tx = TransactionModel.fromFirestore(doc).toEntity();
          if (tx.status == 'deleted') continue;
          if (_matches(tx, query)) {
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
      throw ServerException(e.message ?? 'Search failed');
    }
  }

  bool _matches(TransactionEntity tx, SearchQuery query) {
    if (query.subscriptionsOnly && !tx.isRecurring) return false;

    final type = query.typeFilter;
    if (type != null && tx.type != type) return false;

    if (query.thisMonth) {
      final d = DateTime.tryParse(tx.transactionDate);
      if (d == null) return false;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      if (d.isBefore(start)) return false;
    }

    if (query.hasText) {
      final q = query.text.trim().toLowerCase();
      final merchant = tx.merchant.toLowerCase();
      final normalized = tx.resolvedMerchantKey;
      final category = tx.category.toLowerCase();
      final bank = tx.bank.toLowerCase();
      if (!merchant.contains(q) &&
          !normalized.contains(q) &&
          !category.contains(q) &&
          !bank.contains(q)) {
        return false;
      }
    }

    return true;
  }
}
