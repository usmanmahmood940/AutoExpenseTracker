/// App-wide constants for API endpoints and preferences.
class AppConstants {
  AppConstants._();

  static const String projectId = 'auto-expense-tracker-2026';

  /// FastAPI (Cloud Run) base URL.
  static const String apiBaseUrl =
      'https://novaspend-api-h7asbihbya-el.a.run.app';

  /// Product screens and auth OTP/login/reset use FastAPI.
  /// Kept as a compile-time switch for staged builds; default on.
  static const bool kUseBackendV1 = bool.fromEnvironment(
    'USE_BACKEND_V1',
    defaultValue: true,
  );

  static const String ingestForUserUrl = '$apiBaseUrl/ingest';

  /// Used by Identity Toolkit `createAuthUri` email existence checks.
  static const String productionSiteUrl =
      'https://auto-expense-tracker-2026.firebaseapp.com';

  /// Web OAuth client ID from Firebase (required as serverClientId for Google Sign-In on Android/iOS).
  static const String googleServerClientId =
      '598409230916-h3dapo9iq87opnii7rgc6a64j80v92ll.apps.googleusercontent.com';

  static const String termsUrl =
      'https://auto-expense-tracker-2026.firebaseapp.com/terms';
  static const String privacyUrl =
      'https://auto-expense-tracker-2026.firebaseapp.com/privacy';

  static const String appVersion = '1.1.0';

  static const String feedbackMailto =
      'mailto:support@novaspend.app?subject=NovaSpend%20Feedback';

  /// Dev override: `--dart-define=SKIP_EMAIL_VERIFICATION_CHECK=true`
  static const bool kSkipEmailVerificationCheck = bool.fromEnvironment(
    'SKIP_EMAIL_VERIFICATION_CHECK',
    defaultValue: false,
  );

  static const int otpResendCooldownSeconds = 30;

  static const double confidenceReviewThreshold = 0.8;

  static const String prefBiometricLock = 'biometric_lock_enabled';
  static const String localePreferenceKey = 'app_locale';
  static const String currencyPreferenceKey = 'app_currency';
  static const String showDecimalsPreferenceKey = 'show_decimals';
}

String normalizeMerchantKey(String merchant) {
  return merchant.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

const String kDefaultMerchant = 'Unknown';
const String kAtmMerchant = 'ATM';

/// Stored/display name. Cash withdrawals with no merchant become ATM.
///
/// Keep in sync with `resolveMerchant` in `functions/src/schema.ts` and
/// `resolve_merchant` in `backend/app/services/merchant_key.py`.
String resolveMerchant(
  String merchant, {
  required String category,
  required String paymentMethod,
}) {
  final trimmed = merchant.trim();
  final missing =
      trimmed.isEmpty || trimmed.toLowerCase() == 'unknown';
  if (missing && _isCashWithdrawal(category, paymentMethod)) {
    return kAtmMerchant;
  }
  return trimmed.isEmpty ? kDefaultMerchant : trimmed;
}

bool _isCashWithdrawal(String category, String paymentMethod) {
  final cat = category.trim().toLowerCase();
  return cat == 'cash withdrawal' ||
      cat == 'cash_withdrawal' ||
      paymentMethod.trim().toLowerCase() == 'atm_withdrawal';
}
