import 'package:nova_spend/l10n/app_localizations.dart';

/// Maps Firebase Auth / platform error codes to localized strings.
abstract final class AuthErrorMapper {
  static String friendlyAuthError(
    AppLocalizations l10n,
    String? code,
    String? message,
  ) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return l10n.authWrongCredentials;
      case 'user-not-found':
        return l10n.authUserNotFound;
      case 'email-already-in-use':
      case 'email-already-exists':
        return l10n.authEmailInUse;
      case 'weak-password':
        return l10n.authWeakPassword;
      case 'network-request-failed':
        return l10n.authNetworkError;
      case 'too-many-requests':
        return l10n.authTooManyRequests;
      case 'account-exists-with-different-credential':
        return l10n.authAccountExistsDifferentCredential;
      case 'user-disabled':
      case 'operation-not-allowed':
        return l10n.authSignInDisabled;
      case 'invalid-api-key':
        return l10n.authInvalidApiKey;
      case 'unauthorized-domain':
        return l10n.authUnauthorizedDomain;
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return l10n.authSignInCancelled;
      case 'auth/popup-blocked':
      case 'popup-blocked':
        return l10n.authBrowserHandshakeError;
      default:
        if (message != null && message.trim().isNotEmpty) {
          return l10n.authUnknownError(message);
        }
        return l10n.authUnknownError(code ?? 'unknown');
    }
  }

  static String friendlyPlatformAuthError(
    AppLocalizations l10n,
    String? code,
    String? message,
  ) {
    final normalized = (code ?? '').toLowerCase();
    if (normalized.contains('cancel') ||
        normalized.contains('canceled') ||
        normalized == 'sign_in_canceled' ||
        normalized == '12501') {
      return l10n.authSignInCancelled;
    }
    if (normalized.contains('network')) {
      return l10n.authNetworkError;
    }
    return friendlyAuthError(l10n, code, message);
  }

  static String friendlyGoogleAccountExists(AppLocalizations l10n) {
    return l10n.authGoogleAccountExists;
  }

  static String friendlyAppleAccountExists(AppLocalizations l10n) {
    return l10n.authAppleAccountExists;
  }
}
