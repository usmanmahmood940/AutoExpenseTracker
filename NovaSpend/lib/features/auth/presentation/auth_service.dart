import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/http/cloud_functions_http_client.dart';
import 'package:nova_spend/firebase_options.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Firebase Auth + Cloud Functions auth orchestration used by [AuthPage].
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    CloudFunctionsHttpClient? functionsClient,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null && functionsClient == null,
        _functions = functionsClient ??
            CloudFunctionsHttpClient(client: httpClient ?? http.Client()),
        _googleSignIn = googleSignIn;

  final FirebaseAuth _auth;
  final http.Client _http;
  final bool _ownsHttp;
  final CloudFunctionsHttpClient _functions;
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

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return _auth.signInWithPopup(provider);
    }

    final google = _googleSignIn ?? GoogleSignIn.instance;
    if (!_googleInitialized && _googleSignIn == null) {
      await google.initialize();
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

  Future<void> signOut() => _auth.signOut();

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendEmailOtp({required String email}) async {
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
    await _functions.call(
      'sendPasswordResetOtp',
      data: {'email': email.trim()},
    );
  }

  Future<String> verifyPasswordResetOtp({
    required String email,
    required String code,
  }) async {
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
    await _functions.call(
      'completePasswordReset',
      data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> ensureUserProfile() async {
    await _functions.call('ensureUserProfile', requireAuth: true);
  }

  Future<bool> isEmailAlreadyInUse(String email) async {
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
