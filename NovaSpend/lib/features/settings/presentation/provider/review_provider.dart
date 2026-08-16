import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/mark_transaction_reviewed.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider({
    required TransactionRepository repository,
    required MarkTransactionReviewed markReviewed,
  }) : _repository = repository,
       _markReviewed = markReviewed;

  final TransactionRepository _repository;
  final MarkTransactionReviewed _markReviewed;

  List<TransactionEntity> lowConfidence = [];
  List<RawIngestionEntity> needsParse = [];
  List<RawIngestionEntity> duplicates = [];
  bool isLoading = true;
  String? error;
  String? _uid;

  void start(String uid) {
    _uid = uid;
    refresh();
  }

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final review = await _repository.getNeedsReview(uid, limit: 50);
      final parse = await _repository.getIngestionsByStatus(
        uid,
        'needs_parse',
        limit: 50,
      );
      final dups = await _repository.getIngestionsByStatus(
        uid,
        'duplicate',
        limit: 50,
      );
      lowConfidence = review;
      needsParse = parse;
      duplicates = dups;
    } catch (e) {
      error = e.toString();
      lowConfidence = [];
      needsParse = [];
      duplicates = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirm(TransactionEntity tx) async {
    final uid = _uid;
    if (uid == null) return;
    await _markReviewed(uid, tx.id);
    lowConfidence = lowConfidence.where((item) => item.id != tx.id).toList();
    notifyListeners();
  }

  Future<void> dismiss(TransactionEntity tx) async {
    final uid = _uid;
    if (uid == null) return;
    await _repository.softDelete(uid, tx.id);
    lowConfidence = lowConfidence.where((item) => item.id != tx.id).toList();
    notifyListeners();
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
    needsParse = needsParse.where((item) => item.id != ingestionId).toList();
    notifyListeners();
  }
}
