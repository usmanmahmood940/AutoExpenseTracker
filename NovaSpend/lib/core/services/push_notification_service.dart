import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';

/// Registers FCM token for server-side push on new transactions.
///
/// Phase E: when [AppConstants.kUseBackendV1] is true, tokens go to
/// `POST /me/devices`. Otherwise they are merged onto the Firestore user doc
/// (`fcmTokens`) for the legacy Cloud Function notifier.
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    BackendAuthDatasource? backendAuth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _backendAuth = backendAuth;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final BackendAuthDatasource? _backendAuth;

  Future<void> init() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await _messaging.getToken();
      await _persistToken(token);
      _messaging.onTokenRefresh.listen(_persistToken);
    } catch (e, st) {
      debugPrint('PushNotificationService.init failed: $e\n$st');
    }
  }

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (AppConstants.kUseBackendV1 && _backendAuth != null) {
      try {
        await _backendAuth.registerDevice(
          fcmToken: token,
          platform: _platform,
        );
        return;
      } catch (e, st) {
        debugPrint('POST /me/devices failed: $e\n$st');
        // Fall through to Firestore so push is not silent during cutover.
      }
    }

    await _db.collection(AppConstants.users).doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'web',
    };
  }
}
