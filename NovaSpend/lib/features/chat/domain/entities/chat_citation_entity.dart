import 'package:equatable/equatable.dart';

class ChatCitationEntity extends Equatable {
  const ChatCitationEntity({
    this.transactionId,
    this.date,
    this.amount,
    this.merchant,
    this.category,
  });

  final String? transactionId;
  final String? date;
  final double? amount;
  final String? merchant;
  final String? category;

  @override
  List<Object?> get props => [transactionId, date, amount, merchant, category];
}
