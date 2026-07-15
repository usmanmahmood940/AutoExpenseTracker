import 'package:nova_spend/features/settings/domain/entities/sync_meta_entity.dart';

abstract class SettingsRepository {
  Stream<SyncMetaEntity?> watchSyncMeta(String uid);

  Future<bool> isBiometricEnabled();

  Future<void> setBiometricEnabled(bool enabled);
}
