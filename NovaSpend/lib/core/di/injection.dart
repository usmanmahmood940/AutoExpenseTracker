import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

/// Registers dependency injection bindings.
Future<void> configureDependencies() async {
  // Auth
  // sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(...));
  // sl.registerLazySingleton(() => SignInUseCase(sl()));

  // Transactions
  // sl.registerLazySingleton<TransactionRepository>(
  //   () => TransactionRepositoryImpl(...),
  // );

  // Categories
  // sl.registerLazySingleton<CategoryRepository>(
  //   () => CategoryRepositoryImpl(...),
  // );

  // Budgets
  // sl.registerLazySingleton<BudgetRepository>(() => BudgetRepositoryImpl(...));

  // Analytics
  // sl.registerLazySingleton<AnalyticsRepository>(
  //   () => AnalyticsRepositoryImpl(...),
  // );

  // Settings
  // sl.registerLazySingleton<SettingsRepository>(
  //   () => SettingsRepositoryImpl(...),
  // );
}
