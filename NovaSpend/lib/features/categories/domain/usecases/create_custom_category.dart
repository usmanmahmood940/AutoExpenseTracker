import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';

class CreateCustomCategory {
  CreateCustomCategory(this._repository);

  final CategoryRepository _repository;

  Future<String> call({
    required String uid,
    required String name,
    required String type,
    String icon = 'label',
  }) {
    return _repository.createCustom(
      uid: uid,
      name: name,
      type: type,
      icon: icon,
    );
  }
}
