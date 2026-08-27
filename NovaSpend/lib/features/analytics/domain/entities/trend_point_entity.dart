import 'package:equatable/equatable.dart';

class TrendPointEntity extends Equatable {
  const TrendPointEntity({required this.date, required this.debit});

  final DateTime date;
  final double debit;

  @override
  List<Object?> get props => [date, debit];
}
