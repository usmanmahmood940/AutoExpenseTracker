import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Firebase Auth (session + Google/Apple) + FastAPI orchestration for [AuthPage].
class AuthService {
  factory AuthService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    ApiClient? apiClient,
    BackendAuthDatasource? backendAuth,
    GoogleSignIn? googleSignIn,
  }) {
    final sharedHttp = httpClient ?? http.Client();
    final ownsHttp = httpClient == null &&
        apiClient == null &&
        backendAuth == null;

    ApiClient? api = apiClient;
    var ownsApi = false;
    var backend = backendAuth;
    if (backend == null) {
      if (api == null) {
        api = ApiClient(client: sharedHttp);
        ownsApi = true;
      }
      backend = BackendAuthDatasource(api: api);
    }

    return AuthService._(
      auth: auth ?? FirebaseAuth.instance,
      http: sharedHttp,
      ownsHttp: ownsHttp,
      api: api,
      ownsApi: ownsApi,
      backend: backend,
      googleSignIn: googleSignIn,
    );
  }

  AuthService._({
    required FirebaseAuth auth,
    required http.Client http,
    required bool ownsHttp,
    required ApiClient? api,
    required bool ownsApi,
    required BackendAuthDatasource backend,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _http = http,
        _ownsHttp = ownsHttp,
        _api = api,
        _ownsApi = ownsApi,
        _backend = backend,
        _googleSignIn = googleSignIn;

  final FirebaseAuth _auth;
  final http.Client _http;
  final bool _ownsHttp;
  final bool _ownsApi;
  final ApiClient? _api;
  final BackendAuthDatasource _backend;
  final GoogleSignIn? _googleSignIn;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Backend login (rate limits + profile) then Firebase session for AuthGate.
  Future<UserCredential> loginWithBackend({
    required String email,
    required String password,
  }) async {
    await _backend.login(email: email, password: password);
    return signIn(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return _auth.signInWithPopup(provider);
    }

    final google = _googleSignIn ?? GoogleSignIn.instance;
    if (!_googleInitialized && _googleSignIn == null) {
      await google.initialize(
        serverClientId: AppConstants.googleServerClientId,
      );
      _googleInitialized = true;
    }

    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Missing Google ID token',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      try {
        return await _auth.signInWithPopup(provider);
      } catch (_) {
        return _auth.signInWithProvider(provider);
      }
    }

    final rawNonce = _generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauth = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );
    return _auth.signInWithCredential(oauth);
  }

  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      try {
        await _backend.logout();
      } catch (_) {
        // Still clear the local Firebase session.
      }
    }
    await _auth.signOut();
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendEmailOtp({required String email}) {
    return _backend.sendSignupOtp(email: email);
  }

  Future<void> completeEmailOtpSignup({
    required String email,
    required String password,
    required String code,
  }) {
    return _backend.completeSignup(
      email: email,
      password: password,
      code: code,
    );
  }

  Future<void> sendPasswordResetOtp({required String email}) {
    return _backend.forgotPassword(email: email);
  }

  Future<String> verifyPasswordResetOtp({
    required String email,
    required String code,
  }) {
    return _backend.verifyResetOtp(email: email, code: code);
  }

  Future<void> completePasswordReset({
    required String resetToken,
    required String newPassword,
  }) {
    return _backend.resetPassword(
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }

  Future<void> ensureUserProfile() {
    return _backend.getMe();
  }

  Future<Map<String, dynamic>?> fetchProfile() {
    return _backend.getMe();
  }

  /// Live uniqueness is enforced by signup OTP. Always false on the API path.
  Future<bool> isEmailAlreadyInUse(String email) async {
    if (email.trim().isEmpty) return false;
    return false;
  }

  static bool hasVerifiedPortfolioAccess({
    required User user,
    required IdTokenResult token,
  }) {
    final claims = token.claims ?? const <String, dynamic>{};
    if (claims['emailOtpVerified'] == true) return true;
    if (claims['email_verified'] == true) return true;
    if (user.emailVerified) return true;
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('google.com') || providers.contains('apple.com')) {
      return true;
    }
    return false;
  }

  void dispose() {
    if (_ownsApi) {
      _api?.dispose();
    }
    if (_ownsHttp) {
      _http.close();
    }
  }
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final values = List<int>.generate(
    length,
    (i) => (DateTime.now().microsecondsSinceEpoch + i) % charset.length,
  );
  return String.fromCharCodes(values.map((i) => charset.codeUnitAt(i)));
}
