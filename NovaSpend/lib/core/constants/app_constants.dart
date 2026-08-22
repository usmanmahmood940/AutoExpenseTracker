/// App-wide constants for Firebase paths and webhook endpoints.
class AppConstants {
  AppConstants._();

  static const String projectId = 'auto-expense-tracker-2026';
  static const String region = 'asia-south1';

  /// FastAPI (Cloud Run) base URL for Phase E+.
  static const String apiBaseUrl =
      'https://novaspend-api-h7asbihbya-el.a.run.app';

  /// When true, product screens and auth OTP/login/reset use FastAPI
  /// instead of Firestore / Cloud Functions.
  /// Disable with `--dart-define=USE_BACKEND_V1=false`.
  static const bool kUseBackendV1 = bool.fromEnvironment(
    'USE_BACKEND_V1',
    defaultValue: true,
  );

  /// Dev Shortcuts should hit FastAPI `/ingest`. Production stays on the
  /// Cloud Function until the Phase F freeze.
  static String get ingestForUserUrl => kUseBackendV1
      ? '$apiBaseUrl/ingest'
      : 'https://asia-south1-auto-expense-tracker-2026.cloudfunctions.net/ingestTransactionForUser';

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
