import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class ParkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Distance _distance = const Distance();
  
  // ქეშის დამატება პარკინგების მონაცემების მიღების მიზნით
  List<Map<String, dynamic>>? _parkingsCache;
  DateTime? _lastCacheUpdate;

  // მონაცემების მიღება პარკინგების სიისთვის (ქეშის გამოყენებით)
  Future<List<Map<String, dynamic>>> getAllParkings() async {
    // თუ გვაქვს ქეში და ის არ არის 15 წუთზე ძველი, გამოვიყენებთ მას
    if (_parkingsCache != null && _lastCacheUpdate != null) {
      final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
      if (cacheAge.inMinutes < 15) {
        return _parkingsCache!;
      }
    }
    
    try {
      final snapshot = await _firestore.collection('parkings').get();
      _parkingsCache = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      _lastCacheUpdate = DateTime.now();
      return _parkingsCache!;
    } catch (e) {
      print("შეცდომა პარკირების ზონის მიღებისას: $e");
      // ქეშის გამოყენება თუ გაქვს
      return _parkingsCache ?? [];
    }
  }

  // პარკინგამდე დისტანციის შემოწმება
  Future<List<String>> checkProximity(Position userLocation, {double proximityRadius = 15}) async {
    List<Map<String, dynamic>> nearbyLotsWithDist = [];
    try {
      final parkings = await getAllParkings();
      print('CHECK_PROXIMITY: userLocation: lat=${userLocation.latitude}, lng=${userLocation.longitude}');
      for (var parking in parkings) {
        final location = parking['location'];
        if (location == null || location is! GeoPoint) {
          continue;
        }
        final geoPoint = location as GeoPoint;
        final lotNumber = parking['lotNumber'].toString();
        final userLatLng = LatLng(userLocation.latitude, userLocation.longitude);
        final parkLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
        final distMeters = _distance(userLatLng, parkLatLng);
        if (distMeters <= 30) {
          print('CHECK_PROXIMITY: lot=$lotNumber, parkLat=${geoPoint.latitude}, parkLng=${geoPoint.longitude}, dist=$distMeters');
        }
        if (distMeters <= proximityRadius) {
          nearbyLotsWithDist.add({'lotNumber': lotNumber, 'dist': distMeters});
        }
      }
      // ჯერ დავალაგოთ დისტანციის მიხედვით
      nearbyLotsWithDist.sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));
      // დავაბრუნოთ მხოლოდ lotNumber-ების სია, ყველაზე ახლოს მყოფი პირველია
      final result = nearbyLotsWithDist.map((e) => e['lotNumber'] as String).toList();
      print('CHECK_PROXIMITY: nearbyLots(sorted): $result');
      return result;
    } catch (e) {
      print("დისტანციის შემოწმების შეცდომა: $e");
      return [];
    }
  }
  
  // პარკინგის ინფორმაციის შენახვა
  Future<bool> saveUserParking({
    required String lotNumber,
    required double latitude,
    required double longitude,
    required DateTime startTime,
  }) async {
    try {
      // პარკინგის ინფორმაციის შენახვა ლოკალურ მონაცემთა ბაზაში
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentParkingLot', lotNumber);
      await prefs.setDouble('currentParkingLat', latitude);
      await prefs.setDouble('currentParkingLng', longitude);
      await prefs.setInt('currentParkingStart', startTime.millisecondsSinceEpoch);
      
      // პარკინგის ინფორმაციის შენახვა Firebase-ში
      await _firestore.collection('user_parkings').add({
        'lotNumber': lotNumber,
        'location': GeoPoint(latitude, longitude),
        'startTime': Timestamp.fromDate(startTime),
        'userId': await _getUserId(),
      });
      
      return true;
    } catch (e) {
      print("შეცდომა პარკირების ზონის შენახვისას: $e");
      return false;
    }
  }
  
  // მომხმარებლის ID-ის მიღება
  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    
    return userId ?? 'default_user_id';
  }
  
  // მიმდინარე მოქმედი პარკინგის მიღება
  Future<Map<String, dynamic>?> getCurrentParking() async {
    final prefs = await SharedPreferences.getInstance();
    final lotNumber = prefs.getString('currentParkingLot');
    
    if (lotNumber == null) return null;
    
    return {
      'lotNumber': lotNumber,
      'latitude': prefs.getDouble('currentParkingLat'),
      'longitude': prefs.getDouble('currentParkingLng'),
      'startTime': DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('currentParkingStart') ?? 0
      ),
    };
  }
  
  // პარკინგის დასრულება
  Future<bool> endParking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentParkingLot');
      await prefs.remove('currentParkingLat');
      await prefs.remove('currentParkingLng');
      await prefs.remove('currentParkingStart');
      
      return true;
    } catch (e) {
      print("შეცდომა პარკირების დასრულებისას: $e");
      return false;
    }
  }

  // foreground და background რეჟიმში ბლოკირების ლოგიკა
}