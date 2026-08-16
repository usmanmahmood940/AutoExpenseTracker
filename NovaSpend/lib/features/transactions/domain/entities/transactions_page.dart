import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';

class TransactionsPage {
  const TransactionsPage({
    required this.items,
    required this.hasMore,
    required this.totalCount,
    required this.totalAmount,
  });

  final List<TransactionEntity> items;
  final bool hasMore;
  final int totalCount;
  final double totalAmount;
}
