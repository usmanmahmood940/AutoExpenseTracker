import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/errors/app_error_mapper.dart';
import 'package:nova_spend/features/auth/presentation/auth_error_mapper.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('AuthErrorMapper', () {
    test('maps wrong credentials codes', () {
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'wrong-password', null),
        l10n.authWrongCredentials,
      );
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'invalid-credential', null),
        l10n.authWrongCredentials,
      );
    });

    test('maps email already in use', () {
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'email-already-in-use', null),
        l10n.authEmailInUse,
      );
    });

    test('maps network and rate limits', () {
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'network-request-failed', null),
        l10n.authNetworkError,
      );
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'too-many-requests', null),
        l10n.authTooManyRequests,
      );
    });

    test('maps account-exists-with-different-credential', () {
      expect(
        AuthErrorMapper.friendlyAuthError(
          l10n,
          'account-exists-with-different-credential',
          null,
        ),
        l10n.authAccountExistsDifferentCredential,
      );
      expect(
        AuthErrorMapper.friendlyGoogleAccountExists(l10n),
        l10n.authGoogleAccountExists,
      );
      expect(
        AuthErrorMapper.friendlyAppleAccountExists(l10n),
        l10n.authAppleAccountExists,
      );
    });

    test('maps remaining auth codes', () {
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'user-not-found', null),
        l10n.authUserNotFound,
      );
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'weak-password', null),
        l10n.authWeakPassword,
      );
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'user-disabled', null),
        l10n.authSignInDisabled,
      );
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'invalid-api-key', null),
        l10n.authInvalidApiKey,
      );
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'unauthorized-domain', null),
        l10n.authUnauthorizedDomain,
      );
      expect(
        AuthErrorMapper.friendlyAuthError(l10n, 'popup-blocked', null),
        l10n.authBrowserHandshakeError,
      );
    });

    test('maps platform cancel as cancelled', () {
      expect(
        AuthErrorMapper.friendlyPlatformAuthError(
          l10n,
          'sign_in_canceled',
          null,
        ),
        l10n.authSignInCancelled,
      );
      expect(
        AuthErrorMapper.friendlyPlatformAuthError(l10n, '12501', null),
        l10n.authSignInCancelled,
      );
    });
  });

  group('AppErrorMapper', () {
    test('delegates FirebaseAuthException to AuthErrorMapper', () {
      final error = FirebaseAuthException(
        code: 'wrong-password',
        message: 'bad',
      );
      expect(
        AppErrorMapper.message(l10n, error),
        l10n.authWrongCredentials,
      );
    });

    test('delegates PlatformException cancel', () {
      final error = PlatformException(code: 'sign_in_canceled');
      expect(
        AppErrorMapper.message(l10n, error),
        l10n.authSignInCancelled,
      );
    });
  });
}
