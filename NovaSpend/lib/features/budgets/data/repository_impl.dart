import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/budgets/data/datasource/firestore_budget_datasource.dart';
import 'package:nova_spend/features/budgets/domain/entities/budget_entity.dart';
import 'package:nova_spend/features/budgets/domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl({required FirestoreBudgetDatasource datasource})
      : _datasource = datasource;

  final FirestoreBudgetDatasource _datasource;

  @override
  Stream<List<BudgetEntity>> watchBudgets(String uid) {
    return _datasource.watchBudgets(uid);
  }

  @override
  Future<void> saveBudget(String uid, BudgetEntity budget) async {
    try {
      await _datasource.saveBudget(uid, budget);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteBudget(String uid, String budgetId) async {
    try {
      await _datasource.deleteBudget(uid, budgetId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
