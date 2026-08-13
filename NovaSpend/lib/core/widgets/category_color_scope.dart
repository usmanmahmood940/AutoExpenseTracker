import 'package:flutter/material.dart';

import '../utils/category_visuals.dart';

/// Provides Firestore `categories/{id}.color` hex values to [CategoryAvatar].
class CategoryColorScope extends InheritedWidget {
  const CategoryColorScope({
    required this.hexByKey,
    required super.child,
    super.key,
  });

  /// Lowercase category id and display name → `#RRGGBB`.
  final Map<String, String> hexByKey;

  static CategoryColorScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CategoryColorScope>();
  }

  String? hexFor(String? category) {
    final key = (category ?? '').trim().toLowerCase();
    if (key.isEmpty) return null;
    return hexByKey[key] ?? hexByKey[resolveCategoryId(category)];
  }

  @override
  bool updateShouldNotify(CategoryColorScope oldWidget) {
    if (identical(hexByKey, oldWidget.hexByKey)) return false;
    if (hexByKey.length != oldWidget.hexByKey.length) return true;
    for (final entry in hexByKey.entries) {
      if (oldWidget.hexByKey[entry.key] != entry.value) return true;
    }
    return false;
  }
}
