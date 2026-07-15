import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/features/budgets/domain/entities/budget_entity.dart';

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class BudgetModel {
  BudgetModel(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  factory BudgetModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BudgetModel(doc.id, doc.data() ?? {});
  }

  BudgetEntity toEntity() {
    return BudgetEntity(
      id: id,
      category: data['category'] as String? ?? '',
      limit: (data['limit'] as num?)?.toDouble() ?? 0,
      period: data['period'] as String? ?? 'monthly',
      currency: data['currency'] as String? ?? 'PKR',
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({required bool isNew}) {
    return {
      'category': data['category'],
      'limit': data['limit'],
      'period': data['period'] ?? 'monthly',
      'currency': data['currency'] ?? 'PKR',
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
