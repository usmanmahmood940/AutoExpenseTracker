import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/locale/app_locale_controller.dart';
import 'package:nova_spend/core/services/notification_service.dart';
import 'package:nova_spend/core/services/push_notification_service.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';
import 'package:nova_spend/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controllers created during cold-start bootstrap.
class AppStartupResult {
  const AppStartupResult({
    required this.localeController,
    required this.currencyController,
  });

  final AppLocaleController localeController;
  final AppCurrencyController currencyController;
}

/// Runs all cold-start work while the custom splash is visible.
class AppBootstrap {
  AppBootstrap._();

  static final AppBootstrap instance = AppBootstrap._();

  Future<AppStartupResult>? _future;
  AppStartupResult? _result;

  /// In-flight or completed startup. Safe to call multiple times.
  Future<AppStartupResult> initialize() {
    return _future ??= _run();
  }

  AppStartupResult? get result => _result;

  Future<AppStartupResult> _run() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final prefs = await SharedPreferences.getInstance();
      final localeController = AppLocaleController(prefs);
      await localeController.load();

      await configureDependencies(prefs: prefs);

      final currencyController = AppCurrencyController(
        prefs,
        remoteSync: (code) =>
            sl<BackendAuthDatasource>().updateMe(defaultCurrency: code),
      );
      await currencyController.load();

      await Future.wait([
        FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
        ),
        sl<NotificationService>().init(),
        sl<PushNotificationService>().init(),
      ]);

      _result = AppStartupResult(
        localeController: localeController,
        currencyController: currencyController,
      );
      return _result!;
    } catch (e, st) {
      debugPrint('AppBootstrap failed: $e\n$st');
      rethrow;
    }
  }
}
