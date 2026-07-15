import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/auth/domain/entities/app_user.dart';
import 'package:nova_spend/features/auth/domain/repositories/auth_repository.dart';

/// Watches Firebase auth session for shell / settings (no anonymous sign-in).
class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    _user = _authRepository.currentUser;
    _isLoading = false;
    _subscription = _authRepository.watchUser().listen((user) {
      _user = user;
      _isLoading = false;
      _error = null;
      notifyListeners();
    });
  }

  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _subscription;

  AppUser? _user;
  bool _isLoading = true;
  String? _error;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;
  String? get uid => _user?.id ?? _authRepository.currentUid;
  String? get error => _error;

  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
