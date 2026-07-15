import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nova_spend/core/services/export_service.dart';
import 'package:nova_spend/features/auth/domain/repositories/auth_repository.dart';
import 'package:nova_spend/features/auth/domain/services/user_account_service.dart';
import 'package:nova_spend/features/settings/domain/entities/sync_meta_entity.dart';
import 'package:nova_spend/features/settings/domain/repositories/settings_repository.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required SettingsRepository settingsRepository,
    required AuthRepository authRepository,
    required TransactionRepository transactionRepository,
    required ExportService exportService,
    required UserAccountService userAccountService,
  })  : _settingsRepository = settingsRepository,
        _authRepository = authRepository,
        _transactionRepository = transactionRepository,
        _exportService = exportService,
        _userAccountService = userAccountService;

  final SettingsRepository _settingsRepository;
  final AuthRepository _authRepository;
  final TransactionRepository _transactionRepository;
  final ExportService _exportService;
  final UserAccountService _userAccountService;

  StreamSubscription<SyncMetaEntity?>? _syncSub;

  SyncMetaEntity? syncMeta;
  bool biometricEnabled = false;
  bool isLoading = true;
  bool isExporting = false;
  String? error;

  Future<void> start(String uid) async {
    _syncSub?.cancel();
    isLoading = true;
    notifyListeners();

    biometricEnabled = await _settingsRepository.isBiometricEnabled();

    _syncSub = _settingsRepository.watchSyncMeta(uid).listen((meta) {
      syncMeta = meta;
      isLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _settingsRepository.setBiometricEnabled(enabled);
    biometricEnabled = enabled;
    notifyListeners();
  }

  Future<void> exportCsv(String uid) async {
    isExporting = true;
    notifyListeners();
    try {
      final txs = await _transactionRepository
          .getTransactionsPage(uid, limit: 500);
      await _exportService.exportTransactionsCsv(txs);
    } catch (e) {
      error = e.toString();
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _authRepository.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _userAccountService.sendPasswordResetEmail(email);
  }

  Future<void> deleteAccount({String? password}) {
    return _userAccountService.deleteAccount(password: password);
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
}
