import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class CategoryModel {
  CategoryModel(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  factory CategoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CategoryModel(doc.id, doc.data() ?? {});
  }

  CategoryEntity toEntity({bool? isDefault}) {
    return CategoryEntity(
      id: id,
      name: data['name'] as String? ?? id,
      type: data['type'] as String? ?? 'expense',
      icon: data['icon'] as String? ?? 'label',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isDefault: isDefault ?? data['isDefault'] as bool? ?? false,
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }
}
