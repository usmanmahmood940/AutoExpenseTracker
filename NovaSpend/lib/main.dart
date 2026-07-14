import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/locale/app_locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final localeController = AppLocaleController(prefs);
  await localeController.load();

  await configureDependencies();

  runApp(NovaSpendApp(localeController: localeController));
}
