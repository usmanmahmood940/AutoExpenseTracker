import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/constants/payment_methods.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/update_transaction.dart';

class TransactionDetailProvider extends ChangeNotifier {
  TransactionDetailProvider({
    required this.uid,
    required TransactionEntity transaction,
    required UpdateTransaction updateTransaction,
    required TransactionRepository repository,
  })  : _transaction = transaction,
        _updateTransaction = updateTransaction,
        _repository = repository,
        merchant = resolveMerchant(
          transaction.merchant,
          category: transaction.category,
          paymentMethod: normalizePaymentMethod(transaction.paymentMethod),
        ),
        merchantDetails = transaction.merchantDetails ?? '',
        amount = transaction.amount,
        category = transaction.category,
        type = transaction.type,
        bank = transaction.bank,
        accountIdMasked = transaction.accountIdMasked,
        paymentMethod = normalizePaymentMethod(transaction.paymentMethod),
        transactionDate = transaction.transactionDate,
        transactionTime = transaction.transactionTime,
        isLoadingSettlementMembers = transaction.isSettled,
        settlementMembersResolved = !transaction.isSettled;

  final String uid;
  final UpdateTransaction _updateTransaction;
  final TransactionRepository _repository;

  TransactionEntity _transaction;
  String merchant;
  String merchantDetails;
  double amount;
  String category;
  String type;
  String bank;
  String accountIdMasked;
  String paymentMethod;
  String transactionDate;
  String transactionTime;
  bool rememberForMerchant = false;
  bool isLoadingRememberState = false;
  bool isLoadingSettlementMembers = false;
  bool settlementMembersResolved = false;
  bool isSaving = false;
  String? error;
  bool saved = false;

  /// Normalized merchant key of an existing override, if any.
  String? _activeOverrideKey;
  Future<void>? _rememberStateFuture;
  Future<void>? _detailFuture;
  Future<void>? _settlementMembersFuture;
  bool _detailLoaded = false;
  int _settlementLoadGen = 0;
  final Map<String, TransactionEntity> _settlementMembers = {};

  TransactionEntity get transaction => _transaction;

  /// Linked settlement sources keyed by transaction id.
  Map<String, TransactionEntity> get settlementMembers =>
      Map.unmodifiable(_settlementMembers);

  /// Settled primaries stay "not ready" until members are fetched (or detail
  /// confirms there are no settlement groups).
  bool get settlementMembersReady {
    if (!_transaction.isSettled) return true;
    return settlementMembersResolved;
  }

  Future<void> loadMerchantRememberState() {
    return _rememberStateFuture ??= _fetchMerchantRememberState();
  }

  /// List payloads omit decrypted SMS. Detail GET includes it.
  Future<void> loadFullTransaction() {
    return _detailFuture ??= _fetchFullTransaction();
  }

  /// Resolve settlement member rows for the Settlements section UI.
  Future<void> loadSettlementMembers({bool force = false}) {
    if (force) {
      _settlementMembersFuture = null;
    }
    return _settlementMembersFuture ??= _fetchSettlementMembers();
  }

