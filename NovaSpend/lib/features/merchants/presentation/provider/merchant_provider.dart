import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_summary.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_transactions.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class MerchantProvider extends ChangeNotifier {
  MerchantProvider({
    required GetMerchantSummary getMerchantSummary,
    required GetMerchantTransactions getMerchantTransactions,
  })  : _getMerchantSummary = getMerchantSummary,
        _getMerchantTransactions = getMerchantTransactions;

  final GetMerchantSummary _getMerchantSummary;
  final GetMerchantTransactions _getMerchantTransactions;

  MerchantSummaryEntity? summary;
  List<TransactionEntity> items = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;

  String? _uid;
  String? _merchantNormalized;
  String? _displayNameHint;

  Future<void> start({
    required String uid,
    required String merchantNormalized,
    String? displayNameHint,
  }) async {
    _uid = uid;
    _merchantNormalized = merchantNormalized;
    _displayNameHint = displayNameHint;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _getMerchantSummary(
          uid: uid,
          merchantNormalized: merchantNormalized,
          displayNameHint: displayNameHint,
        ),
        _getMerchantTransactions(
          uid: uid,
          merchantNormalized: merchantNormalized,
          limit: 50,
        ),
      ]);

      summary = results[0] as MerchantSummaryEntity;
      items = results[1] as List<TransactionEntity>;
      hasMore = items.length >= 50;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final uid = _uid;
    final key = _merchantNormalized;
    if (uid == null || key == null) return;
    await start(
      uid: uid,
      merchantNormalized: key,
      displayNameHint: _displayNameHint,
    );
  }

  Future<void> loadMore() async {
    final uid = _uid;
    final key = _merchantNormalized;
    if (uid == null ||
        key == null ||
        isLoadingMore ||
        !hasMore ||
        items.isEmpty) {
      return;
    }

    isLoadingMore = true;
    notifyListeners();

    try {
      final more = await _getMerchantTransactions(
        uid: uid,
        merchantNormalized: key,
        limit: 50,
        startAfter: items.last,
      );
      if (more.isEmpty) {
        hasMore = false;
      } else {
        final existingIds = items.map((e) => e.id).toSet();
        items = [...items, ...more.where((t) => !existingIds.contains(t.id))];
        hasMore = more.length >= 50;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
