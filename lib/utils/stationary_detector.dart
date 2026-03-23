import 'package:geolocator/geolocator.dart';

/// გაჩერების დეტექცია: სიჩქარე, მცირე გადაადგილება, სტაბილური დრო, GPS ზუსტობა.
class StationaryDetector {
  StationaryDetector._();
  static final StationaryDetector instance = StationaryDetector._();

  Position? _prev;
  DateTime? _prevTime;

  static const double _maxAccuracyMeters = 48.0;
  static const double _maxSpeedMps = 1.15;
  static const double _moveThresholdM = 22.0;
  static const int _settleSeconds = 55;

  void reset() {
    _prev = null;
    _prevTime = null;
  }

  bool isStationary(Position p) {
    final DateTime now = DateTime.now();

    if (p.accuracy > _maxAccuracyMeters) {
      return false;
    }

    if (_prev == null || _prevTime == null) {
      _prev = p;
      _prevTime = now;
      return false;
    }

    final double dist = Geolocator.distanceBetween(
      _prev!.latitude,
      _prev!.longitude,
      p.latitude,
      p.longitude,
    );

    final double speed = p.speed;
    if (speed >= 0 && speed > _maxSpeedMps) {
      _prev = p;
      _prevTime = now;
      return false;
    }

    if (dist > _moveThresholdM) {
      _prev = p;
      _prevTime = now;
      return false;
    }

    if (now.difference(_prevTime!).inSeconds < _settleSeconds) {
      return false;
    }

    _prev = p;
    _prevTime = now;
    return true;
  }
}
