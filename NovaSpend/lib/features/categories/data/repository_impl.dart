import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/categories/data/datasource/backend_category_datasource.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required BackendCategoryDatasource backend,
  }) : _backend = backend;

  final BackendCategoryDatasource _backend;

  @override
  Stream<List<CategoryEntity>> watchAll(String uid) {
    return _backend.watchAll();
  }

  @override
  Future<String> createCustom({
    required String uid,
    required String name,
    required String type,
    String icon = 'label',
    String color = '#757575',
  }) async {
    try {
      return await _backend.createCustom(
        name: name,
        type: type,
        icon: icon,
        color: color,
      );
    } catch (e) {
      throwAsFailure(e);
    }
  }
}
