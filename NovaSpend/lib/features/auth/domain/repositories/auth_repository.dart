import 'package:nova_spend/features/auth/domain/entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchUser();

  Future<void> signOut();

  String? get currentUid;

  AppUser? get currentUser;
}
