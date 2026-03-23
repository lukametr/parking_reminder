import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications (Android 13+ permission requested from UI flow).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'parking_reminder_v1';
  static const String channelName = 'პარკინგის შეხსენებები';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  String? _lastPaidZoneId;
  DateTime? _lastPaidNotifiedAt;
  String? _lastFreeZoneId;
  DateTime? _lastFreeNotifiedAt;

  static const Duration _paidThrottle = Duration(minutes: 45);
  static const Duration _freeThrottle = Duration(hours: 2);

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'ფასიანი/უფასო ზონის შეტყობინებები',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showServiceMessage(int id, String title, String body) async {
    await _showRaw(id, title, body);
  }

  Future<void> maybeNotifyPaidZone(String zoneId, String title, String body) async {
    final now = DateTime.now();
    if (_lastPaidZoneId == zoneId &&
        _lastPaidNotifiedAt != null &&
        now.difference(_lastPaidNotifiedAt!) < _paidThrottle) {
      return;
    }
    _lastPaidZoneId = zoneId;
    _lastPaidNotifiedAt = now;
    await _showRaw(zoneId.hashCode & 0x7fffffff, title, body);
  }

  /// ზონიდან გასვლის შემდეგ — ხელახალი შესვლისთვის შეტყობინების დაშვება.
  void clearPaidParkingThrottle() {
    _lastPaidZoneId = null;
    _lastPaidNotifiedAt = null;
  }

  Future<void> maybeNotifyFreeZone(String zoneId, String title, String body) async {
    final now = DateTime.now();
    if (_lastFreeZoneId == zoneId &&
        _lastFreeNotifiedAt != null &&
        now.difference(_lastFreeNotifiedAt!) < _freeThrottle) {
      return;
    }
    _lastFreeZoneId = zoneId;
    _lastFreeNotifiedAt = now;
    await _showRaw((zoneId.hashCode ^ 0x12345678) & 0x7fffffff, title, body);
  }

  Future<void> _showRaw(int id, String title, String body) async {
    if (!_initialized) await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'პარკინგის ზონის შეტყობინებები',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
