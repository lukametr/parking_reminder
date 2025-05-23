import 'dart:async';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:parking_reminder/services/location_service.dart';
import 'package:parking_reminder/services/parking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:parking_reminder/services/notification_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isInitialized = false;
  static bool _isRunning = false;
  static Timer? _debounceTimer;
  static List<String> _pendingLots = [];
  static Position? _lastNotificationPosition;

  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'parking_channel',
      'Parking Reminder',
      description: 'Channel for parking location updates',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'parking_channel',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
        initialNotificationTitle: 'Parking Reminder',
        initialNotificationContent: 'Initializing tracking...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
      ),
    );
    _isInitialized = true;
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    await Firebase.initializeApp();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      flutterLocalNotificationsPlugin.show(
        888,
        'Parking Reminder',
        'Tracking your location...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'parking_channel',
            'Parking Reminder',
            icon: '@mipmap/ic_custom',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: true,
          ),
        ),
      );

      service.setForegroundNotificationInfo(
        title: "Parking Reminder",
        content: "Tracking your location...",
      );
    }

    final parkingService = ParkingService();
    Timer? locationTimer;

    service.on('stop').listen((event) {
      locationTimer?.cancel();
      service.stopSelf();
      _isRunning = false;
    });

    service.on('checkLocation').listen((event) async {
      await _checkCurrentLocation(service, parkingService);
    });

    await _checkCurrentLocation(service, parkingService);
    locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async => await _checkCurrentLocation(service, parkingService),
    );

    _isRunning = true;
  }

  static Future<void> _checkCurrentLocation(
    ServiceInstance service,
    ParkingService parkingService,
  ) async {
    try {
      print('BG_SERVICE: Checking location...');
      final position = await LocationService.getCurrentPosition();
      print('BG_SERVICE: Current position: '
          'lat=${position?.latitude}, lng=${position?.longitude}');
      if (position == null) {
        print('BG_SERVICE: Position is null, skipping.');
        return;
      }

      final lotNumbers = await parkingService.checkProximity(position);
      print('BG_SERVICE: Found lots: $lotNumbers');
      if (lotNumbers.isNotEmpty) {
        if (_lastNotificationPosition != null) {
          final dist = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            _lastNotificationPosition!.latitude, _lastNotificationPosition!.longitude,
          );
          if (dist < 50) return;
        }
        _pendingLots.addAll(lotNumbers);
        _pendingLots = _pendingLots.toSet().toList();
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 2), () async {
          if (_pendingLots.isNotEmpty) {
            final lotsText = _pendingLots.join(' ან ');
            _lastNotificationPosition = Position(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: position.timestamp,
              accuracy: position.accuracy,
              altitude: position.altitude,
              heading: position.heading,
              speed: position.speed,
              speedAccuracy: position.speedAccuracy,
              altitudeAccuracy: position.altitudeAccuracy,
              headingAccuracy: position.headingAccuracy,
            );
            final prefs = await SharedPreferences.getInstance();
            final lastLot = prefs.getString('lastNotifiedLot');
            final lastTime = prefs.getInt('lastNotifiedTime') ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            final blockedLots = prefs.getStringList('blockedLots') ?? [];
            final blockedTimes = prefs.getStringList('blockedTimes') ?? [];
            List<String> stillBlocked = [];
            List<String> stillBlockedTimes = [];
            bool isBlocked = false;
            for (int i = 0; i < blockedLots.length; i++) {
              final lot = blockedLots[i];
              final blockTime = int.tryParse(blockedTimes[i] ?? '0') ?? 0;
              if (now - blockTime < 30 * 60 * 1000 && lotsText.contains(lot)) {
                isBlocked = true;
                break;
              }
            }
            if (isBlocked) return;
            if (lastLot != lotsText || now - lastTime > 3600000) {
              print('BG_SERVICE: Sending notification for lots: $lotsText');
              await NotificationService.showParkingNotification(
                position: position,
                lotNumber: lotsText,
              );
              await prefs.setString('lastNotifiedLot', lotsText);
              await prefs.setInt('lastNotifiedTime', now);
            } else {
              print('BG_SERVICE: Notification already sent recently for these lots.');
            }
            _pendingLots.clear();
          }
        });
      } else {
        _pendingLots.clear();
      }

      final currentParking = await parkingService.getCurrentParking();
      print('BG_SERVICE: Current parking: $currentParking');
      if (currentParking != null) {
        final parkLat = currentParking['latitude'] as double?;
        final parkLng = currentParking['longitude'] as double?;
        if (parkLat != null && parkLng != null) {
          final userLatLng = LatLng(position.latitude, position.longitude);
          final parkLatLng = LatLng(parkLat, parkLng);
          final dist = Distance()(userLatLng, parkLatLng);
          print('BG_SERVICE: Distance from parked location: $dist');
          final prefs = await SharedPreferences.getInstance();
          bool leftZoneNotified = prefs.getBool('leftZoneNotified') ?? false;
          if (dist > 100 && !leftZoneNotified) {
            print('BG_SERVICE: Sending left zone notification');
            // სისტემური შეტყობინება პარკინგის დატოვების შესახებ
            await FlutterLocalNotificationsPlugin().show(
              99,
              'თქვენ დატოვეთ ზონალური პარკირების ადგილი',
              'არ დაგავიწყდეთ პარკირების დასრულება!',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'reminder_channel',
                  'Parking End Reminder',
                  importance: Importance.max,
                  priority: Priority.high,
                  icon: '@mipmap/ic_custom',
                ),
                iOS: DarwinNotificationDetails(),
              ),
            );
            await prefs.setBool('leftZoneNotified', true);
          }
        }
      }
    } catch (e) {
      // შეცდომის დამუშავება: ლოკაციის ან სხვა პრობლემის შემთხვევაში
      print('BG_SERVICE: ERROR: $e');
      service.invoke('error', {'message': 'Ошибка локации: $e'});
    }
  }

  static Future<void> start() async {
    if (_isRunning) return;
    await _service.startService();
    _isRunning = true;
  }

  static Future<void> stop() async {
    if (!_isRunning) return;
    _service.invoke('stop');
    _isRunning = false;
  }

  static Future<void> forceStop() async {
    await stop();
    _isRunning = false;
  }

  static bool get isRunning => _isRunning;
  static FlutterBackgroundService get service => _service;
}
