import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/errors/app_error_mapper.dart';
import 'package:nova_spend/core/http/cloud_functions_http_client.dart';
import 'package:nova_spend/features/auth/presentation/auth_error_mapper.dart';
import 'package:nova_spend/features/auth/presentation/auth_service.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

class AuthSubmitOutcome {
  const AuthSubmitOutcome({
    this.success = false,
    this.errorText,
    this.showVerificationScreen = false,
    this.verificationEmail,
    this.forceLoginMode = false,
  });

  final bool success;
  final String? errorText;
  final bool showVerificationScreen;
  final String? verificationEmail;
  final bool forceLoginMode;
}

/// Orchestrates login vs signup submit logic for [AuthPage].
class AuthSubmitFlow {
  AuthSubmitFlow(this._auth);

  final AuthService _auth;

  Future<AuthSubmitOutcome> submit({
    required bool isLogin,
    required String email,
    required String password,
    required AppLocalizations l10n,
    required bool acceptedTerms,
  }) async {
    try {
      if (isLogin) {
        return await _login(
          email: email,
          password: password,
          l10n: l10n,
        );
      }
      return await _signup(
        email: email,
        password: password,
        l10n: l10n,
        acceptedTerms: acceptedTerms,
      );
    } on FirebaseAuthException catch (e) {
      return AuthSubmitOutcome(
        errorText: AuthErrorMapper.friendlyAuthError(l10n, e.code, e.message),
      );
    } on PlatformException catch (e) {
      return AuthSubmitOutcome(
        errorText: AuthErrorMapper.friendlyPlatformAuthError(
          l10n,
          e.code,
          e.message,
        ),
      );
    } on CloudFunctionsHttpException catch (e) {
      return AuthSubmitOutcome(errorText: e.message);
    } catch (e) {
      return AuthSubmitOutcome(errorText: AppErrorMapper.message(l10n, e));
    }
  }

  Future<AuthSubmitOutcome> _login({
    required String email,
    required String password,
    required AppLocalizations l10n,
  }) async {
    final credential = await _auth.signIn(email: email, password: password);
    final user = credential.user;
    if (user == null) {
      return AuthSubmitOutcome(errorText: l10n.authWrongCredentials);
    }

    await _auth.reloadCurrentUser();
    final refreshed = _auth.currentUser ?? user;
    final token = await refreshed.getIdTokenResult(true);

    if (!AppConstants.kSkipEmailVerificationCheck &&
        !AuthService.hasVerifiedPortfolioAccess(user: refreshed, token: token)) {
      await _auth.signOut();
      return AuthSubmitOutcome(errorText: l10n.authEmailNotVerified);
    }

    return const AuthSubmitOutcome(success: true);
  }

  Future<AuthSubmitOutcome> _signup({
    required String email,
    required String password,
    required AppLocalizations l10n,
    required bool acceptedTerms,
  }) async {
    if (!acceptedTerms) {
      return AuthSubmitOutcome(errorText: l10n.authAcceptTermsError);
    }

    // Prefer Auth Admin check via Cloud Function — Identity Toolkit
    // createAuthUri is unreliable when email enumeration protection is on.
    try {
      final inUse = await _auth.isEmailAlreadyInUse(email);
      if (inUse) {
        return AuthSubmitOutcome(errorText: l10n.authEmailInUse);
      }
    } catch (_) {
      // Fall through to sendEmailOtp, which enforces existence server-side.
    }

    try {
      await _auth.sendEmailOtp(email: email);
    } on CloudFunctionsHttpException catch (e) {
      if (_isEmailInUseMessage(e.message)) {
        return AuthSubmitOutcome(errorText: l10n.authEmailInUse);
      }
      rethrow;
    }

    return AuthSubmitOutcome(
      showVerificationScreen: true,
      verificationEmail: email.trim(),
      forceLoginMode: true,
    );
  }

  static bool _isEmailInUseMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already in use') ||
        lower.contains('already-exists') ||
        lower.contains('email-already');
  }
}
