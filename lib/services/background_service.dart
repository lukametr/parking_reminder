import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
import 'notification_service.dart';
import 'parking_session_tracker.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final LocationService _locationService = LocationService();

  Timer? _timer;
  bool _isRunning = false;

  Future<void> startForegroundService() async {
    if (_isRunning) return;

    _isRunning = true;

    await _locationService.startLocationUpdates();
    _startPeriodicCheck();

    await NotificationService.instance.showServiceMessage(
      90001,
      'პარკინგის კონტროლი',
      'მონიტორინგი ჩართულია. აპლიკაცია შეგიძლიათ ჩაკეცოთ.',
    );
  }

  Future<void> stopService() async {
    if (!_isRunning) return;

    _isRunning = false;

    _timer?.cancel();
    _timer = null;

    _locationService.stopLocationUpdates();

    await NotificationService.instance.showServiceMessage(
      90002,
      'პარკინგის კონტროლი',
      'მონიტორინგი გამორთულია.',
    );
  }

  void _startPeriodicCheck() {
    _timer = Timer.periodic(const Duration(seconds: 45), (Timer timer) async {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      await _performPeriodicCheck();
    });
  }

  Future<void> _performPeriodicCheck() async {
    try {
      final Position? position = _locationService.currentPosition;
      if (position == null) return;

      await ParkingSessionTracker.instance.process(
        position,
        isStationary: _locationService.lastStationary,
      );
    } catch (e) {
      debugPrint('პერიოდული შემოწმება: $e');
    }
  }

  bool get isRunning => _isRunning;
}
