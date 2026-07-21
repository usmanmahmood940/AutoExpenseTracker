import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:get_it/get_it.dart';
import 'package:nova_spend/core/services/biometric_service.dart';
import 'package:nova_spend/core/services/export_service.dart';
import 'package:nova_spend/core/services/notification_service.dart';
import 'package:nova_spend/core/services/push_notification_service.dart';
import 'package:nova_spend/features/analytics/data/datasource/firestore_analytics_datasource.dart';
import 'package:nova_spend/features/analytics/data/repository_impl.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:nova_spend/features/analytics/presentation/provider/insights_provider.dart';
import 'package:nova_spend/features/auth/data/datasource/firebase_auth_datasource.dart';
import 'package:nova_spend/features/auth/data/repository_impl.dart';
import 'package:nova_spend/features/auth/domain/repositories/auth_repository.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/core/services/firebase_user_account_service.dart';
import 'package:nova_spend/features/auth/domain/services/user_account_service.dart';
import 'package:nova_spend/features/categories/data/datasource/firestore_category_datasource.dart';
import 'package:nova_spend/features/categories/data/repository_impl.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';
import 'package:nova_spend/features/merchants/data/datasource/firestore_merchant_datasource.dart';
import 'package:nova_spend/features/merchants/data/repository_impl.dart';
import 'package:nova_spend/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_summary.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_transactions.dart';
import 'package:nova_spend/features/merchants/presentation/provider/merchant_provider.dart';
import 'package:nova_spend/features/search/data/datasource/firestore_search_datasource.dart';
import 'package:nova_spend/features/search/data/datasource/recent_searches_datasource.dart';
import 'package:nova_spend/features/search/data/repository_impl.dart';
import 'package:nova_spend/features/search/domain/repositories/search_repository.dart';
import 'package:nova_spend/features/search/domain/usecases/search_transactions.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/settings/data/datasource/settings_datasource.dart';
import 'package:nova_spend/features/settings/data/repository_impl.dart';
import 'package:nova_spend/features/settings/domain/repositories/settings_repository.dart';
import 'package:nova_spend/features/settings/presentation/provider/review_provider.dart';
import 'package:nova_spend/features/settings/presentation/provider/settings_provider.dart';
import 'package:nova_spend/features/transactions/data/datasource/firestore_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/data/repository_impl.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/get_transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/usecases/mark_transaction_reviewed.dart';
import 'package:nova_spend/features/transactions/domain/usecases/update_transaction.dart';
import 'package:nova_spend/features/transactions/domain/usecases/watch_transactions.dart';
import 'package:nova_spend/features/transactions/presentation/provider/home_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt sl = GetIt.instance;

/// Registers dependency injection bindings.
Future<void> configureDependencies({
  SharedPreferences? prefs,
}) async {
  final sharedPrefs = prefs ?? await SharedPreferences.getInstance();

  // Allow re-entry during hot restart without duplicate registration errors.
  if (sl.isRegistered<SharedPreferences>()) {
    return;
  }

  sl.registerSingleton<SharedPreferences>(sharedPrefs);
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // Services
  sl.registerLazySingleton(() => NotificationService());
  sl.registerLazySingleton(() => BiometricService());
  sl.registerLazySingleton(() => ExportService());
  sl.registerLazySingleton(() => PushNotificationService());

  // Auth
  sl.registerLazySingleton(
    () => FirebaseAuthDatasource(auth: sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(datasource: sl()),
  );
  sl.registerLazySingleton<UserAccountService>(
    () => FirebaseUserAccountService(auth: sl()),
  );
  sl.registerFactory(
    () => AuthProvider(authRepository: sl()),
  );

  // Transactions
  sl.registerLazySingleton(
    () => FirestoreTransactionDatasource(firestore: sl()),
  );
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(datasource: sl()),
  );
  sl.registerLazySingleton(() => WatchTransactions(sl()));
  sl.registerLazySingleton(() => GetTransactionsPage(sl()));
  sl.registerLazySingleton(() => UpdateTransaction(sl()));
  sl.registerLazySingleton(() => MarkTransactionReviewed(sl()));
  sl.registerFactory(
    () => HomeProvider(
      watchTransactions: sl(),
      getTransactionsPage: sl(),
      analyticsRepository: sl(),
      transactionRepository: sl(),
    ),
  );

  // Categories — only CategoryRepository is consumed directly (by the
  // transaction edit picker); there is no standalone categories screen.
  sl.registerLazySingleton(
    () => FirestoreCategoryDatasource(firestore: sl()),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(datasource: sl()),
  );

  // Analytics
  sl.registerLazySingleton(
    () => FirestoreAnalyticsDatasource(firestore: sl()),
  );
  sl.registerLazySingleton<AnalyticsRepository>(
    () => AnalyticsRepositoryImpl(datasource: sl()),
  );
  sl.registerFactory(() => InsightsProvider(repository: sl()));

  // Merchants
  sl.registerLazySingleton(
    () => FirestoreMerchantDatasource(firestore: sl()),
  );
  sl.registerLazySingleton<MerchantRepository>(
    () => MerchantRepositoryImpl(datasource: sl()),
  );
  sl.registerLazySingleton(() => GetMerchantSummary(sl()));
  sl.registerLazySingleton(() => GetMerchantTransactions(sl()));
  sl.registerFactory(
    () => MerchantProvider(
      getMerchantSummary: sl(),
      getMerchantTransactions: sl(),
    ),
  );

  // Search
  sl.registerLazySingleton(
    () => FirestoreSearchDatasource(firestore: sl()),
  );
  sl.registerLazySingleton(() => RecentSearchesDatasource(sl()));
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      firestoreDatasource: sl(),
      recentSearchesDatasource: sl(),
    ),
  );
  sl.registerLazySingleton(() => SearchTransactions(sl()));
  sl.registerFactory(
    () => SearchProvider(
      searchTransactions: sl(),
      searchRepository: sl(),
    ),
  );

  // Settings
  sl.registerLazySingleton(
    () => FirestoreSettingsDatasource(firestore: sl()),
  );
  sl.registerLazySingleton(
    () => SettingsLocalDatasource(sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
      firestoreDatasource: sl(),
      localDatasource: sl(),
    ),
  );
  sl.registerFactory(
    () => SettingsProvider(
      settingsRepository: sl(),
      authRepository: sl(),
      transactionRepository: sl(),
      exportService: sl(),
      userAccountService: sl(),
    ),
  );
  sl.registerFactory(
    () => ReviewProvider(
      repository: sl(),
      markReviewed: sl(),
    ),
  );
}
