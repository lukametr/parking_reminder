import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

class BackgroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'parking_channel',
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Parking Reminder',
        initialNotificationContent: 'Tracking location...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Parking Reminder",
        content: "Tracking your location...",
      );
    }

    service.on('stop').listen((event) {
      service.stopSelf();
    });
  }

  static Future<void> start() => _service.startService();
  static void stop() => _service.invoke('stop'); // Убран await
}