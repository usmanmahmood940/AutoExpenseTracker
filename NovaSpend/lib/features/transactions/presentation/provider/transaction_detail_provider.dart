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
        transactionTime = transaction.transactionTime;

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
  bool isSaving = false;
  String? error;
  bool saved = false;

  /// Normalized merchant key of an existing override, if any.
  String? _activeOverrideKey;
  Future<void>? _rememberStateFuture;

  TransactionEntity get transaction => _transaction;

  Future<void> loadMerchantRememberState() {
    return _rememberStateFuture ??= _fetchMerchantRememberState();
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
    amount = value;
    notifyListeners();
  }

  void setCategory(String value) {
    category = value;
    notifyListeners();
  }

  void setType(String value) {
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
        'amount': amount,
        'category': category,
        'type': type,
        'bank': resolvedBank,
        'accountIdMasked': accountIdMasked.trim(),
        'paymentMethod': resolvedPaymentMethod,
        'transactionDate': transactionDate.trim(),
        'transactionTime': transactionTime.trim(),
        'day': day,
        'isEdited': true,
        'categorySource': 'user',
      };

      if (needsReview) {
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
        status: needsReview ? 'active' : _transaction.status,
        reviewedAt: needsReview ? DateTime.now() : _transaction.reviewedAt,
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

  static String? _dayNameFromDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate.trim());
    if (parsed == null) return null;
    return DateFormat('EEEE').format(parsed);
  }
}
