/// App-wide constants for Firebase paths and webhook endpoints.
class AppConstants {
  AppConstants._();

  static const String projectId = 'auto-expense-tracker-2026';
  static const String region = 'asia-south1';

  static const String ingestForUserUrl =
      'https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransactionForUser';

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

  /// Dev override: `--dart-define=SKIP_EMAIL_VERIFICATION_CHECK=true`
  static const bool kSkipEmailVerificationCheck = bool.fromEnvironment(
    'SKIP_EMAIL_VERIFICATION_CHECK',
    defaultValue: false,
  );

  static const int otpResendCooldownSeconds = 30;

  static const String users = 'users';
  static const String transactions = 'transactions';
  static const String rawIngestions = 'raw_ingestions';
  static const String categories = 'categories';
  static const String merchantCategoryOverrides = 'merchantCategoryOverrides';
  static const String monthlySummaries = 'monthlySummaries';
  static const String meta = 'meta';

  static const double confidenceReviewThreshold = 0.8;

  static const String prefBiometricLock = 'biometric_lock_enabled';
  static const String localePreferenceKey = 'app_locale';
  static const String currencyPreferenceKey = 'app_currency';
  static const String showDecimalsPreferenceKey = 'show_decimals';
}

String normalizeMerchantKey(String merchant) {
  return merchant.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
