// lib/services/notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef NotificationActionCallback = void Function(String action, String? payload);

class NotificationService {
  static final _flnp = FlutterLocalNotificationsPlugin();
  static late NotificationActionCallback _onActionCallback;
  static int _notificationCounter = 0;

  /// პლაგინის ინიციალიზაცია და callback-ის გადაცემა, რომლითაც ვიგებთ მომხმარებლის ქმედებას შეტყობინებაზე
  static Future<void> initialize({
    NotificationActionCallback? onActionCallback,
  }) async {
    if (onActionCallback != null) {
      _onActionCallback = onActionCallback;
    }

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
        if (_onActionCallback != null) {
          _onActionCallback(action!, payload);
        }
      },
    );
  }

  /// მარტივი შეტყობინება, მხოლოდ სათაურით და ტექსტით (ღილაკების გარეშე)
  static Future<void> showSimpleNotification({
    required String title,
    required String message,
  }) async {
    final notificationId = _getNextNotificationId();
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
      notificationId,
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
    // გავაუქმოთ ყველა არსებული შეტყობინება
    await cancelAll();
    
    final notificationId = _getNextNotificationId();
    final title = isLeavingZone 
        ? 'თქვენ დატოვეთ ზონალური პარკირების ადგილი'
        : 'ზონალური პარკირების ზონა № $lotNumber';
    final body = isLeavingZone
        ? 'არ დაგავიწყდეთ პარკირების დასრულება!'
        : 'გსურთ პარკირების დაწყება?';
    
    final androidDetails = AndroidNotificationDetails(
      'parking_channel',
      'Parking Notifications',
      channelDescription: 'Notifications for parking zones',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      actions: isLeavingZone ? [] : [
        const AndroidNotificationAction(
          'open_app',
          'დაწყება',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'block_notifications',
          'საცობი',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'cancel',
          'გაუქმება',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _flnp.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: json.encode({
        'action': isLeavingZone ? 'exit' : 'open_app',
        'lotNumber': lotNumber,
        'latitude': position.latitude,
        'longitude': position.longitude,
      }),
    );
  }

  /// შემდეგი უნიკალური notification ID-ის მიღება
  static int _getNextNotificationId() {
    _notificationCounter = (_notificationCounter + 1) % 1000;
    return _notificationCounter;
  }

  /// ქმედების ხელით გამოძახება, თუ საჭიროა კოდიდან პირდაპირი დამუშავება
  static Future<void> handleAction(String action, Map<String, dynamic> payload) async {
    // გავაუქმოთ ყველა შეტყობინება ნებისმიერი ღილაკზე დაჭერისას
    await cancelAll();
    
    switch (action) {
      case 'open_app':
        // აპლიკაციის გახსნის ლოგიკა
        break;
      case 'block_notifications':
        await _blockNotifications();
        _onActionCallback('block_notifications', null);
        break;
      case 'exit':
        // გასვლის შეტყობინების ლოგიკა
        break;
      case 'cancel':
        // შეტყობინების გაუქმება უკვე მოხდა
        break;
    }
  }

  /// კონკრეტული შეტყობინების გაუქმება
  static Future<void> cancelNotification(int id) async {
    await _flnp.cancel(id);
  }

  /// ყველა შეტყობინების გაუქმება
  static Future<void> cancelAll() async {
    await _flnp.cancelAll();
  }

  /// შეტყობინებების დროებითი გაუქმება
  static Future<void> _blockNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    // 15 წუთი = 15 * 60 * 1000 მილიწამი
    final blockUntil = now + (15 * 60 * 1000);
    await prefs.setInt('notifications_blocked_until', blockUntil);
    print('Notifications blocked until: ${DateTime.fromMillisecondsSinceEpoch(blockUntil)}');
    await cancelAll();
  }

  /// შეტყობინებების გაუქმება და სტატუსის განახლება
  static Future<void> cancelAndUpdateStatus() async {
    await cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isForeground', true);
  }

  /// საწყისი შეტყობინების ჩვენება
  static Future<void> showInit() async {
    const androidDetails = AndroidNotificationDetails(
      'parking_channel',
      'Parking Notifications',
      channelDescription: 'Notifications for parking zones',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_custom',
      ongoing: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flnp.show(
      888,
      'Parking Reminder',
      'Tracking your location...',
      details,
    );
  }

  /// სიახლოვის შეტყობინების ჩვენება
  static Future<void> showProximityNotification(String lotsText) async {
    final notificationId = _getNextNotificationId();
    final androidDetails = AndroidNotificationDetails(
      'parking_channel',
      'Parking Notifications',
      channelDescription: 'Notifications for parking zones',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      actions: [
        const AndroidNotificationAction(
          'open_app',
          'დაწყება',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'block_notifications',
          'საცობი',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'cancel',
          'გაუქმება',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _flnp.show(
      notificationId,
      'ზონალური პარკირების ზონა № $lotsText',
      'გსურთ პარკირების დაწყება?',
      notificationDetails,
      payload: json.encode({
        'action': 'open_app',
        'lotNumber': lotsText,
      }),
    );
  }
}
