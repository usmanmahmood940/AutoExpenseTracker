import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';
import 'package:nova_spend/features/categories/domain/usecases/create_custom_category.dart';

class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider({
    required CategoryRepository repository,
    required CreateCustomCategory createCustomCategory,
  })  : _repository = repository,
        _createCustomCategory = createCustomCategory;

  final CategoryRepository _repository;
  final CreateCustomCategory _createCustomCategory;

  StreamSubscription<List<CategoryEntity>>? _defaultsSub;
  StreamSubscription<List<CategoryEntity>>? _customSub;

  List<CategoryEntity> defaults = [];
  List<CategoryEntity> custom = [];
  bool isLoading = true;
  String? error;

  void start(String uid) {
    _defaultsSub?.cancel();
    _customSub?.cancel();
    isLoading = true;
    notifyListeners();

    _defaultsSub = _repository.watchDefaults().listen((list) {
      defaults = list;
      isLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });

    _customSub = _repository.watchUserCategories(uid).listen((list) {
      custom = list;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      notifyListeners();
    });
  }

  Future<void> addCategory({
    required String uid,
    required String name,
    required String type,
  }) async {
    await _createCustomCategory(uid: uid, name: name, type: type);
  }

  @override
  void dispose() {
    _defaultsSub?.cancel();
    _customSub?.cancel();
    super.dispose();
  }
}
