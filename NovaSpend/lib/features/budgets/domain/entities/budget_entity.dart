import 'package:equatable/equatable.dart';

class BudgetEntity extends Equatable {
  const BudgetEntity({
    required this.id,
    required this.category,
    required this.limit,
    required this.period,
    required this.currency,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String category;
  final double limit;
  final String period;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props =>
      [id, category, limit, period, currency, createdAt, updatedAt];
}
