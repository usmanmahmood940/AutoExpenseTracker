import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/features/transactions/domain/entities/transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class GetTransactionsPage {
  GetTransactionsPage(this._repository);

  final TransactionRepository _repository;

  Future<TransactionsPage> call(
    String uid, {
    int limit = 50,
    TransactionEntity? startAfter,
    TransactionFilter? filter,
    String? dateFrom,
    String? dateTo,
    String sortBy = 'date',
    String orderBy = 'desc',
  }) {
    return _repository.getTransactionsPage(
      uid,
      limit: limit,
      startAfter: startAfter,
      filter: filter,
      dateFrom: dateFrom,
      dateTo: dateTo,
      sortBy: sortBy,
      orderBy: orderBy,
    );
  }
}
