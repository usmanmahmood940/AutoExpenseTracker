import 'package:equatable/equatable.dart';

class TopMerchantEntity extends Equatable {
  const TopMerchantEntity({
    required this.displayName,
    required this.merchantNormalized,
    required this.amount,
    required this.visitCount,
  });

  final String displayName;
  final String merchantNormalized;
  final double amount;
  final int visitCount;

  @override
  List<Object?> get props => [
        displayName,
        merchantNormalized,
        amount,
        visitCount,
      ];
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
    this.dateFrom,
    this.dateTo,
    this.topMerchantsSpent = const [],
    this.topMerchantsReceived = const [],
    this.topMerchantsByVisits = const [],
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
  final List<TopMerchantEntity> topMerchantsSpent;
  final List<TopMerchantEntity> topMerchantsReceived;
  final List<TopMerchantEntity> topMerchantsByVisits;
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
        topMerchantsSpent,
        topMerchantsReceived,
        topMerchantsByVisits,
        updatedAt,
      ];
}
