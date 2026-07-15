import 'package:equatable/equatable.dart';

class TransactionFilter extends Equatable {
  const TransactionFilter({
    this.dateFrom,
    this.dateTo,
    this.category,
    this.bank,
    this.merchantQuery,
    this.amountMin,
    this.amountMax,
    this.type,
    this.accountIdMasked,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? category;
  final String? bank;
  final String? merchantQuery;
  final double? amountMin;
  final double? amountMax;
  final String? type;
  final String? accountIdMasked;

  static const empty = TransactionFilter();

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      (category != null && category!.isNotEmpty) ||
      (bank != null && bank!.isNotEmpty) ||
      (merchantQuery != null && merchantQuery!.trim().isNotEmpty) ||
      amountMin != null ||
      amountMax != null ||
      (type != null && type!.isNotEmpty) ||
      (accountIdMasked != null && accountIdMasked!.isNotEmpty);

  TransactionFilter copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? category,
    String? bank,
    String? merchantQuery,
    double? amountMin,
    double? amountMax,
    String? type,
    String? accountIdMasked,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearCategory = false,
    bool clearBank = false,
    bool clearMerchantQuery = false,
    bool clearAmountMin = false,
    bool clearAmountMax = false,
    bool clearType = false,
    bool clearAccountIdMasked = false,
  }) {
    return TransactionFilter(
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      category: clearCategory ? null : (category ?? this.category),
      bank: clearBank ? null : (bank ?? this.bank),
      merchantQuery:
          clearMerchantQuery ? null : (merchantQuery ?? this.merchantQuery),
      amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
      type: clearType ? null : (type ?? this.type),
      accountIdMasked: clearAccountIdMasked
          ? null
          : (accountIdMasked ?? this.accountIdMasked),
    );
  }

  @override
  List<Object?> get props => [
        dateFrom,
        dateTo,
        category,
        bank,
        merchantQuery,
        amountMin,
        amountMax,
        type,
        accountIdMasked,
      ];
}
