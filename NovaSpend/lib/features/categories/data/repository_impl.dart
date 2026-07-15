import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/categories/data/datasource/firestore_category_datasource.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({required FirestoreCategoryDatasource datasource})
      : _datasource = datasource;

  final FirestoreCategoryDatasource _datasource;

  @override
  Stream<List<CategoryEntity>> watchDefaults() => _datasource.watchDefaults();

  @override
  Stream<List<CategoryEntity>> watchUserCategories(String uid) {
    return _datasource.watchUserCategories(uid);
  }

  @override
  Future<String> createCustom({
    required String uid,
    required String name,
    required String type,
    String icon = 'label',
  }) async {
    try {
      return await _datasource.createCustom(
        uid: uid,
        name: name,
        type: type,
        icon: icon,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
