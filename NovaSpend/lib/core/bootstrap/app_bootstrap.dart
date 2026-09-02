import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/services/notification_service.dart';
import 'package:nova_spend/core/services/push_notification_service.dart';

/// Runs non-critical startup work after the first Flutter frame.
///
/// Await [ready] before backend API calls that depend on App Check.
class AppBootstrap {
  AppBootstrap._();

  static final AppBootstrap instance = AppBootstrap._();

  Future<void>? _future;

  /// Completes when deferred startup work finishes (or fails open).
  Future<void> get ready => _future ?? Future<void>.value();

  /// Starts bootstrap once; safe to call multiple times.
  void start() {
    _future ??= _run();
  }

  Future<void> _run() async {
    try {
      await Future.wait([
        FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
        ),
        sl<NotificationService>().init(),
        sl<PushNotificationService>().init(),
      ]);
    } catch (e, st) {
      debugPrint('AppBootstrap failed: $e\n$st');
    }
  }
}
