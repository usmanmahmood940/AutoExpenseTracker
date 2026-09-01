import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/merchants/domain/entities/merchant_summary_entity.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_summary.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_transactions.dart';
import 'package:nova_spend/features/merchants/presentation/provider/merchant_time_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class MerchantProvider extends ChangeNotifier {
  MerchantProvider({
    required GetMerchantSummary getMerchantSummary,
    required GetMerchantTransactions getMerchantTransactions,
    required TransactionRepository transactionRepository,
  })  : _getMerchantSummary = getMerchantSummary,
        _getMerchantTransactions = getMerchantTransactions,
        _transactionRepository = transactionRepository;

  final GetMerchantSummary _getMerchantSummary;
  final GetMerchantTransactions _getMerchantTransactions;
  final TransactionRepository _transactionRepository;

  MerchantSummaryEntity? summary;
  List<TransactionEntity> items = [];
  MerchantTimeFilter filter = MerchantTimeFilter.all;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;

  bool rememberCategory = false;
  bool isLoadingRememberState = false;
  bool isSavingRemember = false;
  String? _savedOverrideCategory;

  String? _uid;
  String? _merchantNormalized;
  String? _displayNameHint;

  List<TransactionEntity> get filteredItems {
    final cutoff = _filterCutoff(filter);
    if (cutoff == null) return items;
    return items.where((t) => _isOnOrAfter(t.transactionDate, cutoff)).toList();
  }

  String? get savedOverrideCategory => _savedOverrideCategory;

  String get dominantCategory {
    final counts = <String, int>{};
    for (final tx in items) {
      final cat = tx.category.trim();
      if (cat.isEmpty) continue;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String get rememberCategoryLabel =>
      _savedOverrideCategory ?? dominantCategory;

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

    unawaited(loadRememberState());
  }

  void setFilter(MerchantTimeFilter value) {
    if (filter == value) return;
    filter = value;
    notifyListeners();
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
        error = null;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadRememberState() async {
    final uid = _uid;
    final key = _merchantNormalized;
    if (uid == null || key == null) return;

    isLoadingRememberState = true;
    notifyListeners();

    try {
      final category = await _transactionRepository.getMerchantCategoryOverride(
        uid: uid,
        merchantKey: key,
      );
      rememberCategory = category != null;
      _savedOverrideCategory = category;
    } catch (e) {
      debugPrint('MerchantProvider.loadRememberState failed: $e');
      rememberCategory = false;
      _savedOverrideCategory = null;
    } finally {
      isLoadingRememberState = false;
      notifyListeners();
    }
  }

  Future<bool> setRememberCategory(bool value) async {
    final uid = _uid;
    final key = _merchantNormalized;
    if (uid == null || key == null || isSavingRemember) return false;

    isSavingRemember = true;
    notifyListeners();

    try {
      if (value) {
        final category = rememberCategoryLabel;
        if (category.isEmpty) return false;

        await _transactionRepository.upsertMerchantCategoryOverride(
          uid: uid,
          merchantKey: key,
          displayName: summary?.displayName ?? _displayNameHint ?? key,
          category: category,
        );
        rememberCategory = true;
        _savedOverrideCategory = category;
      } else {
        await _transactionRepository.deleteMerchantCategoryOverride(
          uid: uid,
          merchantKey: key,
        );
        rememberCategory = false;
        _savedOverrideCategory = null;
      }
      return true;
    } catch (e) {
      debugPrint('MerchantProvider.setRememberCategory failed: $e');
      return false;
    } finally {
      isSavingRemember = false;
      notifyListeners();
    }
  }

  static DateTime? _filterCutoff(MerchantTimeFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case MerchantTimeFilter.all:
        return null;
      case MerchantTimeFilter.thisMonth:
        return DateTime(now.year, now.month);
      case MerchantTimeFilter.last3Months:
        return DateTime(now.year, now.month - 2);
    }
  }

  static bool _isOnOrAfter(String isoDate, DateTime cutoff) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return false;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final floor = DateTime(cutoff.year, cutoff.month, cutoff.day);
    return !day.isBefore(floor);
  }
}
