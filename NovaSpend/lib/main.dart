import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nova_spend/app.dart';
import 'package:nova_spend/core/bootstrap/app_bootstrap.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/locale/app_locale_controller.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';
import 'package:nova_spend/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  AppBootstrap.instance.start();

  runApp(NovaSpendApp(
    localeController: localeController,
    currencyController: currencyController,
  ));
}
