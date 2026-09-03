import 'dart:async';

import 'package:nova_spend/core/provider/safe_change_notifier.dart';
import 'package:nova_spend/core/services/export_service.dart';
import 'package:nova_spend/features/auth/domain/repositories/auth_repository.dart';
import 'package:nova_spend/features/auth/domain/services/user_account_service.dart';
import 'package:nova_spend/features/settings/domain/entities/sync_meta_entity.dart';
import 'package:nova_spend/features/settings/domain/repositories/settings_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';

enum SettingsBusyAction { signOut, passwordReset, deleteAccount, export }

class SettingsProvider extends SafeChangeNotifier {
  SettingsProvider({
    required SettingsRepository settingsRepository,
    required AuthRepository authRepository,
    required TransactionRepository transactionRepository,
    required ExportService exportService,
    required UserAccountService userAccountService,
  }) : _settingsRepository = settingsRepository,
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
  SettingsBusyAction? _busyAction;
  String? error;

  SettingsBusyAction? get busyAction => _busyAction;
  bool get isBusy => _busyAction != null;
  bool get isExporting => isBusyWith(SettingsBusyAction.export);

  bool isBusyWith(SettingsBusyAction action) => _busyAction == action;

  Future<void> start(String uid) async {
    _syncSub?.cancel();
    isLoading = true;
    notifyListeners();

    biometricEnabled = await _settingsRepository.isBiometricEnabled();

    _syncSub = _settingsRepository
        .watchSyncMeta(uid)
        .listen(
          (meta) {
            syncMeta = meta;
            isLoading = false;
            notifyListeners();
          },
          onError: (Object e) {
            error = e.toString();
            isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _settingsRepository.setBiometricEnabled(enabled);
    biometricEnabled = enabled;
    notifyListeners();
  }

  Future<bool> exportCsv(String uid) {
    error = null;
    return _runBusy(SettingsBusyAction.export, () async {
      try {
        final txs = <TransactionEntity>[];
        TransactionEntity? cursor;
        var hasMore = true;
        while (hasMore) {
          final page = await _transactionRepository.getTransactionsPage(
            uid,
            limit: 100,
            startAfter: cursor,
          );
          txs.addAll(page.items);
          hasMore = page.hasMore && page.items.isNotEmpty;
          cursor = page.items.isEmpty ? null : page.items.last;
          if (txs.length >= 5000) break;
        }
        await _exportService.exportTransactionsCsv(txs);
        return true;
      } catch (e) {
        error = e.toString();
        return false;
      }
    });
  }

  Future<void> signOut() {
    return _runBusy(
      SettingsBusyAction.signOut,
      () => _authRepository.signOut(),
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _runBusy(
      SettingsBusyAction.passwordReset,
      () => _userAccountService.sendPasswordResetEmail(email),
    );
  }

  Future<void> deleteAccount({String? password}) {
    return _runBusy(
      SettingsBusyAction.deleteAccount,
      () => _userAccountService.deleteAccount(password: password),
    );
  }

  Future<T> _runBusy<T>(
    SettingsBusyAction action,
    Future<T> Function() fn,
  ) async {
    if (_busyAction != null) return fn();
    _busyAction = action;
    notifyListeners();
    try {
      return await fn();
    } finally {
      _busyAction = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
}
