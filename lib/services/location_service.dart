import 'package:geolocator/geolocator.dart';
import 'package:parking_reminder/services/kalman_filter.dart';
import 'package:parking_reminder/services/moving_average_filter.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static final KalmanLocationFilter kalmanFilter = KalmanLocationFilter();
  static final MovingAverageFilter movingAverage = MovingAverageFilter(windowSize: 5);
  static bool _isFiltered = false;
  
  // Настройки точности для различных ситуаций
  static const _highAccuracySettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );
  
  static const _navigationAccuracySettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 2,
  );

  // Проверка и запрос разрешений на доступ к местоположению
  static Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    
    return true;
  }

  // Получение текущей позиции
  static Future<Position?> getPosition() async {
    return getCurrentPosition();
  }

  static Future<Position?> getCurrentPosition({bool filtered = true}) async {
    if (!await checkAndRequestPermission()) {
      return null;
    }
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      if (filtered) {
        if (!_isFiltered) {
          kalmanFilter.init(position);
          _isFiltered = true;
        }
        final filteredPos = kalmanFilter.process(position);
        final avgLatLng = movingAverage.filter(
          LatLng(filteredPos.latitude, filteredPos.longitude),
        );
        print('KALMAN: raw=${position.latitude},${position.longitude} filtered=${filteredPos.latitude},${filteredPos.longitude} avg=${avgLatLng?.latitude},${avgLatLng?.longitude}');
        if (avgLatLng != null) {
          return Position(
            latitude: avgLatLng.latitude,
            longitude: avgLatLng.longitude,
            timestamp: filteredPos.timestamp,
            accuracy: filteredPos.accuracy,
            altitude: filteredPos.altitude,
            heading: filteredPos.heading,
            speed: filteredPos.speed,
            speedAccuracy: filteredPos.speedAccuracy,
            altitudeAccuracy: filteredPos.altitudeAccuracy,
            headingAccuracy: filteredPos.headingAccuracy,
          );
        }
        return filteredPos;
      }
      
      return position;
    } catch (e) {
      print('Ошибка получения местоположения: $e');
      return null;
    }
  }
  
  // Начать отслеживание с фильтром Калмана
  static Stream<Position> getPositionStream({bool useFilter = true}) {
    return Geolocator.getPositionStream(
      locationSettings: _navigationAccuracySettings,
    ).map((position) {
      if (useFilter) {
        if (!_isFiltered) {
          kalmanFilter.init(position);
          _isFiltered = true;
        }
        return kalmanFilter.process(position);
      }
      return position;
    });
  }
}