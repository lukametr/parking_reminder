import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class NotificationService {
  static final _locNotif = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _locNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload   = response.payload;
        final actionId = response.actionId;
        FlutterBackgroundService().invoke(
          'notificationResponse',
          {'payload': payload, 'action': actionId},
        );
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'parking_chan', 'Parking Alerts',
      description: 'პარკირების შეტყობინებები',
      importance: Importance.high,
    );
    await _locNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showInit(String lot) async {
    const androidDetails = AndroidNotificationDetails(
      'parking_chan', 'Parking Alerts',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('park', '🚗 პარკირება'),
        AndroidNotificationAction('cancel', '❌ გამოტოვება'),
      ],
    );
    await _locNotif.show(
      1000,
      'თქვენ ხართ ლოტზე №  $lot?',
      ' ',
      const NotificationDetails(android: androidDetails),
      payload: 'init:$lot',
    );
  }

  static Future<void> showLeave(String lot) async {
    const androidDetails = AndroidNotificationDetails(
      'parking_chan', 'Parking Alerts',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('yes', 'დასრულება'),
        AndroidNotificationAction('no', 'გაგრძელება'),
      ],
    );
    await _locNotif.show(
      1001,
      'თვენ დატოვეთ ლოტი №  $lot?',
      'არ დაგავიწყდეთ პარკირების დასრულება',
      const NotificationDetails(android: androidDetails),
      payload: 'leave:$lot',
    );
  }

  static Future<void> showFinal(String lot) async {
    const androidDetails = AndroidNotificationDetails(
      'parking_chan', 'Parking Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _locNotif.show(
      1002,
      'არ დაგავიწყდეთ პარკირების დაწყება',
      'ლოტი №  $lot',
      const NotificationDetails(android: androidDetails),
    );
  }
}