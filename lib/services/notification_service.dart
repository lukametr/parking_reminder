// lib/services/notification_service.dart

import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

typedef NotificationActionCallback = void Function(String action, String? payload);

class NotificationService {
  static final _flnp = FlutterLocalNotificationsPlugin();
  static late NotificationActionCallback _onActionCallback;

  /// პლაგინის ინიციალიზაცია და callback-ის გადაცემა, რომლითაც ვიგებთ მომხმარებლის ქმედებას შეტყობინებაზე
  static Future<void> initialize({
    required NotificationActionCallback onActionCallback,
  }) async {
    _onActionCallback = onActionCallback;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _flnp.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // actionId: 'park', 'cancel', 'tap' (ღილაკის ან notification-ის დაჭერა)
        final action = response.actionId?.isNotEmpty == true ? response.actionId : 'tap';
        final payload = response.payload;
        _onActionCallback(action!, payload);
      },
    );
  }

  /// მარტივი შეტყობინება, მხოლოდ სათაურით და ტექსტით (ღილაკების გარეშე)
  static Future<void> showSimpleNotification({
    required String title,
    required String message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'simple_channel',
      'Simple Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_custom',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flnp.show(
      0,
      title,
      message,
      details,
      payload: 'tap',
    );
  }

  /// პარკირების შეტყობინება: Android-ზე გამოდის ღილაკებით, iOS-ზე მხოლოდ ტექსტით
  static Future<void> showParkingNotification({
    required Position position,
    required String lotNumber,
    bool isLeavingZone = false,
  }) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    final title = isLeavingZone 
        ? 'თქვენ დატოვეთ ზონალური პარკირების ადგილი'
        : 'ზონალური პარკირების ზონა № $lotNumber';
    final body = isLeavingZone
        ? 'არ დაგავიწყდეთ პარკირების დასრულება!'
        : 'გსურთ პარკირების დაწყება?';

    await flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'parking_channel',
          'Parking Reminder',
          channelDescription: 'Channel for parking notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_custom',
          actions: isLeavingZone ? [] : [
            const AndroidNotificationAction(
              'park',
              'დაწყება',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction(
              'cancel',
              'გაუქმება',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: isLeavingZone ? null : lotNumber,
    );
  }

  /// ქმედების ხელით გამოძახება, თუ საჭიროა კოდიდან პირდაპირი დამუშავება
  static void handleAction(String action, [String? payload]) {
    _onActionCallback(action, payload);
  }

  /// კონკრეტული შეტყობინების გაუქმება
  static Future<void> cancelNotification(int id) async {
    await _flnp.cancel(id);
  }

  /// ყველა შეტყობინების გაუქმება
  static Future<void> cancelAll() async {
    await _flnp.cancelAll();
  }
}
