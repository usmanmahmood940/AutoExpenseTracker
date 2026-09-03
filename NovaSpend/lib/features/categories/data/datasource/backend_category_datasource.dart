import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';

class BackendCategoryDatasource {
  BackendCategoryDatasource({required ApiClient api}) : _api = api;

  final ApiClient _api;
  List<CategoryEntity>? _cache;

  Future<List<CategoryEntity>> listCategories({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    try {
      final json = await _api.get('/categories', requireAuth: true);
      final raw = json['items'];
      final items = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => categoryFromApi(Map<String, dynamic>.from(item)))
                .toList()
          : <CategoryEntity>[];
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _cache = items;
      return items;
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }

  Stream<List<CategoryEntity>> watchAll() async* {
    yield await listCategories();
  }

  Future<String> createCustom({
    required String name,
    required String type,
    String icon = 'label',
    String color = '#757575',
  }) async {
    try {
      final created = await _api.post(
        '/categories',
        body: {'name': name.trim(), 'type': type, 'icon': icon, 'color': color},
        requireAuth: true,
      );
      _cache = null;
      return created['id']?.toString() ?? '';
    } on ApiException catch (e) {
      throw e.toDataException();
    }
  }
}
