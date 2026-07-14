import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Persists and exposes the active app locale.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController(this._prefs);

  final SharedPreferences _prefs;
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final code = _prefs.getString(AppConstants.localePreferenceKey);
    if (code == null || code.isEmpty) {
      _locale = null;
    } else {
      _locale = Locale(code);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    if (locale == null) {
      await _prefs.remove(AppConstants.localePreferenceKey);
    } else {
      await _prefs.setString(
        AppConstants.localePreferenceKey,
        locale.languageCode,
      );
    }
    notifyListeners();
  }
}
