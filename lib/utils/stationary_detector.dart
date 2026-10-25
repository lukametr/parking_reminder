import 'lot_index.dart';

/// Gating for "parked": low speed, small displacement, settle time.
/// Native Activity Recognition is the primary battery signal; this is for
/// Dart session reminders and unit tests.
class StationaryDetector {
  StationaryDetector({
    this.maxAccuracyMeters = 48,
    this.maxSpeedMps = 2.8,
    this.moveThresholdM = 22,
    this.settle = const Duration(seconds: 5),
  });

  final double maxAccuracyMeters;
  final double maxSpeedMps;
  final double moveThresholdM;
  final Duration settle;

  double? _prevLat;
  double? _prevLng;
  DateTime? _stillSince;

  void reset() {
    _prevLat = null;
    _prevLng = null;
    _stillSince = null;
  }

  bool isStationary({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double speedMps,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    if (accuracyMeters > maxAccuracyMeters) {
      reset();
      return false;
    }
    if (speedMps >= 0 && speedMps > maxSpeedMps) {
      _prevLat = latitude;
      _prevLng = longitude;
      _stillSince = t;
      return false;
    }
    if (_prevLat == null || _prevLng == null) {
      _prevLat = latitude;
      _prevLng = longitude;
      _stillSince = t;
      return false;
    }
    final double dist = LotIndex.haversineMeters(
      _prevLat!,
      _prevLng!,
      latitude,
      longitude,
    );
    if (dist > moveThresholdM) {
      _prevLat = latitude;
      _prevLng = longitude;
      _stillSince = t;
      return false;
    }
    _stillSince ??= t;
    return t.difference(_stillSince!) >= settle;
  }
}
