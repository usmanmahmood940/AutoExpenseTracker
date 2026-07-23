import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NovaSpend'**
  String get appTitle;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to NovaSpend'**
  String get homeWelcome;

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get navReview;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search is coming soon. You\'ll be able to find transactions by merchant, category, and more.'**
  String get searchPlaceholder;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get searchHint;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @searchClearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClearRecent;

  /// No description provided for @searchQuickFilters.
  ///
  /// In en, this message translates to:
  /// **'Quick filters'**
  String get searchQuickFilters;

  /// No description provided for @searchFilterThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get searchFilterThisMonth;

  /// No description provided for @searchFilterDebits.
  ///
  /// In en, this message translates to:
  /// **'Debits'**
  String get searchFilterDebits;

  /// No description provided for @searchFilterCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get searchFilterCredits;

  /// No description provided for @searchFilterSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get searchFilterSubscriptions;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search by merchant, category, or bank'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Examples: KFC, Food, Meezan'**
  String get searchEmptyHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No transactions match your search'**
  String get searchNoResults;

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'Results ({count})'**
  String searchResultsCount(String count);

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get settingsSectionSetup;

  /// No description provided for @settingsSectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsSectionAdvanced;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsFixParsing.
  ///
  /// In en, this message translates to:
  /// **'Fix parsing issues'**
  String get settingsFixParsing;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsUserId.
  ///
  /// In en, this message translates to:
  /// **'Your user ID'**
  String get settingsUserId;

  /// No description provided for @settingsUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Use this UID in iOS Shortcuts (X-User-Id)'**
  String get settingsUserIdHint;

  /// No description provided for @settingsCopyUid.
  ///
  /// In en, this message translates to:
  /// **'Copy UID'**
  String get settingsCopyUid;

  /// No description provided for @settingsUidCopied.
  ///
  /// In en, this message translates to:
  /// **'UID copied'**
  String get settingsUidCopied;

  /// No description provided for @settingsWebhookUrl.
  ///
  /// In en, this message translates to:
  /// **'Webhook URL'**
  String get settingsWebhookUrl;

  /// No description provided for @settingsCopyWebhook.
  ///
  /// In en, this message translates to:
  /// **'Copy webhook URL'**
  String get settingsCopyWebhook;

  /// No description provided for @settingsWebhookCopied.
  ///
  /// In en, this message translates to:
  /// **'Webhook URL copied'**
  String get settingsWebhookCopied;

  /// No description provided for @settingsSyncHealth.
  ///
  /// In en, this message translates to:
  /// **'Sync health'**
  String get settingsSyncHealth;

  /// No description provided for @settingsLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get settingsLastSynced;

  /// No description provided for @settingsNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'No transactions synced yet'**
  String get settingsNeverSynced;

  /// No description provided for @settingsLastMerchant.
  ///
  /// In en, this message translates to:
  /// **'Last merchant'**
  String get settingsLastMerchant;

  /// No description provided for @settingsOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Bank & Shortcut setup'**
  String get settingsOnboarding;

  /// No description provided for @settingsOnboardingBody.
  ///
  /// In en, this message translates to:
  /// **'1. Open the Shortcuts app and add the Process Bank SMS automation.\n2. Set the webhook URL below.\n3. Set the X-User-Id header to your UID.\n4. Supported bank today: Meezan (extend Shortcuts for other SMS formats).'**
  String get settingsOnboardingBody;

  /// No description provided for @settingsSupportedBanks.
  ///
  /// In en, this message translates to:
  /// **'Supported banks'**
  String get settingsSupportedBanks;

  /// No description provided for @settingsBankMeezan.
  ///
  /// In en, this message translates to:
  /// **'Meezan Bank'**
  String get settingsBankMeezan;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsLanguageSection;

  /// No description provided for @settingsBiometric.
  ///
  /// In en, this message translates to:
  /// **'Require Face ID / biometrics'**
  String get settingsBiometric;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get settingsExport;

  /// No description provided for @settingsExportDone.
  ///
  /// In en, this message translates to:
  /// **'CSV ready to share'**
  String get settingsExportDone;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homePeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homePeriodToday;

  /// No description provided for @homePeriodThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get homePeriodThisWeek;

  /// No description provided for @homePeriodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get homePeriodThisMonth;

  /// No description provided for @homeSpentSummary.
  ///
  /// In en, this message translates to:
  /// **'{amount} spent'**
  String homeSpentSummary(String amount);

  /// No description provided for @homeReceivedSummary.
  ///
  /// In en, this message translates to:
  /// **'{amount} received'**
  String homeReceivedSummary(String amount);

  /// No description provided for @homeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get homeEmpty;

  /// No description provided for @homeEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Set up the iOS Shortcut to start seeing your spending automatically.'**
  String get homeEmptyHint;

  /// No description provided for @homeEmptySetupCta.
  ///
  /// In en, this message translates to:
  /// **'Open setup guide'**
  String get homeEmptySetupCta;

  /// No description provided for @homeBrandName.
  ///
  /// In en, this message translates to:
  /// **'NovaSpend'**
  String get homeBrandName;

  /// No description provided for @homeRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get homeRecentTransactions;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeViewAll;

  /// No description provided for @homeHighestSpend.
  ///
  /// In en, this message translates to:
  /// **'Highest \nspend'**
  String get homeHighestSpend;

  /// No description provided for @homeHighestReceived.
  ///
  /// In en, this message translates to:
  /// **'Highest \nreceived'**
  String get homeHighestReceived;

  /// No description provided for @homeHighlightNone.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get homeHighlightNone;

  /// No description provided for @homeReceivedWithSign.
  ///
  /// In en, this message translates to:
  /// **'+ {amount} received'**
  String homeReceivedWithSign(String amount);

  /// No description provided for @homeHighlightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{merchant} • {day}'**
  String homeHighlightSubtitle(String merchant, String day);

  /// No description provided for @homeAddTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get homeAddTransaction;

  /// No description provided for @homePeriodEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period'**
  String get homePeriodEmpty;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @reviewBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item needs review} other{{count} items need review}}'**
  String reviewBannerMessage(int count);

  /// No description provided for @merchantPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Merchant details are coming soon. You\'ll see spending history and trends here.'**
  String get merchantPlaceholder;

  /// No description provided for @merchantTotalVisits.
  ///
  /// In en, this message translates to:
  /// **'{total} total · {visits} visits'**
  String merchantTotalVisits(String total, String visits);

  /// No description provided for @merchantAverage.
  ///
  /// In en, this message translates to:
  /// **'Avg {amount} per visit'**
  String merchantAverage(String amount);

  /// No description provided for @merchantThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month: {amount} ({visits} visits)'**
  String merchantThisMonth(String amount, String visits);

  /// No description provided for @merchantAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'All transactions'**
  String get merchantAllTransactions;

  /// No description provided for @merchantEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this merchant'**
  String get merchantEmpty;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get feedTitle;

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get feedEmpty;

  /// No description provided for @feedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Send a bank SMS via your Shortcut to get started.'**
  String get feedEmptyHint;

  /// No description provided for @feedRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get feedRefresh;

  /// No description provided for @feedFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get feedFilterAll;

  /// No description provided for @feedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search merchant…'**
  String get feedSearchHint;

  /// No description provided for @feedFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get feedFilters;

  /// No description provided for @feedClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get feedClearFilters;

  /// No description provided for @feedFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get feedFilterCategory;

  /// No description provided for @feedFilterBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get feedFilterBank;

  /// No description provided for @feedFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get feedFilterType;

  /// No description provided for @feedFilterTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get feedFilterTypeAll;

  /// No description provided for @feedFilterTypeDebit.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get feedFilterTypeDebit;

  /// No description provided for @feedFilterTypeCredit.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get feedFilterTypeCredit;

  /// No description provided for @feedFilterAmountMin.
  ///
  /// In en, this message translates to:
  /// **'Min amount'**
  String get feedFilterAmountMin;

  /// No description provided for @feedFilterAmountMax.
  ///
  /// In en, this message translates to:
  /// **'Max amount'**
  String get feedFilterAmountMax;

  /// No description provided for @feedFilterDateFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get feedFilterDateFrom;

  /// No description provided for @feedFilterDateTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get feedFilterDateTo;

  /// No description provided for @feedApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get feedApplyFilters;

  /// No description provided for @transactionDetail.
  ///
  /// In en, this message translates to:
  /// **'Transaction Detail'**
  String get transactionDetail;

  /// No description provided for @transactionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get transactionEdit;

  /// No description provided for @transactionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get transactionSave;

  /// No description provided for @transactionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transactionCancel;

  /// No description provided for @transactionMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get transactionMerchant;

  /// No description provided for @transactionAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get transactionAmount;

  /// No description provided for @transactionCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get transactionCategory;

  /// No description provided for @transactionType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get transactionType;

  /// No description provided for @transactionBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get transactionBank;

  /// No description provided for @transactionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get transactionAccount;

  /// No description provided for @transactionDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get transactionDate;

  /// No description provided for @transactionConfidence.
  ///
  /// In en, this message translates to:
  /// **'Parse confidence'**
  String get transactionConfidence;

  /// No description provided for @transactionRawSms.
  ///
  /// In en, this message translates to:
  /// **'Original SMS'**
  String get transactionRawSms;

  /// No description provided for @transactionPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get transactionPaymentMethod;

  /// No description provided for @transactionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get transactionStatus;

  /// No description provided for @transactionReferenceId.
  ///
  /// In en, this message translates to:
  /// **'Reference ID'**
  String get transactionReferenceId;

  /// No description provided for @transactionStatusCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get transactionStatusCleared;

  /// No description provided for @transactionStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get transactionStatusDeleted;

  /// No description provided for @transactionStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get transactionStatusNeedsReview;

  /// No description provided for @transactionMetaLine.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time} · {bankAccount}'**
  String transactionMetaLine(String date, String time, String bankAccount);

  /// No description provided for @transactionReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue with this transaction'**
  String get transactionReportIssue;

  /// No description provided for @transactionReportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks — reporting will be available soon.'**
  String get transactionReportThanks;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction updated'**
  String get transactionSaved;

  /// No description provided for @transactionAlsoOverride.
  ///
  /// In en, this message translates to:
  /// **'Remember category for this merchant'**
  String get transactionAlsoOverride;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewTitle;

  /// No description provided for @reviewConfidenceSection.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get reviewConfidenceSection;

  /// No description provided for @reviewParseSection.
  ///
  /// In en, this message translates to:
  /// **'Needs parse'**
  String get reviewParseSection;

  /// No description provided for @reviewDuplicatesSection.
  ///
  /// In en, this message translates to:
  /// **'Duplicates skipped'**
  String get reviewDuplicatesSection;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get reviewEmpty;

  /// No description provided for @reviewConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get reviewConfirm;

  /// No description provided for @reviewDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get reviewDismiss;

  /// No description provided for @reviewCompleteManually.
  ///
  /// In en, this message translates to:
  /// **'Complete manually'**
  String get reviewCompleteManually;

  /// No description provided for @reviewConfidence.
  ///
  /// In en, this message translates to:
  /// **'{percent}% confidence'**
  String reviewConfidence(String percent);

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get insightsThisMonth;

  /// No description provided for @insightsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get insightsSpent;

  /// No description provided for @insightsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get insightsIncome;

  /// No description provided for @insightsNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get insightsNet;

  /// No description provided for @insightsVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'vs previous month'**
  String get insightsVsPrevious;

  /// No description provided for @insightsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get insightsByCategory;

  /// No description provided for @insightsTrends.
  ///
  /// In en, this message translates to:
  /// **'Spend over time'**
  String get insightsTrends;

  /// No description provided for @insightsTopMerchants.
  ///
  /// In en, this message translates to:
  /// **'Top merchants'**
  String get insightsTopMerchants;

  /// No description provided for @insightsCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Income vs expense'**
  String get insightsCashFlow;

  /// No description provided for @insightsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No summary for this month yet'**
  String get insightsEmpty;

  /// No description provided for @insightsPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get insightsPrevMonth;

  /// No description provided for @insightsNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get insightsNextMonth;

  /// No description provided for @authUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock NovaSpend'**
  String get authUnlockTitle;

  /// No description provided for @authUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to view your finances'**
  String get authUnlockSubtitle;

  /// No description provided for @authUnlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get authUnlockButton;

  /// No description provided for @authLoading.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get authLoading;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to track your spending'**
  String get authLoginSubtitle;

  /// No description provided for @authSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up NovaSpend in a minute'**
  String get authSignupSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogin;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get authOr;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get authContinueWithApple;

  /// No description provided for @authNeedAccount.
  ///
  /// In en, this message translates to:
  /// **'Need an account? Sign up'**
  String get authNeedAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Have an account? Log in'**
  String get authHaveAccount;

  /// No description provided for @authBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get authBackToLogin;

  /// No description provided for @authTermsConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms and Privacy Policy'**
  String get authTermsConsent;

  /// No description provided for @authAcceptTermsError.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms and Privacy Policy'**
  String get authAcceptTermsError;

  /// No description provided for @authLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our'**
  String get authLegalPrefix;

  /// No description provided for @authAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get authAnd;

  /// No description provided for @authTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get authTerms;

  /// No description provided for @authPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacy;

  /// No description provided for @authVerifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authVerifyEmailTitle;

  /// No description provided for @authVerifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}'**
  String authVerifyEmailBody(String email);

  /// No description provided for @authOtpSentInstructions.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox for a verification code.'**
  String get authOtpSentInstructions;

  /// No description provided for @authOtpCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get authOtpCodeLabel;

  /// No description provided for @authVerifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerifyOtp;

  /// No description provided for @authResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authResendOtp;

  /// No description provided for @authResendOtpIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String authResendOtpIn(String seconds);

  /// No description provided for @authEnterOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get authEnterOtpCode;

  /// No description provided for @authOtpResentTo.
  ///
  /// In en, this message translates to:
  /// **'OTP resent to {email}'**
  String authOtpResentTo(String email);

  /// No description provided for @authSignupSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Signup session expired. Please sign up again.'**
  String get authSignupSessionExpired;

  /// No description provided for @authEmailVerifiedCreated.
  ///
  /// In en, this message translates to:
  /// **'Email verified. Your account is ready.'**
  String get authEmailVerifiedCreated;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a reset code'**
  String get authResetPasswordSubtitle;

  /// No description provided for @authSendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get authSendResetCode;

  /// No description provided for @authPasswordResetOtpInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to {email}'**
  String authPasswordResetOtpInstructions(String email);

  /// No description provided for @authResetCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Reset code sent if this email is registered.'**
  String get authResetCodeSent;

  /// No description provided for @authCreateNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get authCreateNewPasswordTitle;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get authChangePassword;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authPasswordChangedLogin.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please log in.'**
  String get authPasswordChangedLogin;

  /// No description provided for @authPasswordResetSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Reset session expired. Start again.'**
  String get authPasswordResetSessionExpired;

  /// No description provided for @authEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email before signing in.'**
  String get authEmailNotVerified;

  /// No description provided for @authEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authEnterValidEmail;

  /// No description provided for @authMinPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authMinPassword;

  /// No description provided for @authWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get authWrongCredentials;

  /// No description provided for @authUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found for this email'**
  String get authUserNotFound;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use'**
  String get authEmailInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password'**
  String get authWeakPassword;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get authNetworkError;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get authTooManyRequests;

  /// No description provided for @authAccountExistsDifferentCredential.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with a different sign-in method.'**
  String get authAccountExistsDifferentCredential;

  /// No description provided for @authGoogleAccountExists.
  ///
  /// In en, this message translates to:
  /// **'This email is linked to another sign-in method. Try email or Apple.'**
  String get authGoogleAccountExists;

  /// No description provided for @authAppleAccountExists.
  ///
  /// In en, this message translates to:
  /// **'This email is linked to another sign-in method. Try email or Google.'**
  String get authAppleAccountExists;

  /// No description provided for @authSignInDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is disabled for this account.'**
  String get authSignInDisabled;

  /// No description provided for @authInvalidApiKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid API key configuration.'**
  String get authInvalidApiKey;

  /// No description provided for @authUnauthorizedDomain.
  ///
  /// In en, this message translates to:
  /// **'This domain is not authorized for sign-in.'**
  String get authUnauthorizedDomain;

  /// No description provided for @authSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get authSignInCancelled;

  /// No description provided for @authBrowserHandshakeError.
  ///
  /// In en, this message translates to:
  /// **'Browser blocked the sign-in popup. Allow popups and try again.'**
  String get authBrowserHandshakeError;

  /// No description provided for @authUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({message})'**
  String authUnknownError(String message);

  /// No description provided for @authCheckingEmail.
  ///
  /// In en, this message translates to:
  /// **'Checking email…'**
  String get authCheckingEmail;

  /// No description provided for @authDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get authDeleteAccount;

  /// No description provided for @authDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and signed-in access. Continue?'**
  String get authDeleteAccountConfirm;

  /// No description provided for @authDeleteAccountPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get authDeleteAccountPasswordHint;

  /// No description provided for @authAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get authAccountDeleted;

  /// No description provided for @authSendPasswordResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send password reset email'**
  String get authSendPasswordResetLink;

  /// No description provided for @authPasswordResetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent.'**
  String get authPasswordResetLinkSent;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load data'**
  String get errorLoadFailed;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @amountFormat.
  ///
  /// In en, this message translates to:
  /// **'{currency} {amount}'**
  String amountFormat(String currency, String amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
