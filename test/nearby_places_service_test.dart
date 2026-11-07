import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_reminder/models/nearby_category.dart';
import 'package:parking_reminder/services/nearby_places_service.dart';

void main() {
  const double lat = 41.6938;
  const double lng = 44.8015;

  String overpass(List<Map<String, dynamic>> elements) =>
      json.encode({'elements': elements});

  test('parses nodes and ways, sorts by distance, falls back on names', () async {
    final List<String> queries = [];
    final MockClient client = MockClient((http.Request req) async {
      queries.add(Uri.splitQueryString(req.body)['data']!);
      return http.Response.bytes(
        utf8.encode(overpass([
          {
            'type': 'way',
            'id': 2,
            'center': {'lat': 41.70, 'lon': 44.81},
            'tags': {'amenity': 'police', 'name': 'Far station'},
          },
          {
            'type': 'node',
            'id': 1,
            'lat': 41.6940,
            'lon': 44.8016,
            'tags': {
              'amenity': 'police',
              'name:ka': 'მთაწმინდის განყოფილება',
              'addr:street': 'რუსთაველის გამზირი',
              'addr:housenumber': '10',
              'phone': '+995 32 000 000',
            },
          },
          {
            'type': 'node',
            'id': 3,
            'lat': 41.695,
            'lon': 44.803,
            'tags': {'amenity': 'police'},
          },
        ])),
        200,
      );
    });

    final result = await NearbyPlacesService(client: client).search(
      category: NearbyCategory.police,
      lat: lat,
      lng: lng,
      minResultsBeforeWidening: 0,
    );

    expect(queries.single, contains('nwr["amenity"="police"](around:2500,$lat,$lng);'));
    expect(result.places.map((p) => p.id), ['node/1', 'node/3', 'way/2']);
    final NearbyPlace first = result.places.first;
    expect(first.name, 'მთაწმინდის განყოფილება');
    expect(first.address, 'რუსთაველის გამზირი 10');
    expect(first.phone, '+995 32 000 000');
    expect(result.places[1].name, NearbyCategory.police.singular);
  });

  test('widens the radius when too few results', () async {
    final List<String> queries = [];
    final MockClient client = MockClient((http.Request req) async {
      queries.add(Uri.splitQueryString(req.body)['data']!);
      return http.Response(overpass([]), 200);
    });

    final result = await NearbyPlacesService(client: client).search(
      category: NearbyCategory.fuel,
      lat: lat,
      lng: lng,
    );

    expect(queries, hasLength(2));
    expect(queries.last, contains('around:7000'));
    expect(result.radiusMeters, 7000);
    expect(result.places, isEmpty);
  });

  test('falls back to the next endpoint and throws when all fail', () async {
    int calls = 0;
    final MockClient failing = MockClient((_) async {
      calls++;
      return http.Response('busy', 429);
    });

    await expectLater(
      NearbyPlacesService(client: failing).search(
        category: NearbyCategory.pharmacy,
        lat: lat,
        lng: lng,
      ),
      throwsA(isA<NearbyPlacesException>()),
    );
    expect(calls, 3);
  });

  test('uses Nominatim when every Overpass instance fails', () async {
    final List<Uri> calls = [];
    final MockClient client = MockClient((http.Request req) async {
      calls.add(req.url);
      if (req.url.host != 'nominatim.openstreetmap.org') {
        return http.Response('Gateway Time-out', 504);
      }
      final String q = req.url.queryParameters['q']!;
      return http.Response.bytes(
        utf8.encode(json.encode([
          {
            'osm_type': 'node',
            'osm_id': q == 'restaurant' ? 10 : 11,
            'lat': q == 'restaurant' ? '41.6945' : '41.6990',
            'lon': '44.8020',
            'category': 'amenity',
            'type': q == 'restaurant' ? 'restaurant' : 'cafe',
            'namedetails': {'name': q == 'restaurant' ? 'Metis' : 'Station Cafe'},
            'address': {'road': 'რუსთაველის გამზირი', 'house_number': '5', 'suburb': 'მთაწმინდა'},
            'extratags': {'opening_hours': '10:00-23:00'},
          },
        ])),
        200,
      );
    });

    final result = await NearbyPlacesService(client: client, nominatimSpacing: Duration.zero)
        .search(category: NearbyCategory.food, lat: lat, lng: lng, minResultsBeforeWidening: 0);

    expect(calls.where((u) => u.host != 'nominatim.openstreetmap.org'), hasLength(2));
    expect(calls.where((u) => u.host == 'nominatim.openstreetmap.org'), hasLength(3));
    expect(calls.last.queryParameters['bounded'], '1');
    expect(result.places.map((p) => p.name), ['Metis', 'Station Cafe']);
    expect(result.places.first.kind, 'რესტორანი');
    expect(result.places.first.address, 'რუსთაველის გამზირი 5, მთაწმინდა');
    expect(result.places.last.kind, 'კაფე');
    expect(result.places.first.openingHours, '10:00-23:00');
  });

  test('formats distances in Georgian units', () {
    expect(NearbyPlacesService.formatDistance(420), '420 მ');
    expect(NearbyPlacesService.formatDistance(2500), '2.5 კმ');
  });
}
