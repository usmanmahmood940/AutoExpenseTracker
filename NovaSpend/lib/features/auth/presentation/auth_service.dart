import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/http/cloud_functions_http_client.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';
import 'package:nova_spend/firebase_options.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Firebase Auth + backend (or Cloud Functions) orchestration used by [AuthPage].
class AuthService {
  factory AuthService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    CloudFunctionsHttpClient? functionsClient,
    ApiClient? apiClient,
    BackendAuthDatasource? backendAuth,
    GoogleSignIn? googleSignIn,
  }) {
    final sharedHttp = httpClient ?? http.Client();
    final ownsHttp = httpClient == null &&
        functionsClient == null &&
        apiClient == null &&
        backendAuth == null;

    ApiClient? api = apiClient;
    var ownsApi = false;
    BackendAuthDatasource? backend = backendAuth;
    if (backend == null && AppConstants.kUseBackendV1) {
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
      functions: functionsClient ?? CloudFunctionsHttpClient(client: sharedHttp),
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
    required CloudFunctionsHttpClient functions,
    required ApiClient? api,
    required bool ownsApi,
    required BackendAuthDatasource? backend,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _http = http,
        _ownsHttp = ownsHttp,
        _functions = functions,
        _api = api,
        _ownsApi = ownsApi,
        _backend = backend,
        _googleSignIn = googleSignIn;

  final FirebaseAuth _auth;
  final http.Client _http;
  final bool _ownsHttp;
  final bool _ownsApi;
  final CloudFunctionsHttpClient _functions;
  final ApiClient? _api;
  final BackendAuthDatasource? _backend;
  final GoogleSignIn? _googleSignIn;
  bool _googleInitialized = false;

  bool get usesBackend => _backend != null;

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
    final backend = _backend;
    if (backend == null) {
      return signIn(email: email, password: password);
    }
    await backend.login(email: email, password: password);
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
    final backend = _backend;
    if (backend != null && _auth.currentUser != null) {
      try {
        await backend.logout();
      } catch (_) {
        // Still clear the local Firebase session.
      }
    }
    await _auth.signOut();
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendEmailOtp({required String email}) async {
    final backend = _backend;
    if (backend != null) {
      await backend.sendSignupOtp(email: email);
      return;
    }
    await _functions.call(
      'sendEmailOtp',
      data: {'email': email.trim()},
    );
  }

  Future<void> completeEmailOtpSignup({
    required String email,
    required String password,
    required String code,
  }) async {
    final backend = _backend;
    if (backend != null) {
      await backend.completeSignup(
        email: email,
        password: password,
        code: code,
      );
      return;
    }
    await _functions.call(
      'completeEmailOtpSignup',
      data: {
        'email': email.trim(),
        'password': password,
        'code': code.trim(),
      },
    );
  }

  Future<void> sendPasswordResetOtp({required String email}) async {
    final backend = _backend;
    if (backend != null) {
      await backend.forgotPassword(email: email);
      return;
    }
    await _functions.call(
      'sendPasswordResetOtp',
      data: {'email': email.trim()},
    );
  }

  Future<String> verifyPasswordResetOtp({
    required String email,
    required String code,
  }) async {
    final backend = _backend;
    if (backend != null) {
      return backend.verifyResetOtp(email: email, code: code);
    }
    final result = await _functions.call(
      'verifyPasswordResetOtp',
      data: {
        'email': email.trim(),
        'code': code.trim(),
      },
    );
    final token = result['resetToken']?.toString();
    if (token == null || token.isEmpty) {
      throw CloudFunctionsHttpException(
        statusCode: 500,
        message: 'Missing reset token',
      );
    }
    return token;
  }

  Future<void> completePasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    final backend = _backend;
    if (backend != null) {
      await backend.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      return;
    }
    await _functions.call(
      'completePasswordReset',
      data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> ensureUserProfile() async {
    final backend = _backend;
    if (backend != null) {
      await backend.getMe();
      return;
    }
    await _functions.call('ensureUserProfile', requireAuth: true);
  }

  /// Postgres profile from `GET /me`, or null on the Cloud Functions path.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final backend = _backend;
    if (backend == null) return null;
    return backend.getMe();
  }

  Future<bool> isEmailAlreadyInUse(String email) async {
    // Backend signup OTP enforces existence; Identity Toolkit createAuthUri is
    // unreliable when email enumeration protection is on.
    if (_backend != null) return false;

    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$apiKey',
    );
    final response = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': email.trim(),
        'continueUri': AppConstants.productionSiteUrl,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      return body['registered'] == true;
    }
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
    _functions.dispose();
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
