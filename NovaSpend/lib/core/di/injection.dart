import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:get_it/get_it.dart';
import 'package:nova_spend/core/http/api_client.dart';
import 'package:nova_spend/core/services/biometric_service.dart';
import 'package:nova_spend/core/services/export_service.dart';
import 'package:nova_spend/core/services/firebase_user_account_service.dart';
import 'package:nova_spend/core/services/notification_service.dart';
import 'package:nova_spend/core/services/push_notification_service.dart';
import 'package:nova_spend/features/analytics/data/datasource/backend_analytics_datasource.dart';
import 'package:nova_spend/features/analytics/data/repository_impl.dart';
import 'package:nova_spend/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:nova_spend/features/analytics/presentation/provider/insights_provider.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';
import 'package:nova_spend/features/auth/data/datasource/firebase_auth_datasource.dart';
import 'package:nova_spend/features/auth/data/repository_impl.dart';
import 'package:nova_spend/features/auth/domain/repositories/auth_repository.dart';
import 'package:nova_spend/features/auth/domain/services/user_account_service.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/data/datasource/backend_category_datasource.dart';
import 'package:nova_spend/features/categories/data/repository_impl.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';
import 'package:nova_spend/features/merchants/data/datasource/backend_merchant_datasource.dart';
import 'package:nova_spend/features/merchants/data/repository_impl.dart';
import 'package:nova_spend/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_summary.dart';
import 'package:nova_spend/features/merchants/domain/usecases/get_merchant_transactions.dart';
import 'package:nova_spend/features/merchants/presentation/provider/merchant_provider.dart';
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
import 'package:nova_spend/features/transactions/data/datasource/backend_transaction_datasource.dart';
import 'package:nova_spend/features/transactions/data/repository_impl.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/get_period_stats.dart';
import 'package:nova_spend/features/transactions/domain/usecases/get_transactions_page.dart';
import 'package:nova_spend/features/transactions/domain/usecases/mark_transaction_reviewed.dart';
import 'package:nova_spend/features/transactions/domain/usecases/update_transaction.dart';
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

  sl.registerLazySingleton(() => ApiClient());
  sl.registerLazySingleton(
    () => BackendAuthDatasource(api: sl()),
  );
  sl.registerLazySingleton(
    () => BackendTransactionDatasource(api: sl()),
  );
  sl.registerLazySingleton(
    () => BackendMerchantDatasource(api: sl()),
  );
  sl.registerLazySingleton(
    () => BackendCategoryDatasource(api: sl()),
  );
  sl.registerLazySingleton(
    () => BackendAnalyticsDatasource(api: sl()),
  );

  sl.registerLazySingleton(() => NotificationService());
  sl.registerLazySingleton(() => BiometricService());
  sl.registerLazySingleton(() => ExportService());
  sl.registerLazySingleton(
    () => PushNotificationService(backendAuth: sl()),
  );

  sl.registerLazySingleton(
    () => FirebaseAuthDatasource(auth: sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      datasource: sl(),
      backendAuth: sl(),
    ),
  );
  sl.registerLazySingleton<UserAccountService>(
    () => FirebaseUserAccountService(auth: sl()),
  );
  sl.registerFactory(
    () => AuthProvider(authRepository: sl()),
  );

  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(backend: sl()),
  );
  sl.registerLazySingleton(() => GetTransactionsPage(sl()));
  sl.registerLazySingleton(() => GetPeriodStats(sl()));
  sl.registerLazySingleton(() => UpdateTransaction(sl()));
  sl.registerLazySingleton(() => MarkTransactionReviewed(sl()));
  sl.registerFactory(
    () => HomeProvider(
      getTransactionsPage: sl(),
      getPeriodStats: sl(),
      transactionRepository: sl(),
    ),
  );

  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(backend: sl()),
  );

  sl.registerLazySingleton<AnalyticsRepository>(
    () => AnalyticsRepositoryImpl(backend: sl()),
  );
  sl.registerFactory(() => InsightsProvider(repository: sl()));

  sl.registerLazySingleton<MerchantRepository>(
    () => MerchantRepositoryImpl(backend: sl()),
  );
  sl.registerLazySingleton(() => GetMerchantSummary(sl()));
  sl.registerLazySingleton(() => GetMerchantTransactions(sl()));
  sl.registerFactory(
    () => MerchantProvider(
      getMerchantSummary: sl(),
      getMerchantTransactions: sl(),
      transactionRepository: sl(),
    ),
  );

  sl.registerLazySingleton(() => RecentSearchesDatasource(sl()));
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      recentSearchesDatasource: sl(),
      backend: sl(),
    ),
  );
  sl.registerLazySingleton(() => SearchTransactions(sl()));
  sl.registerFactory(
    () => SearchProvider(
      searchTransactions: sl(),
      searchRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => SettingsLocalDatasource(sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
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
