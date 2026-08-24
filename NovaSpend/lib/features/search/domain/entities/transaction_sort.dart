import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

/// Sort options for the Activity (Transactions) list.
enum TransactionSort {
  dateNewest,
  dateOldest,
  amountHighest,
  amountLowest,
  merchantAz,
  merchantZa;

  static const TransactionSort defaultSort = dateNewest;

  bool get isDefault => this == defaultSort;

  /// Day headers (Spent / Net) only make sense for date-ordered lists.
  bool get groupsByDay =>
      this == dateNewest || this == dateOldest;

  int compare(TransactionEntity a, TransactionEntity b) {
    switch (this) {
      case TransactionSort.dateNewest:
        return _dateOf(b).compareTo(_dateOf(a));
      case TransactionSort.dateOldest:
        return _dateOf(a).compareTo(_dateOf(b));
      case TransactionSort.amountHighest:
        return b.amount.compareTo(a.amount);
      case TransactionSort.amountLowest:
        return a.amount.compareTo(b.amount);
      case TransactionSort.merchantAz:
        return a.merchant.toLowerCase().compareTo(b.merchant.toLowerCase());
      case TransactionSort.merchantZa:
        return b.merchant.toLowerCase().compareTo(a.merchant.toLowerCase());
    }
  }
}

DateTime _dateOf(TransactionEntity tx) {
  return DateTime.tryParse(tx.transactionDate) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

List<TransactionEntity> sortTransactions(
  List<TransactionEntity> items,
  TransactionSort sort,
) {
  final copy = List<TransactionEntity>.from(items);
  copy.sort(sort.compare);
  return copy;
}
