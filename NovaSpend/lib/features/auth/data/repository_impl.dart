import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/auth/data/datasource/firebase_auth_datasource.dart';
import 'package:nova_spend/features/auth/domain/entities/app_user.dart';
import 'package:nova_spend/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required FirebaseAuthDatasource datasource})
      : _datasource = datasource;

  final FirebaseAuthDatasource _datasource;

  @override
  Stream<AppUser?> watchUser() => _datasource.watchUser();

  @override
  String? get currentUid => _datasource.currentUid;

  @override
  AppUser? get currentUser => _datasource.currentUser;

  @override
  Future<void> signOut() async {
    try {
      await _datasource.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
