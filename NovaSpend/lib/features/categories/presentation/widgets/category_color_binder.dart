import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/widgets/category_color_scope.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';

/// Watches Firestore default categories and exposes their colors to the tree.
class CategoryColorBinder extends StatefulWidget {
  const CategoryColorBinder({required this.child, super.key});

  final Widget child;

  @override
  State<CategoryColorBinder> createState() => _CategoryColorBinderState();
}

class _CategoryColorBinderState extends State<CategoryColorBinder> {
  StreamSubscription<List<CategoryEntity>>? _sub;
  String? _uid;
  Map<String, String> _hexByKey = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().uid;
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    if (uid == null) {
      if (_hexByKey.isNotEmpty) {
        setState(() => _hexByKey = const {});
      }
      return;
    }
    _sub = sl<CategoryRepository>().watchDefaults().listen(
      (categories) {
        if (!mounted) return;
        setState(() => _hexByKey = _indexColors(categories));
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _hexByKey = const {});
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CategoryColorScope(hexByKey: _hexByKey, child: widget.child);
  }
}

Map<String, String> _indexColors(List<CategoryEntity> categories) {
  final map = <String, String>{};
  for (final category in categories) {
    final hex = category.color.trim();
    if (hex.isEmpty) continue;
    map[category.id.toLowerCase()] = hex;
    map[category.name.toLowerCase()] = hex;
  }
  return map;
}
