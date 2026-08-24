import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/categories/data/datasource/backend_category_datasource.dart';
import 'package:nova_spend/features/categories/data/datasource/firestore_category_datasource.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required FirestoreCategoryDatasource datasource,
    BackendCategoryDatasource? backend,
  })  : _datasource = datasource,
        _backend = backend;

  final FirestoreCategoryDatasource _datasource;
  final BackendCategoryDatasource? _backend;

  bool get _useBackend => AppConstants.kUseBackendV1 && _backend != null;

  @override
  Stream<List<CategoryEntity>> watchDefaults() {
    if (_useBackend) return _backend!.watchDefaults();
    return _datasource.watchDefaults();
  }

  @override
  Stream<List<CategoryEntity>> watchUserCategories(String uid) {
    if (_useBackend) return _backend!.watchUserCategories();
    return _datasource.watchUserCategories(uid);
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
      if (_useBackend) {
        return await _backend!.createCustom(
          name: name,
          type: type,
          icon: icon,
          color: color,
        );
      }
      return await _datasource.createCustom(
        uid: uid,
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
