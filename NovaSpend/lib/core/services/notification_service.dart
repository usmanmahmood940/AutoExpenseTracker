import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for budget alerts.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showBudgetAlert({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await init();
    const android = AndroidNotificationDetails(
      'budget_alerts',
      'Budget alerts',
      channelDescription: 'Alerts when spending approaches budget limits',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(id, title, body, details);
  }
}
