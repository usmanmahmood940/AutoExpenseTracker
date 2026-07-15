import 'package:equatable/equatable.dart';

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
    this.updatedAt,
  });

  final String yearMonth;
  final String currency;
  final double totalDebit;
  final double totalCredit;
  final double net;
  final int transactionCount;
  final Map<String, double> byCategory;
  final Map<String, double> byMerchant;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        yearMonth,
        currency,
        totalDebit,
        totalCredit,
        net,
        transactionCount,
        byCategory,
        byMerchant,
        updatedAt,
      ];
}
