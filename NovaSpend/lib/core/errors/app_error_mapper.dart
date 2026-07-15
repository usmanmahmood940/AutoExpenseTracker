import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:nova_spend/features/auth/presentation/auth_error_mapper.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

/// Routes unexpected errors to localized user-facing messages.
abstract final class AppErrorMapper {
  static String message(AppLocalizations l10n, Object error) {
    if (error is FirebaseAuthException) {
      return AuthErrorMapper.friendlyAuthError(
        l10n,
        error.code,
        error.message,
      );
    }
    if (error is PlatformException) {
      return AuthErrorMapper.friendlyPlatformAuthError(
        l10n,
        error.code,
        error.message,
      );
    }
    final text = error.toString().trim();
    if (text.isEmpty) return l10n.errorGeneric;
    return text;
  }
}
