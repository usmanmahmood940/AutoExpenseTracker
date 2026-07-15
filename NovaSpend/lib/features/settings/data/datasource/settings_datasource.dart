import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/features/settings/domain/entities/sync_meta_entity.dart';
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

class FirestoreSettingsDatasource {
  FirestoreSettingsDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<SyncMetaEntity?> watchSyncMeta(String uid) {
    return _db
        .collection(AppConstants.users)
        .doc(uid)
        .collection(AppConstants.meta)
        .doc('sync')
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final lastSynced = data['lastSyncedAt'];
      return SyncMetaEntity(
        lastSyncedAt:
            lastSynced is Timestamp ? lastSynced.toDate() : null,
        lastMerchant: data['lastMerchant'] as String?,
        lastAmount: (data['lastAmount'] as num?)?.toDouble(),
        lastTransactionId: data['lastTransactionId'] as String?,
      );
    });
  }
}
