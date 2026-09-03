import 'package:equatable/equatable.dart';

/// Result of `POST /transactions/parse`. Does not create a transaction.
class ParsedTransactionDraft extends Equatable {
  const ParsedTransactionDraft({
    required this.ok,
    this.duplicate = false,
    this.transactionId,
    this.error,
    this.parseConfidence,
    this.model,
    this.amount,
    this.currency,
    this.type,
    this.merchant,
    this.merchantDetails,
    this.category,
    this.paymentMethod,
    this.bank,
    this.accountId,
    this.branch,
    this.transactionTime,
    this.transactionDate,
  });

  final bool ok;
  final bool duplicate;
  final String? transactionId;
  final String? error;
  final double? parseConfidence;
  final String? model;
  final double? amount;
  final String? currency;
  final String? type;
  final String? merchant;
  final String? merchantDetails;
  final String? category;
  final String? paymentMethod;
  final String? bank;
  final String? accountId;
  final String? branch;
  final String? transactionTime;
  final String? transactionDate;

  bool get hasPartialFields =>
      (merchant != null && merchant!.trim().isNotEmpty) ||
      (amount != null && amount! > 0);

  @override
  List<Object?> get props => [
        ok,
        duplicate,
        transactionId,
        error,
        parseConfidence,
        model,
        amount,
        currency,
        type,
        merchant,
        merchantDetails,
        category,
        paymentMethod,
        bank,
        accountId,
        branch,
        transactionTime,
        transactionDate,
      ];
}
