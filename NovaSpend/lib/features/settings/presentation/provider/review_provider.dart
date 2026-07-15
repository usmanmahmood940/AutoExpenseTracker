import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/mark_transaction_reviewed.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider({
    required TransactionRepository repository,
    required MarkTransactionReviewed markReviewed,
  })  : _repository = repository,
        _markReviewed = markReviewed;

  final TransactionRepository _repository;
  final MarkTransactionReviewed _markReviewed;

  StreamSubscription<List<TransactionEntity>>? _confidenceSub;
  StreamSubscription<List<RawIngestionEntity>>? _needsParseSub;
  StreamSubscription<List<RawIngestionEntity>>? _duplicateSub;

  List<TransactionEntity> lowConfidence = [];
  List<RawIngestionEntity> needsParse = [];
  List<RawIngestionEntity> duplicates = [];
  bool isLoading = true;
  String? error;
  String? _uid;

  void start(String uid) {
    _uid = uid;
    _confidenceSub?.cancel();
    _needsParseSub?.cancel();
    _duplicateSub?.cancel();
    isLoading = true;
    notifyListeners();

    _confidenceSub = _repository.watchNeedsReview(uid).listen((list) {
      lowConfidence = list;
      isLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });

    _needsParseSub =
        _repository.watchIngestionsByStatus(uid, 'needs_parse').listen((list) {
      needsParse = list;
      isLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });

    _duplicateSub =
        _repository.watchIngestionsByStatus(uid, 'duplicate').listen((list) {
      duplicates = list;
      isLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> confirm(TransactionEntity tx) async {
    final uid = _uid;
    if (uid == null) return;
    await _markReviewed(uid, tx.id);
  }

  Future<void> dismiss(TransactionEntity tx) async {
    final uid = _uid;
    if (uid == null) return;
    await _repository.softDelete(uid, tx.id);
  }

  Future<void> completeManually({
    required String ingestionId,
    required Map<String, dynamic> fields,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _repository.createManualFromIngestion(
      uid: uid,
      ingestionId: ingestionId,
      transactionFields: fields,
    );
  }

  @override
  void dispose() {
    _confidenceSub?.cancel();
    _needsParseSub?.cancel();
    _duplicateSub?.cancel();
    super.dispose();
  }
}
