import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ParkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Distance _distance = const Distance();

  /// Проверка близости пользователя к парковкам из Firestore
  /// Если в радиусе 30 м, возвращает номер лота, иначе null
  Future<String?> checkProximity(Position userLocation) async {
    try {
      final snapshot = await _firestore.collection('parkings').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final geoPoint = data['location'] as GeoPoint;
        final lotNumber = data['lotNumber'].toString();

        final userLatLng = LatLng(userLocation.latitude, userLocation.longitude);
        final parkLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
        final distMeters = _distance(userLatLng, parkLatLng);

        if (distMeters <= 30) {
          return lotNumber;
        }
      }
    } catch (e) {
      print("შეცდომა proximity: $e");
    }
    return null;
  }
}