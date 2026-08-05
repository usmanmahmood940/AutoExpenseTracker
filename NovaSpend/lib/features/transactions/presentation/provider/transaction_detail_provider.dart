import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
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
        merchant = transaction.merchant,
        amount = transaction.amount,
        category = transaction.category,
        type = transaction.type,
        bank = transaction.bank,
        accountIdMasked = transaction.accountIdMasked,
        paymentMethod = transaction.paymentMethod,
        transactionDate = transaction.transactionDate,
        transactionTime = transaction.transactionTime;

  final String uid;
  final UpdateTransaction _updateTransaction;
  final TransactionRepository _repository;

  TransactionEntity _transaction;
  String merchant;
  double amount;
  String category;
  String type;
  String bank;
  String accountIdMasked;
  String paymentMethod;
  String transactionDate;
  String transactionTime;
  bool rememberForMerchant = false;
  bool isSaving = false;
  String? error;
  bool saved = false;

  TransactionEntity get transaction => _transaction;

  void setMerchant(String value) {
    merchant = value;
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
    paymentMethod = value;
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
    merchant = _transaction.merchant;
    amount = _transaction.amount;
    category = _transaction.category;
    type = _transaction.type;
    bank = _transaction.bank;
    accountIdMasked = _transaction.accountIdMasked;
    paymentMethod = _transaction.paymentMethod;
    transactionDate = _transaction.transactionDate;
    transactionTime = _transaction.transactionTime;
    rememberForMerchant = false;
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

      final fields = <String, dynamic>{
        'merchant': merchant.trim(),
        'amount': amount,
        'category': category,
        'type': type,
        'bank': bank.trim(),
        'accountIdMasked': accountIdMasked.trim(),
        'paymentMethod': paymentMethod.trim(),
        'transactionDate': transactionDate.trim(),
        'transactionTime': transactionTime.trim(),
        'day': day,
        'isEdited': true,
        'categorySource': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (needsReview) {
        fields['reviewedAt'] = FieldValue.serverTimestamp();
        fields['status'] = 'active';
      }

      await _updateTransaction(uid, _transaction.id, fields);

      if (rememberForMerchant && merchant.trim().isNotEmpty) {
        await _repository.upsertMerchantCategoryOverride(
          uid: uid,
          merchantKey: merchant,
          displayName: merchant.trim(),
          category: category,
        );
      }

      _transaction = _transaction.copyWith(
        merchant: merchant.trim(),
        amount: amount,
        category: category,
        type: type,
        bank: bank.trim(),
        accountIdMasked: accountIdMasked.trim(),
        paymentMethod: paymentMethod.trim(),
        transactionDate: transactionDate.trim(),
        transactionTime: transactionTime.trim(),
        day: day,
        categorySource: 'user',
        isEdited: true,
        status: needsReview ? 'active' : _transaction.status,
        reviewedAt: needsReview ? DateTime.now() : _transaction.reviewedAt,
      );
      rememberForMerchant = false;
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
