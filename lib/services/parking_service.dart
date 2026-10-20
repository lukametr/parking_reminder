import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parking_lot.dart';
import '../utils/lot_index.dart';
import 'parking_monitor.dart';

class ParkingService {
  ParkingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  LotIndex? _index;
  DateTime? _lastCacheUpdate;

  Future<List<ParkingLot>> getAllParkings({bool force = false}) async {
    if (!force &&
        _index != null &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 15) {
      return _index!.lots;
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('parkings').get();
      final List<ParkingLot> lots = snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        final Object? location = data['location'];
        double lat = 0;
        double lng = 0;
        if (location is GeoPoint) {
          lat = location.latitude;
          lng = location.longitude;
        }
        return ParkingLot(
          id: doc.id,
          lotNumber: '${data['lotNumber']}',
          latitude: lat,
          longitude: lng,
        );
      }).where((ParkingLot e) => e.latitude != 0 || e.longitude != 0).toList();
      _index = LotIndex(lots);
      _lastCacheUpdate = DateTime.now();
      await ParkingMonitor.instance.syncLots(lots);
      return lots;
    } catch (_) {
      return _index?.lots ?? <ParkingLot>[];
    }
  }

  Future<List<String>> checkProximity(
    Position userLocation, {
    double proximityRadius = 8,
  }) async {
    await getAllParkings();
    final LotIndex? index = _index;
    if (index == null) return <String>[];
    final ParkingLot? lot = index.nearestWithin(
      userLocation.latitude,
      userLocation.longitude,
      radiusMeters: proximityRadius,
    );
    if (lot == null) return <String>[];
    return <String>[lot.lotNumber];
  }

  /// Local session only — do not write `user_parkings` while rules are open.
  Future<bool> saveUserParking({
    required String lotNumber,
    required double latitude,
    required double longitude,
    required DateTime startTime,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentParkingLot', lotNumber);
    await prefs.setDouble('currentParkingLat', latitude);
    await prefs.setDouble('currentParkingLng', longitude);
    await prefs.setInt('currentParkingStart', startTime.millisecondsSinceEpoch);
    return true;
  }

  Future<Map<String, dynamic>?> getCurrentParking() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? lotNumber = prefs.getString('currentParkingLot');
    if (lotNumber == null) return null;
    return <String, dynamic>{
      'lotNumber': lotNumber,
      'latitude': prefs.getDouble('currentParkingLat'),
      'longitude': prefs.getDouble('currentParkingLng'),
      'startTime': DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('currentParkingStart') ?? 0,
      ),
    };
  }

  Future<bool> endParking() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentParkingLot');
    await prefs.remove('currentParkingLat');
    await prefs.remove('currentParkingLng');
    await prefs.remove('currentParkingStart');
    return true;
  }
}
