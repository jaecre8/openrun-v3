import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(settings);

    // 안드로이드 13 이상을 위한 권한 요청
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'openrun_id', 'OPENRUN',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _notificationsPlugin.show(DateTime.now().hashCode, title, body, details);
  }
}