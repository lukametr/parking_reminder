import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/stationary_detector.dart';
import 'parking_session_tracker.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final StationaryDetector _stationary = StationaryDetector.instance;
  bool _lastStationary = false;

  /// ბოლო ფიქსისთვის — ფონური ტაიმერი იგივე მნიშვნელობას იყენებს (ორმაგი დეტექტორი არა).
  bool get lastStationary => _lastStationary;

  Future<void> startLocationUpdates() async {
    final bool hasPermission = await _requestLocationPermission();
    if (!hasPermission) return;

    await _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onLocationChanged, onError: (_) {});
  }

  void _onLocationChanged(Position position) {
    _currentPosition = position;
    _lastStationary = _stationary.isStationary(position);
    unawaited(
      ParkingSessionTracker.instance.process(
        position,
        isStationary: _lastStationary,
      ),
    );
  }

  Future<bool> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) return false;
    final backgroundStatus = await Permission.locationAlways.request();
    return backgroundStatus == PermissionStatus.granted;
  }

  void stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
    ParkingSessionTracker.instance.cancelSession();
  }

  Position? get currentPosition => _currentPosition;
}
