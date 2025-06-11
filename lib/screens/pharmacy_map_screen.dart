import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PharmacyMapScreen extends StatefulWidget {
  const PharmacyMapScreen({super.key});

  @override
  State<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends State<PharmacyMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Position? _currentPosition;
  bool _isLoading = true;
  Set<Polyline> _polylines = {};
  Marker? _selectedMarker;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Current location: ${position.latitude}, ${position.longitude}');
      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _errorMessage = null;
      });
      _searchNearbyPharmacies();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'ვერ მოხერხდა მდებარეობის მიღება: $e';
      });
    }
  }

  Future<void> _searchNearbyPharmacies() async {
    if (_currentPosition == null || _mapController == null) {
      print('Cannot search: currentPosition or mapController is null');
      return;
    }

    try {
      final url = 'https://places.googleapis.com/v1/places:searchNearby';
      
      print('Searching pharmacies with URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': 'AIzaSyDm_j_wiq5Y45WT8X-JvJ007PiQ7Emk0Pw',
          'X-Goog-FieldMask': 'places.displayName,places.location,places.formattedAddress',
        },
        body: json.encode({
          'locationBias': {
            'circle': {
              'center': {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude
              },
              'radius': 5000.0
            }
          },
          'includedTypes': ['pharmacy'],
          'languageCode': 'ka',
          'maxResultCount': 20
        }),
      );
      
      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List;
        print('Found ${places.length} pharmacies');

        setState(() {
          _markers = places.map((place) {
            final location = place['location'];
            final lat = location['latitude'] as double;
            final lng = location['longitude'] as double;
            final name = place['displayName']['text'] as String;
            final address = place['formattedAddress'] as String?;
            final placeId = place['id'] as String;

            print('Adding marker for pharmacy: $name at $lat, $lng');

            return Marker(
              markerId: MarkerId(placeId),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: name,
                snippet: address,
                onTap: () {
                  print('Marker tapped: $name');
                  _showRouteOptions(LatLng(lat, lng), name);
                },
              ),
              onTap: () {
                print('Marker tapped: $name');
                setState(() {
                  _selectedMarker = Marker(
                    markerId: MarkerId(placeId),
                    position: LatLng(lat, lng),
                    infoWindow: InfoWindow(
                      title: name,
                      snippet: address,
                      onTap: () {
                        print('Info window tapped: $name');
                        _showRouteOptions(LatLng(lat, lng), name);
                      },
                    ),
                  );
                });
              },
            );
          }).toSet();
        });
      } else {
        print('HTTP Error: ${response.statusCode}');
        setState(() {
          _errorMessage = 'ვერ მოხერხდა აფთიაქების მოძიება: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Error searching pharmacies: $e');
      setState(() {
        _errorMessage = 'ვერ მოხერხდა აფთიაქების მოძიება: $e';
      });
    }
  }

  Future<void> _showRouteOptions(LatLng destination, String pharmacyName) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pharmacyName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _getDirections(destination, 'driving'),
                child: const Text('ავტომობილით'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _getDirections(destination, 'walking'),
                child: const Text('ფეხით'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getDirections(LatLng destination, String mode) async {
    if (_currentPosition == null) return;

    try {
      final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$mode'
        '&key=AIzaSyDm_j_wiq5Y45WT8X-JvJ007PiQ7Emk0Pw'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final points = _decodePolyline(routes[0]['overview_polyline']['points']);
            setState(() {
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: points,
                  color: Colors.blue,
                  width: 5,
                ),
              };
            });
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(
                _getBounds(points),
                50,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (var point in points) {
      if (minLat == null || point.latitude < minLat) minLat = point.latitude;
      if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
      if (minLng == null || point.longitude < minLng) minLng = point.longitude;
      if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentPosition == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'ვერ მოხერხდა მდებარეობის მიღება'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _getCurrentLocation,
                child: const Text('ხელახლა ცდა'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ახლომდებარე აფთიაქები'),
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              print('Map created');
              _mapController = controller;
              _searchNearbyPharmacies();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: (LatLng position) {
              print('Map tapped at: ${position.latitude}, ${position.longitude}');
            },
          ),
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[100],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 