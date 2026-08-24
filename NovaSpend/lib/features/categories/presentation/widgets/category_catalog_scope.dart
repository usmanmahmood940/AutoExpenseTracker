import 'package:flutter/material.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';

/// Exposes the category catalog fetched at sign-in by [CategoryColorBinder].
class CategoryCatalogScope extends InheritedWidget {
  const CategoryCatalogScope({
    required this.categories,
    required super.child,
    super.key,
  });

  final List<CategoryEntity> categories;

  static CategoryCatalogScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CategoryCatalogScope>();
  }

  static List<CategoryEntity> of(BuildContext context) {
    return maybeOf(context)?.categories ?? const [];
  }

  @override
  bool updateShouldNotify(CategoryCatalogScope oldWidget) {
    if (identical(categories, oldWidget.categories)) return false;
    if (categories.length != oldWidget.categories.length) return true;
    for (var i = 0; i < categories.length; i++) {
      if (categories[i] != oldWidget.categories[i]) return true;
    }
    return false;
  }
}
