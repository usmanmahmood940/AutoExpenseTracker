import 'package:firebase_auth/firebase_auth.dart';
import 'package:nova_spend/features/auth/domain/services/user_account_service.dart';

class FirebaseUserAccountService implements UserAccountService {
  FirebaseUserAccountService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> reauthenticate({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user',
      );
    }

    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('password') &&
        password != null &&
        password.isNotEmpty) {
      await reauthenticate(password: password);
    }

    await user.delete();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
