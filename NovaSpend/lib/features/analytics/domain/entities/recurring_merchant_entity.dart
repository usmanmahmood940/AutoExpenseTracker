import 'package:equatable/equatable.dart';

class RecurringMerchantEntity extends Equatable {
  const RecurringMerchantEntity({
    required this.displayName,
    required this.merchantNormalized,
    required this.count,
    required this.averageAmount,
    required this.lastDate,
  });

  final String displayName;
  final String merchantNormalized;
  final int count;
  final double averageAmount;
  final DateTime lastDate;

  @override
  List<Object?> get props => [
        displayName,
        merchantNormalized,
        count,
        averageAmount,
        lastDate,
      ];
}
