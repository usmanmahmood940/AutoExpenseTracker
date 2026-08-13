import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String type;
  final String icon;

  /// Psychology-based hex (`#RRGGBB`) from Firestore.
  final String color;
  final int sortOrder;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    icon,
    color,
    sortOrder,
    isDefault,
    createdAt,
    updatedAt,
  ];
}
