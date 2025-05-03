import 'package:geolocator/geolocator.dart';

class ZoneUtils {
  static bool isInParkingZone(double lat, double lng) {
    const parkLat = 41.7151;
    const parkLng = 44.8271;
    const radiusMeters = 50.0;
    final dist = Geolocator.distanceBetween(lat, lng, parkLat, parkLng);
    return dist <= radiusMeters;
  }
}
