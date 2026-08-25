import 'package:nova_spend/features/settings/data/datasource/settings_datasource.dart';
import 'package:nova_spend/features/settings/domain/entities/sync_meta_entity.dart';
import 'package:nova_spend/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required SettingsLocalDatasource localDatasource,
  }) : _local = localDatasource;

  final SettingsLocalDatasource _local;

  @override
  Stream<SyncMetaEntity?> watchSyncMeta(String uid) {
    return Stream<SyncMetaEntity?>.value(null);
  }

  @override
  Future<bool> isBiometricEnabled() => _local.isBiometricEnabled();

  @override
  Future<void> setBiometricEnabled(bool enabled) {
    return _local.setBiometricEnabled(enabled);
  }
}
