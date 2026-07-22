// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NovaSpend';

  @override
  String get homeWelcome => 'Welcome to NovaSpend';

  @override
  String get navFeed => 'Feed';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navInsights => 'Insights';

  @override
  String get navReview => 'Review';

  @override
  String get navSettings => 'Settings';

  @override
  String get searchPlaceholder =>
      'Search is coming soon. You\'ll be able to find transactions by merchant, category, and more.';

  @override
  String get searchHint => 'Search transactions';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchClearRecent => 'Clear';

  @override
  String get searchQuickFilters => 'Quick filters';

  @override
  String get searchFilterThisMonth => 'This month';

  @override
  String get searchFilterDebits => 'Debits';

  @override
  String get searchFilterCredits => 'Credits';

  @override
  String get searchFilterSubscriptions => 'Subscriptions';

  @override
  String get searchEmptyTitle => 'Search by merchant, category, or bank';

  @override
  String get searchEmptyHint => 'Examples: KFC, Food, Meezan';

  @override
  String get searchNoResults => 'No transactions match your search';

  @override
  String searchResultsCount(String count) {
    return 'Results ($count)';
  }

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionPrivacy => 'Privacy';

  @override
  String get settingsSectionSetup => 'Setup';

  @override
  String get settingsSectionAdvanced => 'Advanced';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsFixParsing => 'Fix parsing issues';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsUserId => 'Your user ID';

  @override
  String get settingsUserIdHint => 'Use this UID in iOS Shortcuts (X-User-Id)';

  @override
  String get settingsCopyUid => 'Copy UID';

  @override
  String get settingsUidCopied => 'UID copied';

  @override
  String get settingsWebhookUrl => 'Webhook URL';

  @override
  String get settingsCopyWebhook => 'Copy webhook URL';

  @override
  String get settingsWebhookCopied => 'Webhook URL copied';

  @override
  String get settingsSyncHealth => 'Sync health';

  @override
  String get settingsLastSynced => 'Last synced';

  @override
  String get settingsNeverSynced => 'No transactions synced yet';

  @override
  String get settingsLastMerchant => 'Last merchant';

  @override
  String get settingsOnboarding => 'Bank & Shortcut setup';

  @override
  String get settingsOnboardingBody =>
      '1. Open the Shortcuts app and add the Process Bank SMS automation.\n2. Set the webhook URL below.\n3. Set the X-User-Id header to your UID.\n4. Supported bank today: Meezan (extend Shortcuts for other SMS formats).';

  @override
  String get settingsSupportedBanks => 'Supported banks';

  @override
  String get settingsBankMeezan => 'Meezan Bank';

  @override
  String get settingsLanguageSection => 'Preferences';

  @override
  String get settingsBiometric => 'Require Face ID / biometrics';

  @override
  String get settingsExport => 'Export CSV';

  @override
  String get settingsExportDone => 'CSV ready to share';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get homeTitle => 'Home';

  @override
  String get homePeriodToday => 'Today';

  @override
  String get homePeriodThisWeek => 'This week';

  @override
  String get homePeriodThisMonth => 'This month';

  @override
  String homeSpentSummary(String amount) {
    return '$amount spent';
  }

  @override
  String homeReceivedSummary(String amount) {
    return '$amount received';
  }

  @override
  String get homeEmpty => 'No transactions yet';

  @override
  String get homeEmptyHint =>
      'Set up the iOS Shortcut to start seeing your spending automatically.';

  @override
  String get homeEmptySetupCta => 'Open setup guide';

  @override
  String get homeBrandName => 'NovaSpend';

  @override
  String get homeRecentTransactions => 'Recent Transactions';

  @override
  String get homeViewAll => 'View All';

  @override
  String get homeHighestSpend => 'Highest spend';

  @override
  String get homeHighestReceived => 'Highest received';

  @override
  String get homeHighlightNone => 'No activity yet';

  @override
  String homeReceivedWithSign(String amount) {
    return '+ $amount received';
  }

  @override
  String homeHighlightSubtitle(String merchant, String day) {
    return '$merchant • $day';
  }

  @override
  String get homeAddTransaction => 'Add transaction';

  @override
  String get homePeriodEmpty => 'No transactions in this period';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String reviewBannerMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need review',
      one: '1 item needs review',
    );
    return '$_temp0';
  }

  @override
  String get merchantPlaceholder =>
      'Merchant details are coming soon. You\'ll see spending history and trends here.';

  @override
  String merchantTotalVisits(String total, String visits) {
    return '$total total · $visits visits';
  }

  @override
  String merchantAverage(String amount) {
    return 'Avg $amount per visit';
  }

  @override
  String merchantThisMonth(String amount, String visits) {
    return 'This month: $amount ($visits visits)';
  }

  @override
  String get merchantAllTransactions => 'All transactions';

  @override
  String get merchantEmpty => 'No transactions for this merchant';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get feedTitle => 'Transactions';

  @override
  String get feedEmpty => 'No transactions yet';

  @override
  String get feedEmptyHint =>
      'Send a bank SMS via your Shortcut to get started.';

  @override
  String get feedRefresh => 'Refresh';

  @override
  String get feedFilterAll => 'All accounts';

  @override
  String get feedSearchHint => 'Search merchant…';

  @override
  String get feedFilters => 'Filters';

  @override
  String get feedClearFilters => 'Clear';

  @override
  String get feedFilterCategory => 'Category';

  @override
  String get feedFilterBank => 'Bank';

  @override
  String get feedFilterType => 'Type';

  @override
  String get feedFilterTypeAll => 'All';

  @override
  String get feedFilterTypeDebit => 'Expense';

  @override
  String get feedFilterTypeCredit => 'Income';

  @override
  String get feedFilterAmountMin => 'Min amount';

  @override
  String get feedFilterAmountMax => 'Max amount';

  @override
  String get feedFilterDateFrom => 'From';

  @override
  String get feedFilterDateTo => 'To';

  @override
  String get feedApplyFilters => 'Apply';

  @override
  String get transactionDetail => 'Transaction';

  @override
  String get transactionEdit => 'Edit';

  @override
  String get transactionSave => 'Save';

  @override
  String get transactionMerchant => 'Merchant';

  @override
  String get transactionAmount => 'Amount';

  @override
  String get transactionCategory => 'Category';

  @override
  String get transactionType => 'Type';

  @override
  String get transactionBank => 'Bank';

  @override
  String get transactionAccount => 'Account';

  @override
  String get transactionDate => 'Date';

  @override
  String get transactionConfidence => 'Parse confidence';

  @override
  String get transactionRawSms => 'Original SMS';

  @override
  String get transactionSaved => 'Transaction updated';

  @override
  String get transactionAlsoOverride => 'Remember category for this merchant';

  @override
  String get reviewTitle => 'Review';

  @override
  String get reviewConfidenceSection => 'Low confidence';

  @override
  String get reviewParseSection => 'Needs parse';

  @override
  String get reviewDuplicatesSection => 'Duplicates skipped';

  @override
  String get reviewEmpty => 'Nothing to review';

  @override
  String get reviewConfirm => 'Confirm';

  @override
  String get reviewDismiss => 'Dismiss';

  @override
  String get reviewCompleteManually => 'Complete manually';

  @override
  String reviewConfidence(String percent) {
    return '$percent% confidence';
  }

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsThisMonth => 'This month';

  @override
  String get insightsSpent => 'Spent';

  @override
  String get insightsIncome => 'Income';

  @override
  String get insightsNet => 'Net';

  @override
  String get insightsVsPrevious => 'vs previous month';

  @override
  String get insightsByCategory => 'By category';

  @override
  String get insightsTrends => 'Spend over time';

  @override
  String get insightsTopMerchants => 'Top merchants';

  @override
  String get insightsCashFlow => 'Income vs expense';

  @override
  String get insightsEmpty => 'No summary for this month yet';

  @override
  String get insightsPrevMonth => 'Previous';

  @override
  String get insightsNextMonth => 'Next';

  @override
  String get authUnlockTitle => 'Unlock NovaSpend';

  @override
  String get authUnlockSubtitle => 'Authenticate to view your finances';

  @override
  String get authUnlockButton => 'Unlock';

  @override
  String get authLoading => 'Signing in…';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authLoginSubtitle => 'Sign in to track your spending';

  @override
  String get authSignupSubtitle => 'Set up NovaSpend in a minute';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authLogin => 'Log in';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authOr => 'OR';

  @override
  String get authContinueWithGoogle => 'Sign in with Google';

  @override
  String get authContinueWithApple => 'Sign in with Apple';

  @override
  String get authNeedAccount => 'Need an account? Sign up';

  @override
  String get authHaveAccount => 'Have an account? Log in';

  @override
  String get authBackToLogin => 'Back to login';

  @override
  String get authTermsConsent => 'I agree to the Terms and Privacy Policy';

  @override
  String get authAcceptTermsError =>
      'Please accept the Terms and Privacy Policy';

  @override
  String get authLegalPrefix => 'By continuing you agree to our';

  @override
  String get authAnd => 'and';

  @override
  String get authTerms => 'Terms';

  @override
  String get authPrivacy => 'Privacy Policy';

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String authVerifyEmailBody(String email) {
    return 'Enter the 6-digit code we sent to $email';
  }

  @override
  String get authOtpSentInstructions =>
      'Check your inbox for a verification code.';

  @override
  String get authOtpCodeLabel => 'Verification code';

  @override
  String get authVerifyOtp => 'Verify';

  @override
  String get authResendOtp => 'Resend code';

  @override
  String authResendOtpIn(String seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authEnterOtpCode => 'Enter the verification code';

  @override
  String authOtpResentTo(String email) {
    return 'OTP resent to $email';
  }

  @override
  String get authSignupSessionExpired =>
      'Signup session expired. Please sign up again.';

  @override
  String get authEmailVerifiedCreated =>
      'Email verified. Your account is ready.';

  @override
  String get authResetPasswordTitle => 'Reset password';

  @override
  String get authResetPasswordSubtitle =>
      'Enter your email to receive a reset code';

  @override
  String get authSendResetCode => 'Send reset code';

  @override
  String authPasswordResetOtpInstructions(String email) {
    return 'Enter the code we sent to $email';
  }

  @override
  String get authResetCodeSent =>
      'Reset code sent if this email is registered.';

  @override
  String get authCreateNewPasswordTitle => 'Create a new password';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authChangePassword => 'Change password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authPasswordChangedLogin => 'Password updated. Please log in.';

  @override
  String get authPasswordResetSessionExpired =>
      'Reset session expired. Start again.';

  @override
  String get authEmailNotVerified =>
      'Please verify your email before signing in.';

  @override
  String get authEnterValidEmail => 'Enter a valid email address';

  @override
  String get authMinPassword => 'Password must be at least 6 characters';

  @override
  String get authWrongCredentials => 'Incorrect email or password';

  @override
  String get authUserNotFound => 'No account found for this email';

  @override
  String get authEmailInUse => 'This email is already in use';

  @override
  String get authWeakPassword => 'Choose a stronger password';

  @override
  String get authNetworkError => 'Network error. Check your connection.';

  @override
  String get authTooManyRequests => 'Too many attempts. Try again later.';

  @override
  String get authAccountExistsDifferentCredential =>
      'An account already exists with a different sign-in method.';

  @override
  String get authGoogleAccountExists =>
      'This email is linked to another sign-in method. Try email or Apple.';

  @override
  String get authAppleAccountExists =>
      'This email is linked to another sign-in method. Try email or Google.';

  @override
  String get authSignInDisabled => 'Sign-in is disabled for this account.';

  @override
  String get authInvalidApiKey => 'Invalid API key configuration.';

  @override
  String get authUnauthorizedDomain =>
      'This domain is not authorized for sign-in.';

  @override
  String get authSignInCancelled => 'Sign-in was cancelled.';

  @override
  String get authBrowserHandshakeError =>
      'Browser blocked the sign-in popup. Allow popups and try again.';

  @override
  String authUnknownError(String message) {
    return 'Something went wrong ($message)';
  }

  @override
  String get authCheckingEmail => 'Checking email…';

  @override
  String get authDeleteAccount => 'Delete account';

  @override
  String get authDeleteAccountConfirm =>
      'This permanently deletes your account and signed-in access. Continue?';

  @override
  String get authDeleteAccountPasswordHint => 'Enter your password to confirm';

  @override
  String get authAccountDeleted => 'Your account was deleted.';

  @override
  String get authSendPasswordResetLink => 'Send password reset email';

  @override
  String get authPasswordResetLinkSent => 'Password reset email sent.';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorLoadFailed => 'Could not load data';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonOk => 'OK';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonAll => 'All';

  @override
  String get commonLoading => 'Loading…';

  @override
  String amountFormat(String currency, String amount) {
    return '$currency $amount';
  }
}