  Future<void> _fetchFullTransaction() async {
    try {
      if (_transaction.smsSource.raw.trim().isEmpty) {
        final full = await _repository.getTransaction(uid, _transaction.id);
        if (saved) {
          _transaction = _transaction.copyWith(smsSource: full.smsSource);
        } else {
          _transaction = full;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadFullTransaction failed: $e');
    } finally {
      _detailLoaded = true;
    }

    final ids = _settlementMemberIds(_transaction);
    if (!_transaction.isSettled || ids.isEmpty) {
      _settlementMembers.clear();
      isLoadingSettlementMembers = false;
      settlementMembersResolved = true;
      notifyListeners();
      return;
    }

    final missing =
        ids.where((id) => !_settlementMembers.containsKey(id)).toList();
    if (missing.isEmpty) {
      isLoadingSettlementMembers = false;
      settlementMembersResolved = true;
      notifyListeners();
      await loadSettlementMembers();
      return;
    }

    final shouldForce =
        _settlementMembersFuture == null || !isLoadingSettlementMembers;
    isLoadingSettlementMembers = true;
    settlementMembersResolved = false;
    notifyListeners();
    await loadSettlementMembers(force: shouldForce);
  }

  Future<void> _fetchSettlementMembers() async {
    final loadGen = ++_settlementLoadGen;
    final ids = _settlementMemberIds(_transaction);
    if (ids.isEmpty) {
      if (_transaction.isSettled && !_detailLoaded) {
        // Primary detail may still bring settlement_groups — keep skeletons.
        isLoadingSettlementMembers = true;
        settlementMembersResolved = false;
        notifyListeners();
        // Don't memoize this no-op; detail load will start a real fetch.
        _settlementMembersFuture = null;
        return;
      }
      if (_settlementMembers.isNotEmpty) {
        _settlementMembers.clear();
      }
      if (loadGen != _settlementLoadGen) return;
      isLoadingSettlementMembers = false;
      settlementMembersResolved = true;
      notifyListeners();
      return;
    }

    final missing =
        ids.where((id) => !_settlementMembers.containsKey(id)).toList();
    if (missing.isEmpty) {
      if (loadGen != _settlementLoadGen) return;
      isLoadingSettlementMembers = false;
      settlementMembersResolved = true;
      notifyListeners();
      return;
    }

    isLoadingSettlementMembers = true;
    settlementMembersResolved = false;
    notifyListeners();
    try {
      final fetched = await Future.wait(
        missing.map((id) async {
          try {
            return await _repository.getTransaction(uid, id);
          } catch (e) {
            debugPrint('loadSettlementMember $id failed: $e');
            return null;
          }
        }),
      );
      if (loadGen != _settlementLoadGen) return;
      for (final tx in fetched) {
        if (tx != null) {
          _settlementMembers[tx.id] = tx;
        }
      }
      _settlementMembers.removeWhere((id, _) => !ids.contains(id));
      isLoadingSettlementMembers = false;
      settlementMembersResolved = true;
      notifyListeners();
    } catch (e) {
      debugPrint('loadSettlementMembers failed: $e');
      if (loadGen != _settlementLoadGen) return;
      isLoadingSettlementMembers = false;
      settlementMembersResolved = true;
      notifyListeners();
    }
  }

  static Set<String> _settlementMemberIds(TransactionEntity tx) {
    final ids = <String>{};
    for (final group
        in tx.settlementGroups ?? const <SettlementGroupEntity>[]) {
      ids.addAll(group.mergedTransactionIds);
    }
    return ids;
  }

  Future<void> _fetchMerchantRememberState() async {
    isLoadingRememberState = true;
    notifyListeners();
    try {
      final key = normalizeMerchantKey(merchant);
      if (key.isEmpty) {
        rememberForMerchant = false;
        _activeOverrideKey = null;
        return;
      }
      final category = await _repository.getMerchantCategoryOverride(
        uid: uid,
        merchantKey: merchant,
      );
      rememberForMerchant = category != null;
      _activeOverrideKey = category != null ? key : null;
    } catch (e) {
      debugPrint('loadMerchantRememberState failed: $e');
      rememberForMerchant = false;
      _activeOverrideKey = null;
    } finally {
      isLoadingRememberState = false;
      notifyListeners();
    }
  }

  void setMerchant(String value) {
    merchant = value;
    notifyListeners();
  }

  void setMerchantDetails(String value) {
    merchantDetails = value;
    notifyListeners();
  }

  void setAmount(double value) {
    if (_transaction.isSettlementLocked) return;
    amount = value;
    notifyListeners();
  }

  void setCategory(String value) {
    category = value;
    notifyListeners();
  }

  void setType(String value) {
    if (_transaction.isSettlementLocked) return;
    type = value;
    notifyListeners();
  }

  void setBank(String value) {
    bank = value;
    notifyListeners();
  }

  void setAccountIdMasked(String value) {
    accountIdMasked = value;
    notifyListeners();
  }

  void setPaymentMethod(String value) {
    paymentMethod = normalizePaymentMethod(value);
    notifyListeners();
  }

  void setTransactionDate(String value) {
    transactionDate = value;
    notifyListeners();
  }

  void setTransactionTime(String value) {
    transactionTime = value;
    notifyListeners();
  }

  void setRememberForMerchant(bool value) {
    rememberForMerchant = value;
    notifyListeners();
  }

  void resetDraftFromTransaction() {
    merchant = resolveMerchant(
      _transaction.merchant,
      category: _transaction.category,
      paymentMethod: normalizePaymentMethod(_transaction.paymentMethod),
    );
    merchantDetails = _transaction.merchantDetails ?? '';
    amount = _transaction.amount;
    category = _transaction.category;
    type = _transaction.type;
    bank = _transaction.bank;
    accountIdMasked = _transaction.accountIdMasked;
    paymentMethod = normalizePaymentMethod(_transaction.paymentMethod);
    transactionDate = _transaction.transactionDate;
    transactionTime = _transaction.transactionTime;
    rememberForMerchant = _activeOverrideKey != null;
    notifyListeners();
  }

  Future<bool> save() async {
    isSaving = true;
    error = null;
    saved = false;
    notifyListeners();

    try {
      final needsReview =
          _transaction.parseConfidence < AppConstants.confidenceReviewThreshold &&
              _transaction.reviewedAt == null;

      final day = _dayNameFromDate(transactionDate) ?? _transaction.day;

      final resolvedBank = bank.trim().isEmpty ? 'Unknown' : bank.trim();
      final resolvedPaymentMethod = normalizePaymentMethod(paymentMethod);
      final trimmedMerchant = resolveMerchant(
        merchant.trim(),
        category: category,
        paymentMethod: resolvedPaymentMethod,
      );
      final trimmedDetails = merchantDetails.trim();
      final currentKey = normalizeMerchantKey(trimmedMerchant);

      final fields = <String, dynamic>{
        'merchant': trimmedMerchant,
        'merchantDetails': trimmedDetails.isEmpty ? null : trimmedDetails,
        'category': category,
        'bank': resolvedBank,
        'accountIdMasked': accountIdMasked.trim(),
        'paymentMethod': resolvedPaymentMethod,
        'transactionDate': transactionDate.trim(),
        'transactionTime': transactionTime.trim(),
        'day': day,
        'isEdited': true,
        'categorySource': 'user',
      };
      if (!_transaction.isSettlementLocked) {
        fields['amount'] = amount;
        fields['type'] = type;
      }

      if (needsReview && !_transaction.isSettlementLocked) {
        fields['status'] = 'active';
      }

      await _updateTransaction(uid, _transaction.id, fields);

      if (rememberForMerchant && currentKey.isNotEmpty) {
        await _repository.upsertMerchantCategoryOverride(
          uid: uid,
          merchantKey: trimmedMerchant,
          displayName: trimmedMerchant,
          category: category,
        );
        if (_activeOverrideKey != null &&
            _activeOverrideKey != currentKey) {
          await _repository.deleteMerchantCategoryOverride(
            uid: uid,
            merchantKey: _activeOverrideKey!,
          );
        }
        _activeOverrideKey = currentKey;
      } else if (!rememberForMerchant && _activeOverrideKey != null) {
        await _repository.deleteMerchantCategoryOverride(
          uid: uid,
          merchantKey: _activeOverrideKey!,
        );
        _activeOverrideKey = null;
      }

      _transaction = _transaction.copyWith(
        merchant: trimmedMerchant,
        merchantDetails: trimmedDetails.isEmpty ? null : trimmedDetails,
        clearMerchantDetails: trimmedDetails.isEmpty,
        amount: amount,
        category: category,
        type: type,
        bank: resolvedBank,
        accountIdMasked: accountIdMasked.trim(),
        paymentMethod: resolvedPaymentMethod,
        transactionDate: transactionDate.trim(),
        transactionTime: transactionTime.trim(),
        day: day,
        categorySource: 'user',
        isEdited: true,
        status: (needsReview && !_transaction.isSettlementLocked)
            ? 'active'
            : _transaction.status,
        reviewedAt: (needsReview && !_transaction.isSettlementLocked)
            ? DateTime.now()
            : _transaction.reviewedAt,
      );
      rememberForMerchant = _activeOverrideKey != null;
      saved = true;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTransaction() async {
    if (_transaction.isSettlementLocked) {
      error = 'settlement_locked';
      notifyListeners();
      return false;
    }
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.softDelete(uid, _transaction.id);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> unsettleGroup(String groupId) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final updated = await _repository.unsettle(
        uid: uid,
        primaryId: _transaction.id,
        groupId: groupId,
      );
      _transaction = updated;
      amount = updated.amount;
      saved = true;
      _settlementMembers.clear();
      _settlementMembersFuture = null;
      settlementMembersResolved = _settlementMemberIds(updated).isEmpty;
      isLoadingSettlementMembers = !settlementMembersResolved;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> unmergeTransaction() async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final updated = await _repository.unmerge(
        uid: uid,
        transactionId: _transaction.id,
      );
      _transaction = updated;
      amount = updated.amount;
      saved = true;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<TransactionEntity?> loadLinkedTransaction(String id) async {
    try {
      return await _repository.getTransaction(uid, id);
    } catch (e) {
      debugPrint('loadLinkedTransaction failed: $e');
      return null;
    }
  }

  static String? _dayNameFromDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate.trim());
    if (parsed == null) return null;
    return DateFormat('EEEE').format(parsed);
  }
}
