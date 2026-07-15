import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/features/budgets/data/models/budget_model.dart';
import 'package:nova_spend/features/budgets/domain/entities/budget_entity.dart';
import 'package:uuid/uuid.dart';

class FirestoreBudgetDatasource {
  FirestoreBudgetDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> _budgets(String uid) => _db
      .collection(AppConstants.users)
      .doc(uid)
      .collection(AppConstants.budgets);

  Stream<List<BudgetEntity>> watchBudgets(String uid) {
    return _budgets(uid).snapshots().map((snap) {
      return snap.docs.map((d) => BudgetModel.fromFirestore(d).toEntity()).toList();
    });
  }

  Future<void> saveBudget(String uid, BudgetEntity budget) async {
    try {
      final id = budget.id.isEmpty ? _uuid.v4() : budget.id;
      final ref = _budgets(uid).doc(id);
      final exists = (await ref.get()).exists;
      await ref.set({
        'category': budget.category,
        'limit': budget.limit,
        'period': budget.period,
        'currency': budget.currency,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save budget');
    }
  }

  Future<void> deleteBudget(String uid, String budgetId) async {
    try {
      await _budgets(uid).doc(budgetId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete budget');
    }
  }
}
