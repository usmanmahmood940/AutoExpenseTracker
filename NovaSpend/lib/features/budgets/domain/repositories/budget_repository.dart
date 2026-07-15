import 'package:nova_spend/features/budgets/domain/entities/budget_entity.dart';

abstract class BudgetRepository {
  Stream<List<BudgetEntity>> watchBudgets(String uid);

  Future<void> saveBudget(String uid, BudgetEntity budget);

  Future<void> deleteBudget(String uid, String budgetId);
}
