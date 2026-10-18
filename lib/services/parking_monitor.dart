import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/parking_lot.dart';

/// Talks to the native Fused Location + Activity Recognition foreground service.
class ParkingMonitor {
  ParkingMonitor._();
  static final ParkingMonitor instance = ParkingMonitor._();

  static const MethodChannel _methods =
      MethodChannel('com.findall.ParkingReminder/monitor');
  static const EventChannel _events =
      EventChannel('com.findall.ParkingReminder/monitor_events');

  Stream<MonitorEvent>? _eventStream;

  Stream<MonitorEvent> get events {
    return _eventStream ??= _events.receiveBroadcastStream().map((dynamic raw) {
      final Map<Object?, Object?> map = raw as Map<Object?, Object?>;
      return MonitorEvent(
        type: map['type'] as String? ?? '',
        lots: ((map['lots'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
        latitude: (map['lat'] as num?)?.toDouble() ?? 0,
        longitude: (map['lng'] as num?)?.toDouble() ?? 0,
        accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
        speed: (map['speed'] as num?)?.toDouble() ?? 0,
        activity: map['activity'] as String? ?? 'unknown',
      );
    });
  }

  Future<void> syncLots(List<ParkingLot> lots) async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>(
      'syncLots',
      jsonEncode(lots.map((ParkingLot e) => e.toNativeMap()).toList()),
    );
  }

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('start');
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('stop');
  }

  Future<bool> hasAlwaysLocation() async {
    if (!Platform.isAndroid) return false;
    return await _methods.invokeMethod<bool>('hasAlwaysLocation') ?? false;
  }

  Future<void> openLocationSettings() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('openLocationSettings');
  }

  Future<void> setSession({
    required String lotNumber,
    required double latitude,
    required double longitude,
  }) async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('setSession', <String, Object>{
      'lot': lotNumber,
      'lat': latitude,
      'lng': longitude,
    });
  }

  Future<void> clearSession() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('clearSession');
  }
}

class MonitorEvent {
  const MonitorEvent({
    required this.type,
    required this.lots,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.activity,
  });

  final String type;
  final List<String> lots;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final String activity;
}
