import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../constants/currencies.dart';
import '../utils/money_format.dart' as money;

/// Persists and exposes the user's money display preferences.
class AppCurrencyController extends ChangeNotifier {
  AppCurrencyController(this._prefs);

  final SharedPreferences _prefs;
  String _currency = kDefaultCurrency;
  bool _showDecimals = true;

  String get currency => _currency;
  bool get showDecimals => _showDecimals;

  Future<void> load() async {
    final code = _prefs.getString(AppConstants.currencyPreferenceKey);
    _currency = normalizeCurrency(code);
    _showDecimals = _prefs.getBool(AppConstants.showDecimalsPreferenceKey) ?? true;
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _currency = normalizeCurrency(currency);
    await _prefs.setString(AppConstants.currencyPreferenceKey, _currency);
    notifyListeners();
  }

  Future<void> setShowDecimals(bool value) async {
    _showDecimals = value;
    await _prefs.setBool(AppConstants.showDecimalsPreferenceKey, value);
    notifyListeners();
  }

  String formatMoney(num amount) {
    return money.formatMoney(
      amount,
      currency: _currency,
      showDecimals: _showDecimals,
    );
  }
}
