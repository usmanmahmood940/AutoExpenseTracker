import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/features/categories/data/models/category_model.dart';
import 'package:nova_spend/features/categories/domain/entities/category_entity.dart';
import 'package:uuid/uuid.dart';

class FirestoreCategoryDatasource {
  FirestoreCategoryDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  Stream<List<CategoryEntity>> watchDefaults() {
    return _db
        .collection(AppConstants.categories)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => CategoryModel.fromFirestore(d).toEntity(isDefault: true))
          .toList();
    });
  }

  Stream<List<CategoryEntity>> watchUserCategories(String uid) {
    return _db
        .collection(AppConstants.users)
        .doc(uid)
        .collection(AppConstants.categories)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => CategoryModel.fromFirestore(d).toEntity(isDefault: false))
          .toList();
    });
  }

  Future<String> createCustom({
    required String uid,
    required String name,
    required String type,
    String icon = 'label',
  }) async {
    try {
      final id = _uuid.v4();
      final now = FieldValue.serverTimestamp();
      await _db
          .collection(AppConstants.users)
          .doc(uid)
          .collection(AppConstants.categories)
          .doc(id)
          .set({
        'name': name.trim(),
        'type': type,
        'icon': icon,
        'sortOrder': 1000,
        'isDefault': false,
        'createdAt': now,
        'updatedAt': now,
      });
      return id;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create category');
    }
  }
}
