import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/nearby_category.dart';

class NearbyPlace {
  final String id;
  final String name;
  final String kind;
  final double lat;
  final double lng;
  final String? address;
  final String? phone;
  final String? openingHours;
  final double distanceMeters;

  const NearbyPlace({
    required this.id,
    required this.name,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.address,
    this.phone,
    this.openingHours,
  });
}

class NearbyPlacesException implements Exception {
  final String message;
  const NearbyPlacesException(this.message);
  @override
  String toString() => message;
}

/// Nearby places from OpenStreetMap (no API key): Overpass radius search,
/// falling back to Nominatim when every Overpass instance is down or busy.
class NearbyPlacesService {
  NearbyPlacesService({
    http.Client? client,
    this.nominatimSpacing = const Duration(milliseconds: 1100),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Nominatim's usage policy allows at most one request per second.
  final Duration nominatimSpacing;

  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];
  static const String _nominatimHost = 'nominatim.openstreetmap.org';

  static const String _userAgent = 'ParkingReminderPlus/1.1 (com.lukacode.sosapp)';
  static const int maxResults = 60;

  /// City-sized first, widening for towns and villages; 10 km is the cap.
  static const List<int> radiusSteps = [2500, 5000, 10000];

  bool _overpassDown = false;
  DateTime? _lastNominatimAt;

  /// Searches each radius in [radii] until at least [minResults] places are found.
  Future<({List<NearbyPlace> places, int radiusMeters})> search({
    required NearbyCategory category,
    required double lat,
    required double lng,
    List<int> radii = radiusSteps,
    int minResults = 5,
  }) async {
    List<NearbyPlace> places = const [];
    int usedRadius = radii.first;
    for (final int radius in radii) {
      places = await _query(category, lat, lng, radius);
      usedRadius = radius;
      if (places.length >= minResults) break;
    }
    return (places: places, radiusMeters: usedRadius);
  }

  Future<List<NearbyPlace>> _query(
    NearbyCategory category,
    double lat,
    double lng,
    int radius,
  ) async {
    if (!_overpassDown) {
      try {
        return await _overpass(category, lat, lng, radius);
      } on NearbyPlacesException {
        _overpassDown = true;
      }
    }
    return _nominatim(category, lat, lng, radius);
  }

  Future<List<NearbyPlace>> _overpass(
    NearbyCategory category,
    double lat,
    double lng,
    int radius,
  ) async {
    final String around = '(around:$radius,$lat,$lng)';
    // A small server-side timeout and maxsize make a busy instance fail fast
    // instead of stalling the next fallback.
    final String body = '[out:json][timeout:8][maxsize:33554432];('
        '${category.osmFilters.map((f) => 'nwr$f$around;').join()}'
        ');out center tags 400;';

    Object? lastError;
    for (final String endpoint in _overpassEndpoints) {
      try {
        final http.Response res = await _client
            .post(
              Uri.parse(endpoint),
              headers: {
                'User-Agent': _userAgent,
                'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              },
              body: {'data': body},
            )
            .timeout(const Duration(seconds: 9));
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        final Map<String, dynamic> data =
            json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final List<NearbyPlace> places = [];
        for (final dynamic raw in (data['elements'] as List<dynamic>?) ?? const []) {
          final Map<String, dynamic> el = raw as Map<String, dynamic>;
          final Map<String, dynamic>? center = el['center'] as Map<String, dynamic>?;
          final double? pLat = ((el['lat'] ?? center?['lat']) as num?)?.toDouble();
          final double? pLng = ((el['lon'] ?? center?['lon']) as num?)?.toDouble();
          if (pLat == null || pLng == null) continue;
          final Map<String, dynamic> tags =
              (el['tags'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
          places.add(_place(
            id: '${el['type']}/${el['id']}',
            tags: tags,
            address: _address(tags),
            category: category,
            lat: pLat,
            lng: pLng,
            originLat: lat,
            originLng: lng,
          ));
        }
        return _finish(places, radius);
      } catch (e) {
        lastError = e;
      }
    }
    throw NearbyPlacesException('Overpass unavailable: $lastError');
  }

  Future<List<NearbyPlace>> _nominatim(
    NearbyCategory category,
    double lat,
    double lng,
    int radius,
  ) async {
    final double dLat = radius / 111320;
    final double dLng = radius / (111320 * math.cos(_rad(lat)));
    final String viewbox = '${lng - dLng},${lat + dLat},${lng + dLng},${lat - dLat}';

    final List<NearbyPlace> places = [];
    Object? lastError;
    bool anyOk = false;
    for (int i = 0; i < category.nominatimQueries.length; i++) {
      final DateTime? last = _lastNominatimAt;
      if (last != null) {
        final Duration wait = nominatimSpacing - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastNominatimAt = DateTime.now();
      try {
        final http.Response res = await _client.get(
          Uri.https(_nominatimHost, '/search', {
            'q': category.nominatimQueries[i],
            'format': 'jsonv2',
            'viewbox': viewbox,
            'bounded': '1',
            'limit': '40',
            'addressdetails': '1',
            'extratags': '1',
            'namedetails': '1',
            'accept-language': 'ka',
          }),
          headers: {'User-Agent': _userAgent},
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        anyOk = true;
        for (final dynamic raw in json.decode(utf8.decode(res.bodyBytes)) as List<dynamic>) {
          final Map<String, dynamic> r = raw as Map<String, dynamic>;
          final double? pLat = double.tryParse('${r['lat']}');
          final double? pLng = double.tryParse('${r['lon']}');
          if (pLat == null || pLng == null) continue;
          final Map<String, dynamic> tags = {
            ...?(r['extratags'] as Map<String, dynamic>?),
            ...?(r['namedetails'] as Map<String, dynamic>?),
            if (r['category'] is String) '${r['category']}': r['type'],
          };
          places.add(_place(
            id: '${r['osm_type']}/${r['osm_id']}',
            tags: tags,
            address: _nominatimAddress(r['address'] as Map<String, dynamic>?),
            category: category,
            lat: pLat,
            lng: pLng,
            originLat: lat,
            originLng: lng,
          ));
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (!anyOk) throw NearbyPlacesException('Nominatim unavailable: $lastError');
    return _finish(places, radius);
  }

  NearbyPlace _place({
    required String id,
    required Map<String, dynamic> tags,
    required String? address,
    required NearbyCategory category,
    required double lat,
    required double lng,
    required double originLat,
    required double originLng,
  }) {
    final String kind = _kindLabel(tags, category);
    return NearbyPlace(
      id: id,
      name: _name(tags) ?? kind,
      kind: kind,
      lat: lat,
      lng: lng,
      address: address,
      phone: _str(tags['contact:phone']) ?? _str(tags['phone']) ?? _str(tags['contact:mobile']),
      openingHours: _str(tags['opening_hours']),
      distanceMeters: distanceMeters(originLat, originLng, lat, lng),
    );
  }

  List<NearbyPlace> _finish(List<NearbyPlace> places, int radius) {
    final Map<String, NearbyPlace> byId = {
      for (final NearbyPlace p in places)
        if (p.distanceMeters <= radius) p.id: p,
    };
    final List<NearbyPlace> list = byId.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list.length > maxResults ? list.sublist(0, maxResults) : list;
  }

  static String? _nominatimAddress(Map<String, dynamic>? a) {
    if (a == null) return null;
    final String? road = _str(a['road']) ?? _str(a['pedestrian']);
    final String? number = _str(a['house_number']);
    final String? area = _str(a['suburb']) ?? _str(a['neighbourhood']) ?? _str(a['city']);
    final List<String> parts = [
      if (road != null) number != null ? '$road $number' : road,
      if (area != null) area,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  static String? _str(Object? v) {
    if (v is! String) return null;
    final String t = v.trim();
    return t.isEmpty ? null : t;
  }

  static String? _name(Map<String, dynamic> tags) =>
      _str(tags['name:ka']) ??
      _str(tags['name']) ??
      _str(tags['brand:ka']) ??
      _str(tags['brand']) ??
      _str(tags['name:en']) ??
      _str(tags['operator']);

  static String? _address(Map<String, dynamic> tags) {
    final String? full = _str(tags['addr:full']);
    if (full != null) return full;
    final String? street = _str(tags['addr:street']);
    final String? number = _str(tags['addr:housenumber']);
    final String? city = _str(tags['addr:city']);
    final List<String> parts = [
      if (street != null) number != null ? '$street $number' : street,
      if (city != null) city,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  static String _kindLabel(Map<String, dynamic> tags, NearbyCategory category) {
    const Map<String, String> labels = {
      'restaurant': 'რესტორანი',
      'cafe': 'კაფე',
      'fast_food': 'სწრაფი კვება',
      'food_court': 'კვების კორტი',
      'supermarket': 'სუპერმარკეტი',
      'convenience': 'მარკეტი',
      'general': 'მაღაზია',
      'department_store': 'უნივერმაღი',
      'mall': 'სავაჭრო ცენტრი',
      'greengrocer': 'ხილ-ბოსტნეული',
      'grocery': 'სასურსათო მაღაზია',
      'car_repair': 'ავტოსერვისი',
      'car_parts': 'ავტონაწილები',
      'tyres': 'ვულკანიზაცია',
    };
    if (category == NearbyCategory.vulcanization) return category.singular;
    final String? key = _str(tags['amenity']) ?? _str(tags['shop']);
    return labels[key] ?? category.singular;
  }

  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371000;
    final double dLat = _rad(lat2 - lat1);
    final double dLng = _rad(lng2 - lng1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} მ';
    final String km = (meters / 1000).toStringAsFixed(1);
    return '${km.endsWith('.0') ? km.substring(0, km.length - 2) : km} კმ';
  }
}
