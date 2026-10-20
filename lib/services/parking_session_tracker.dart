import 'package:shared_preferences/shared_preferences.dart';

import '../utils/lot_index.dart';
import 'notification_service.dart';
import 'parking_monitor.dart';

/// Local "I started paid parking in the official app" session.
/// No countdown — Tbilisi zonal parking is billed continuously per minute.
/// Leave-lot → remind to turn parking OFF in ge.msda.parking.
class ParkingSessionTracker {
  ParkingSessionTracker({
    this.exitBufferMeters = 80,
    this.onLeftLot,
    this.emitNotifications = true,
  });

  final double exitBufferMeters;
  final void Function(String lot)? onLeftLot;
  final bool emitNotifications;

  String? _activeLot;
  double? _parkLat;
  double? _parkLng;
  bool _leftNotified = false;

  String? get activeLot => _activeLot;
  bool get hasActiveSession => _activeLot != null;

  Future<void> restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? lot = prefs.getString('currentParkingLot');
    final double? lat = prefs.getDouble('currentParkingLat');
    final double? lng = prefs.getDouble('currentParkingLng');
    if (lot == null || lat == null || lng == null) return;
    _activeLot = lot;
    _parkLat = lat;
    _parkLng = lng;
    _leftNotified = false;
    await ParkingMonitor.instance.setSession(
      lotNumber: lot,
      latitude: lat,
      longitude: lng,
    );
  }

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
    final String lot = _activeLot!;
    if (emitNotifications) {
      await NotificationService.showLeaveLotNotification(lotNumber: lot);
    }
    onLeftLot?.call(lot);
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
    await ParkingMonitor.instance.setSession(
      lotNumber: lotNumber,
      latitude: latitude,
      longitude: longitude,
    );
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
    await ParkingMonitor.instance.clearSession();
  }
}
