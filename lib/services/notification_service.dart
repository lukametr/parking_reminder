import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  
  // 1. Константы для канала уведомлений
  static const _channelId = 'parking_channel';
  static const _channelName = 'Parking Alerts';

  static Future<void> initialize() async {
    // 2. Инициализация иконки (без @)
    const androidSettings = AndroidInitializationSettings('mipmap/ic_launcher');
    
    // 3. Создание канала уведомлений
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
      description: 'Channel for parking notifications',
    );
    
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) {
        handleAction(response.actionId ?? response.payload ?? '');
      },
    );

    // 4. Создаем канал для Android 8+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> showInit(Position pos) async {
    // 5. Используем константы канала
    const details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('park', 'პარკირება'),
        AndroidNotificationAction('cancel', 'გამოტოვება'),
      ],
    );
    
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch, // Уникальный ID
      'პარკირების ზონა',
      'გსურთ პარკირების დაწყება?',
      NotificationDetails(android: details),
      payload: '${pos.latitude},${pos.longitude}',
    );
  }

  // 6. Улучшенная обработка действий
  static void handleAction(String actionId) {
    switch (actionId) {
      case 'park':
        _startParking();
        break;
      case 'cancel':
        _skipParking();
        break;
      default:
        _handleNotificationTap();
    }
  }

  static void _startParking() {
    // Логика старта парковки
  }

  static void _skipParking() {
    // Логика отмены
  }

  static void _handleNotificationTap() {
    // Действие при тапе на уведомление
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}