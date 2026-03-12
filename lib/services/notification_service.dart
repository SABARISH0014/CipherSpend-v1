import 'package:flutter/material.dart'; // [FIX] Added to support Color class
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Ask for Android 13+ Notification Permission
    await Permission.notification.request();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // [FIX 1] flutter_local_notifications v20+ requires named arguments
    // CORRECT
    await _notificationsPlugin.initialize(settings: initSettings);
    _isInitialized = true;
  }

  // Define the style of the notification (Heads-up, high priority)
  NotificationDetails _getChannelDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'cipherspend_insights',
        'Financial Insights',
        channelDescription: 'Smart alerts about your budget and spending',
        importance: Importance.max,
        priority: Priority.high,
        // [FIX 2] Added the missing `const` keyword
        color: const Color(0xFF00E676),
        enableLights: true,
      ),
    );
  }

  // Method to show a notification
  Future<void> showInsightNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // [FIX 3] flutter_local_notifications v20+ requires named arguments for show()
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _getChannelDetails(),
    );
  }
}
