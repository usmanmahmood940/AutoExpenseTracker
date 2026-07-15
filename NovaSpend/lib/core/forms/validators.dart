import 'package:nova_spend/l10n/app_localizations.dart';

/// Shared form validators for auth and other screens.
abstract final class AppValidators {
  static String? email(String? value, AppLocalizations l10n) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return l10n.authEnterValidEmail;
    }
    return null;
  }

  static String? password(String? value, AppLocalizations l10n) {
    final password = value ?? '';
    if (password.length < 6) {
      return l10n.authMinPassword;
    }
    return null;
  }

  static String? confirmPassword(
    String? value,
    String password,
    AppLocalizations l10n,
  ) {
    if ((value ?? '').trim() != password.trim()) {
      return l10n.authPasswordsDoNotMatch;
    }
    return null;
  }

  static String? otp(String? value, AppLocalizations l10n) {
    if ((value ?? '').trim().isEmpty) {
      return l10n.authEnterOtpCode;
    }
    return null;
  }
}
