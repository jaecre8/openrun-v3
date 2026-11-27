import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../app_services.dart';
import '../screens/web_view_screen.dart';

/// Server push (FCM): registers this device's token and opens the deal when a notification is tapped.
class NotificationService {
  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'openrun_deals', // must match the channelId the server sends
    '핫딜 알림',
    description: '키워드 조건에 맞는 핫딜 알림',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (!AppServices.instance.user.supportsPush) return;
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _open(r.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      final messaging = FirebaseMessaging.instance;
      final perm = await messaging.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;

      // iOS shows foreground pushes itself; Android needs a local notification.
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data['url'] as String?));
      final initial = await messaging.getInitialMessage();
      if (initial != null) Future.delayed(const Duration(milliseconds: 1800), () => _open(initial.data['url'] as String?));

      if (Platform.isIOS) await messaging.getAPNSToken();
      // The server sends with Admin SDK `tokens`, so keep the classic FCM registration token
      // rather than the newer FID from register()/onRegistered.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await AppServices.instance.user.addFcmToken(token);
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen(AppServices.instance.user.addFcmToken);
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null || !Platform.isAndroid) return;
    await _local.show(
      m.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(_channel.id, _channel.name,
            importance: Importance.high, priority: Priority.high),
      ),
      payload: m.data['url'] as String?,
    );
  }

  static void _open(String? url) {
    if (url == null || url.isEmpty) return;
    Get.to(() => WebViewScreen(url: url));
  }
}
