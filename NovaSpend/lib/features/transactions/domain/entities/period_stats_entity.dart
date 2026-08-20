import 'package:equatable/equatable.dart';

/// Lightweight highlight row returned by [getPeriodStats].
class PeriodHighlight extends Equatable {
  const PeriodHighlight({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.merchantNormalized,
    required this.category,
    required this.transactionDate,
    required this.type,
    required this.currency,
  });

  final String id;
  final double amount;
  final String merchant;
  final String merchantNormalized;
  final String category;
  final String transactionDate;
  final String type;
  final String currency;

  @override
  List<Object?> get props => [
        id,
        amount,
        merchant,
        merchantNormalized,
        category,
        transactionDate,
        type,
        currency,
      ];
}

class PeriodComparisonStats extends Equatable {
  const PeriodComparisonStats({
    required this.spentChangePercent,
    required this.receivedChangePercent,
    required this.netChangePercent,
  });

  final double spentChangePercent;
  final double receivedChangePercent;
  final double netChangePercent;

  @override
  List<Object?> get props => [
        spentChangePercent,
        receivedChangePercent,
        netChangePercent,
      ];
}

/// Full period overview payload from the getPeriodStats cloud function.
class PeriodStatsEntity extends Equatable {
  const PeriodStatsEntity({
    required this.period,
    required this.from,
    required this.to,
    required this.currency,
    required this.spent,
    required this.received,
    required this.net,
    this.highestSpend,
    this.highestReceive,
    this.comparison,
  });

  final String period;
  final String from;
  final String to;
  final String currency;
  final double spent;
  final double received;
  final double net;
  final PeriodHighlight? highestSpend;
  final PeriodHighlight? highestReceive;
  final PeriodComparisonStats? comparison;

  @override
  List<Object?> get props => [
        period,
        from,
        to,
        currency,
        spent,
        received,
        net,
        highestSpend,
        highestReceive,
        comparison,
      ];
}
