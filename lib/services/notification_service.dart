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
  }) async {
    final title = 'პარკირების ზონა №  $lotNumber';
    const body = 'გსურთ პარკირების დაწყება?';

    // Для Android — добавляем две action-кнопки
    const androidDetails = AndroidNotificationDetails(
      'parking_channel',
      'Parking Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_custom',
      sound: RawResourceAndroidNotificationSound('funny_minion'),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('park', 'დადასტურება'),
        AndroidNotificationAction('cancel', 'გაუქმება'),
      ],
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // payload передает lotNumber, а действие — идентификатор кнопки
    await _flnp.show(
      1,
      title,
      body,
      details,
      payload: lotNumber,
    );
  }

  /// ქმედების ხელით გამოძახება, თუ საჭიროა კოდიდან პირდაპირი დამუშავება
  static void handleAction(String action, [String? payload]) {
    _onActionCallback(action, payload);
  }

  /// ყველა შეტყობინების გაუქმება
  static Future<void> cancelAll() => _flnp.cancelAll();
}
