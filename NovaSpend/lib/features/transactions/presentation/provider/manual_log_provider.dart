import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/constants/payment_methods.dart';
import 'package:nova_spend/core/provider/safe_change_notifier.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/features/transactions/domain/entities/parsed_transaction_draft.dart';
import 'package:nova_spend/features/transactions/domain/usecases/create_transaction.dart';
import 'package:nova_spend/features/transactions/domain/usecases/parse_transaction_text.dart';

enum ManualLogMode { paste, form }

class ManualLogProvider extends SafeChangeNotifier {
  ManualLogProvider({
    required ParseTransactionText parseTransactionText,
    required CreateTransaction createTransaction,
  }) : _parseTransactionText = parseTransactionText,
       _createTransaction = createTransaction;

  final ParseTransactionText _parseTransactionText;
  final CreateTransaction _createTransaction;

  String uid = '';
  String currency = 'PKR';

  ManualLogMode mode = ManualLogMode.paste;
  String pasteText = '';
  bool isParsing = false;
  bool isSaving = false;

  String merchant = '';
  String amountText = '';
  double amount = 0;
  String category = '';
  String type = 'debit';
  String transactionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String transactionTime = '';
  String paymentMethod = kDefaultPaymentMethod;
  String note = '';

  String? pasteError;
  String? amountError;
  String? merchantError;
  String? categoryError;
  String? bannerMessage;
  bool bannerIsDuplicate = false;
  String? duplicateTransactionId;
  Object? actionError;
  double? parseConfidence;

  bool get canParse => pasteText.trim().isNotEmpty && !isParsing && !isSaving;

  bool get canSave => !isSaving && !isParsing;

  bool get hasLowConfidence {
    final value = parseConfidence;
    return value != null && value < AppConstants.confidenceReviewThreshold;
  }

  void configure({required String uid, required String currency}) {
    this.uid = uid;
    this.currency = currency;
  }

  void setMode(ManualLogMode next) {
    if (mode == next) return;
    mode = next;
    pasteError = null;
    notifyListeners();
  }

  void setPasteText(String value) {
    pasteText = value;
    if (pasteError != null) pasteError = null;
    notifyListeners();
  }

  void setMerchant(String value) {
    merchant = value;
    if (merchantError != null) merchantError = null;
    notifyListeners();
  }

  void setAmountText(String value) {
    amountText = value;
    amount = double.tryParse(value.trim()) ?? 0;
    if (amountError != null) amountError = null;
    notifyListeners();
  }

  void setCategory(String value) {
    category = value;
    if (categoryError != null) categoryError = null;
    notifyListeners();
  }

  void setType(String value) {
    type = value;
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

  void setPaymentMethod(String value) {
    paymentMethod = normalizePaymentMethod(value);
    notifyListeners();
  }

  void setNote(String value) {
    note = value;
    notifyListeners();
  }

  void clearActionError() {
    actionError = null;
  }

  bool validatePaste() {
    if (pasteText.trim().isEmpty) {
      pasteError = 'empty';
      notifyListeners();
      return false;
    }
    pasteError = null;
    notifyListeners();
    return true;
  }

  bool validateForm() {
    var ok = true;
    if (amount <= 0) {
      amountError = 'invalid';
      ok = false;
    } else {
      amountError = null;
    }
    if (merchant.trim().isEmpty) {
      merchantError = 'empty';
      ok = false;
    } else {
      merchantError = null;
    }
    if (category.trim().isEmpty) {
      categoryError = 'empty';
      ok = false;
    } else {
      categoryError = null;
    }
    notifyListeners();
    return ok;
  }

  Future<bool> parse() async {
    actionError = null;
    bannerMessage = null;
    bannerIsDuplicate = false;
    duplicateTransactionId = null;
    if (!validatePaste()) return false;

    isParsing = true;
    notifyListeners();
    try {
      final draft = await _parseTransactionText(
        uid: uid,
        raw: pasteText.trim(),
      );
      _applyDraft(draft, raw: pasteText.trim());
      if (draft.duplicate) {
        bannerIsDuplicate = true;
        duplicateTransactionId = draft.transactionId;
        bannerMessage = 'duplicate';
        mode = ManualLogMode.form;
        return false;
      }
      if (!draft.ok) {
        bannerIsDuplicate = false;
        bannerMessage = 'parseFailed';
        mode = ManualLogMode.form;
        return false;
      }
      mode = ManualLogMode.form;
      return true;
    } catch (e) {
      actionError = e;
      return false;
    } finally {
      isParsing = false;
      notifyListeners();
    }
  }

  Future<bool> save() async {
    actionError = null;
    if (!validateForm()) return false;

    isSaving = true;
    notifyListeners();
    try {
      await _createTransaction(
        uid: uid,
        fields: {
          'amount': amount,
          'merchant': merchant.trim(),
          'transactionDate': transactionDate,
          'type': type,
          'category': category.trim(),
          'currency': currency,
          'transactionTime': transactionTime,
          'paymentMethod': paymentMethod,
          'categorySource': 'user',
          if (note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      return true;
    } catch (e) {
      actionError = e;
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void _applyDraft(ParsedTransactionDraft draft, {required String raw}) {
    note = raw;
    parseConfidence = draft.parseConfidence;

    final nextMerchant = draft.merchant?.trim() ?? '';
    if (nextMerchant.isNotEmpty) merchant = nextMerchant;

    if (draft.amount != null && draft.amount! > 0) {
      amount = draft.amount!;
      amountText = formatAmount(amount);
    }

    final nextCategory = draft.category?.trim() ?? '';
    if (nextCategory.isNotEmpty &&
        nextCategory.toLowerCase() != 'uncategorized') {
      category = nextCategory;
    }

    if (draft.type == 'credit' || draft.type == 'debit') {
      type = draft.type!;
    }

    final date = draft.transactionDate?.trim() ?? '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      transactionDate = date;
    }

    final time = draft.transactionTime?.trim() ?? '';
    if (time.isNotEmpty) transactionTime = time;

    paymentMethod = normalizePaymentMethod(draft.paymentMethod);
  }
}
