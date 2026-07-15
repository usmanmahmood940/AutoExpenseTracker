import 'package:firebase_auth/firebase_auth.dart';
import 'package:nova_spend/core/errors/exceptions.dart';
import 'package:nova_spend/features/auth/domain/entities/app_user.dart';

class FirebaseAuthDatasource {
  FirebaseAuthDatasource({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<AppUser?> watchUser() {
    return _auth.authStateChanges().map(_mapUser);
  }

  String? get currentUid => _auth.currentUser?.uid;

  AppUser? get currentUser => _mapUser(_auth.currentUser);

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign-out failed');
    }
  }

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(id: user.uid, isAnonymous: user.isAnonymous);
  }
}
