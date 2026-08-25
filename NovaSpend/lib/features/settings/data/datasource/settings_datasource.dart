import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsLocalDatasource {
  SettingsLocalDatasource(this._prefs);

  final SharedPreferences _prefs;

  Future<bool> isBiometricEnabled() async {
    return _prefs.getBool(AppConstants.prefBiometricLock) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(AppConstants.prefBiometricLock, enabled);
  }
}
