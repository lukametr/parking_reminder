// lib/services/moving_average_filter.dart

import 'package:latlong2/latlong.dart';

class MovingAverageFilter {
  final int windowSize;
  final List<LatLng> _latitudeBuffer = [];
  final List<LatLng> _longitudeBuffer = [];

  MovingAverageFilter({required this.windowSize});

  LatLng? filter(LatLng newLocation) {
    _latitudeBuffer.add(LatLng(newLocation.latitude, 0));
    _longitudeBuffer.add(LatLng(0, newLocation.longitude));

    if (_latitudeBuffer.length > windowSize) {
      _latitudeBuffer.removeAt(0);
      _longitudeBuffer.removeAt(0);
    }

    if (_latitudeBuffer.isEmpty) {
      return null;
    }

    double sumLatitude = 0;
    for (final latLng in _latitudeBuffer) {
      sumLatitude += latLng.latitude;
    }
    double avgLatitude = sumLatitude / _latitudeBuffer.length;

    double sumLongitude = 0;
    for (final latLng in _longitudeBuffer) {
      sumLongitude += latLng.longitude;
    }
    double avgLongitude = sumLongitude / _longitudeBuffer.length;

    return LatLng(avgLatitude, avgLongitude);
  }
}