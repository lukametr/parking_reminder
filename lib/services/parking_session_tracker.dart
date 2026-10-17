import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/lot_index.dart';
import '../utils/stationary_detector.dart';
import 'notification_service.dart';

/// 55-minute paid-session reminder + leave-zone notice. Lots come from
/// Firestore (via [LotIndex]), never from main's demo SQLite.
class ParkingSessionTracker {
  ParkingSessionTracker({
    StationaryDetector? detector,
    this.exitBufferMeters = 80,
    this.reminder = const Duration(minutes: 55),
  }) : _detector = detector ?? StationaryDetector();

  final StationaryDetector _detector;
  final double exitBufferMeters;
  final Duration reminder;

  String? _activeLot;
  double? _parkLat;
  double? _parkLng;
  Timer? _reminderTimer;

  String? get activeLot => _activeLot;

  Future<void> processFix({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double speedMps,
    required List<String> nearbyLotNumbers,
    DateTime? now,
  }) async {
    final bool still = _detector.isStationary(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      speedMps: speedMps,
      now: now,
    );

    if (_activeLot != null && _parkLat != null && _parkLng != null) {
      final double dist = LotIndex.haversineMeters(
        latitude,
        longitude,
        _parkLat!,
        _parkLng!,
      );
      if (dist > exitBufferMeters) {
        await NotificationService.showSimpleNotification(
          title: 'პარკინგის ზონა დატოვებულია',
          message: '$_activeLot — არ დაგავიწყდეთ პარკირების დასრულება.',
        );
        await endSession();
        return;
      }
    }

    if (!still || nearbyLotNumbers.isEmpty) return;
    if (_activeLot != null) return;

    await beginSession(
      lotNumber: nearbyLotNumbers.first,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> beginSession({
    required String lotNumber,
    required double latitude,
    required double longitude,
  }) async {
    _activeLot = lotNumber;
    _parkLat = latitude;
    _parkLng = longitude;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentParkingLot', lotNumber);
    await prefs.setDouble('currentParkingLat', latitude);
    await prefs.setDouble('currentParkingLng', longitude);
    await prefs.setInt(
      'currentParkingStart',
      DateTime.now().millisecondsSinceEpoch,
    );
    _reminderTimer?.cancel();
    _reminderTimer = Timer(reminder, () async {
      await NotificationService.showSimpleNotification(
        title: 'პარკინგის შეხსენება',
        message: '$lotNumber — გადაამოწმეთ პარკინგის დრო/ლოტი.',
      );
    });
  }

  Future<void> endSession() async {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _activeLot = null;
    _parkLat = null;
    _parkLng = null;
    _detector.reset();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentParkingLot');
    await prefs.remove('currentParkingLat');
    await prefs.remove('currentParkingLng');
    await prefs.remove('currentParkingStart');
  }
}
