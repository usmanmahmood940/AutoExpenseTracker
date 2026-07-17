import 'package:equatable/equatable.dart';

class MerchantSummaryEntity extends Equatable {
  const MerchantSummaryEntity({
    required this.merchantNormalized,
    required this.displayName,
    required this.currency,
    required this.totalSpent,
    required this.visitCount,
    required this.averageSpent,
    required this.thisMonthSpent,
    required this.thisMonthVisits,
  });

  final String merchantNormalized;
  final String displayName;
  final String currency;
  final double totalSpent;
  final int visitCount;
  final double averageSpent;
  final double thisMonthSpent;
  final int thisMonthVisits;

  @override
  List<Object?> get props => [
        merchantNormalized,
        displayName,
        currency,
        totalSpent,
        visitCount,
        averageSpent,
        thisMonthSpent,
        thisMonthVisits,
      ];
}
