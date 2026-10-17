import 'package:shared_preferences/shared_preferences.dart';

import '../utils/lot_index.dart';
import 'notification_service.dart';

/// Local "I started paid parking in the official app" session.
/// No countdown — Tbilisi zonal parking is billed continuously per minute.
/// Leave-lot → remind to turn parking OFF in ge.msda.parking.
class ParkingSessionTracker {
  ParkingSessionTracker({this.exitBufferMeters = 80});

  final double exitBufferMeters;

  String? _activeLot;
  double? _parkLat;
  double? _parkLng;
  bool _leftNotified = false;

  String? get activeLot => _activeLot;

  Future<void> processFix({
    required double latitude,
    required double longitude,
  }) async {
    if (_activeLot == null || _parkLat == null || _parkLng == null) return;
    final double dist = LotIndex.haversineMeters(
      latitude,
      longitude,
      _parkLat!,
      _parkLng!,
    );
    if (dist <= exitBufferMeters) {
      _leftNotified = false;
      return;
    }
    if (_leftNotified) return;
    _leftNotified = true;
    await NotificationService.showSimpleNotification(
      title: 'დატოვეთ პარკირების ლოტი',
      message:
          '$_activeLot — გამორთეთ პარკირება ოფიციალურ აპში (MSDA / ge.msda.parking).',
    );
    await endSession();
  }

  Future<void> beginSession({
    required String lotNumber,
    required double latitude,
    required double longitude,
  }) async {
    _activeLot = lotNumber;
    _parkLat = latitude;
    _parkLng = longitude;
    _leftNotified = false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentParkingLot', lotNumber);
    await prefs.setDouble('currentParkingLat', latitude);
    await prefs.setDouble('currentParkingLng', longitude);
  }

  Future<void> endSession() async {
    _activeLot = null;
    _parkLat = null;
    _parkLng = null;
    _leftNotified = false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentParkingLot');
    await prefs.remove('currentParkingLat');
    await prefs.remove('currentParkingLng');
    await prefs.remove('currentParkingStart');
  }
}
