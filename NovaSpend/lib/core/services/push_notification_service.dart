import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:nova_spend/features/auth/data/datasource/backend_auth_datasource.dart';

/// Registers FCM token for server-side push on new transactions.
///
/// Tokens go to `POST /me/devices`. Firebase Messaging is kept for receive +
/// token refresh; Firestore is no longer a fallback.
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    required BackendAuthDatasource backendAuth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _backendAuth = backendAuth;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final BackendAuthDatasource _backendAuth;

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
    if (_auth.currentUser?.uid == null) return;

    try {
      await _backendAuth.registerDevice(
        fcmToken: token,
        platform: _platform,
      );
    } catch (e, st) {
      debugPrint('POST /me/devices failed: $e\n$st');
    }
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
