import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../constants/currencies.dart';
import '../utils/money_format.dart' as money;

/// Persists and exposes the user's money display preferences.
class AppCurrencyController extends ChangeNotifier {
  AppCurrencyController(this._prefs, {this.remoteSync});

  final SharedPreferences _prefs;

  /// When set (Phase E backend), [setCurrency] also PATCHes `/me`.
  final Future<void> Function(String currency)? remoteSync;

  String _currency = kDefaultCurrency;
  bool _showDecimals = false;
  bool _isSaving = false;

  String get currency => _currency;
  bool get showDecimals => _showDecimals;
  bool get isSaving => _isSaving;

  Future<void> load() async {
    final code = _prefs.getString(AppConstants.currencyPreferenceKey);
    _currency = normalizeCurrency(code);
    _showDecimals = _prefs.getBool(AppConstants.showDecimalsPreferenceKey) ?? false;
    notifyListeners();
  }

  /// Apply the profile currency from `GET /me` without calling the API again.
  Future<void> applyFromServer(String currency) async {
    final next = normalizeCurrency(currency);
    if (next == _currency) return;
    _currency = next;
    await _prefs.setString(AppConstants.currencyPreferenceKey, _currency);
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _currency = normalizeCurrency(currency);
    await _prefs.setString(AppConstants.currencyPreferenceKey, _currency);
    notifyListeners();
    final sync = remoteSync;
    if (sync == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      await sync(_currency);
    } catch (e, st) {
      debugPrint('PATCH /me default_currency failed: $e\n$st');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
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
