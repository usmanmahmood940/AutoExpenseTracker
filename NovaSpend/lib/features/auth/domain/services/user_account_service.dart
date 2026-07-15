/// Contract for post-auth account operations (not full auth repository).
abstract class UserAccountService {
  Future<void> signOut();

  Future<void> deleteAccount({String? password});

  Future<void> reauthenticate({required String password});

  Future<void> sendPasswordResetEmail(String email);
}
