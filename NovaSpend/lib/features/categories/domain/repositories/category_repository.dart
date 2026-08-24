import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';

abstract class CategoryRepository {
  Stream<List<CategoryEntity>> watchDefaults();

  Stream<List<CategoryEntity>> watchUserCategories(String uid);

  /// Defaults plus the signed-in user's custom categories, already sorted.
  Stream<List<CategoryEntity>> watchAll(String uid);

  Future<String> createCustom({
    required String uid,
    required String name,
    required String type,
    String icon = 'label',
    String color = '#757575',
  });
}
