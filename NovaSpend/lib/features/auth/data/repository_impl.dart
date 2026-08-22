import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/core/errors/failures.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';
import 'package:nova_spend/features/auth/data/datasource/firebase_auth_datasource.dart';
import 'package:nova_spend/features/auth/domain/entities/app_user.dart';
import 'package:nova_spend/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required FirebaseAuthDatasource datasource,
    BackendAuthDatasource? backendAuth,
  })  : _datasource = datasource,
        _backendAuth = backendAuth;

  final FirebaseAuthDatasource _datasource;
  final BackendAuthDatasource? _backendAuth;

  @override
  Stream<AppUser?> watchUser() => _datasource.watchUser();

  @override
  String? get currentUid => _datasource.currentUid;

  @override
  AppUser? get currentUser => _datasource.currentUser;

  @override
  Future<void> signOut() async {
    try {
      if (AppConstants.kUseBackendV1 && _backendAuth != null) {
        try {
          await _backendAuth.logout();
        } catch (_) {
          // Still clear the local Firebase session.
        }
      }
      await _datasource.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
