import 'package:equatable/equatable.dart';

class MerchantSpendStat extends Equatable {
  const MerchantSpendStat({
    required this.amount,
    required this.visitCount,
    required this.merchantNormalized,
  });

  final double amount;
  final int visitCount;
  final String merchantNormalized;

  @override
  List<Object?> get props => [amount, visitCount, merchantNormalized];
}

class MonthlySummaryEntity extends Equatable {
  const MonthlySummaryEntity({
    required this.yearMonth,
    required this.currency,
    required this.totalDebit,
    required this.totalCredit,
    required this.net,
    required this.transactionCount,
    required this.byCategory,
    required this.byMerchant,
    this.dateFrom,
    this.dateTo,
    this.byMerchantStats = const {},
    this.updatedAt,
  });

  final String yearMonth;
  final String? dateFrom;
  final String? dateTo;
  final String currency;
  final double totalDebit;
  final double totalCredit;
  final double net;
  final int transactionCount;
  final Map<String, double> byCategory;
  final Map<String, double> byMerchant;
  final Map<String, MerchantSpendStat> byMerchantStats;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        yearMonth,
        dateFrom,
        dateTo,
        currency,
        totalDebit,
        totalCredit,
        net,
        transactionCount,
        byCategory,
        byMerchant,
        byMerchantStats,
        updatedAt,
      ];
}
