import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nova_spend/app.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/locale/app_locale_controller.dart';
import 'package:nova_spend/core/services/notification_service.dart';
import 'package:nova_spend/core/services/push_notification_service.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';
import 'package:nova_spend/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  final prefs = await SharedPreferences.getInstance();
  final localeController = AppLocaleController(prefs);
  await localeController.load();

  await configureDependencies(prefs: prefs);
  final currencyController = AppCurrencyController(
    prefs,
    remoteSync: AppConstants.kUseBackendV1
        ? (code) => sl<BackendAuthDatasource>().updateMe(defaultCurrency: code)
        : null,
  );
  await currencyController.load();
  await sl<NotificationService>().init();
  await sl<PushNotificationService>().init();

  runApp(NovaSpendApp(
    localeController: localeController,
    currencyController: currencyController,
  ));
}
