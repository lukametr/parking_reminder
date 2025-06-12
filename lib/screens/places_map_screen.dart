import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PlacesMapScreen extends StatefulWidget {
  final String title;
  final String placeType;
  final String keyword;
  final IconData icon;

  const PlacesMapScreen({
    Key? key,
    required this.title,
    required this.placeType,
    required this.keyword,
    required this.icon,
  }) : super(key: key);

  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Marker? _selectedMarker;
  Set<Polyline> _polylines = {};
  Position? _currentPosition;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestPermission = await Geolocator.requestPermission();
        if (requestPermission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'ლოკაციის ნებართვა არ არის მიცემული';
            _isLoading = false;
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _searchNearbyPlaces();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _errorMessage = 'ვერ მოხერხდა მიმდინარე მდებარეობის განსაზღვრა';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchNearbyPlaces() async {
    if (_currentPosition == null || _mapController == null) {
      print('Cannot search: currentPosition or mapController is null');
      return;
    }

    try {
      final url = 'https://places.googleapis.com/v1/places:searchNearby';
      
      print('Searching ${widget.placeType} with URL: $url');
      
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
          'includedTypes': [widget.placeType],
          'languageCode': 'ka',
          'maxResultCount': 20
        }),
      );
      
      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List;
        print('Found ${places.length} ${widget.placeType}');

        setState(() {
          _markers = places.map((place) {
            final location = place['location'];
            final lat = location['latitude'] as double;
            final lng = location['longitude'] as double;
            final name = place['displayName']['text'] as String;
            final address = place['formattedAddress'] as String?;
            final placeId = place['id'] as String;

            print('Adding marker for ${widget.placeType}: $name at $lat, $lng');

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
          _errorMessage = 'ვერ მოხერხდა ${widget.placeType}ის მოძიება: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        _errorMessage = 'ვერ მოხერხდა ${widget.placeType}ის მოძიება';
      });
    }
  }

  void _showRouteOptions(LatLng destination, String name) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _getDirections(destination, 'driving'),
                  icon: const Icon(Icons.directions_car),
                  label: const Text('ავტომობილით'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _getDirections(destination, 'walking'),
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('ფეხით'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getDirections(LatLng destination, String mode) async {
    if (_currentPosition == null) return;

    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=$mode'
          '&key=AIzaSyDm_j_wiq5Y45WT8X-JvJ007PiQ7Emk0Pw';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final route = data['routes'][0]['overview_polyline']['points'];
        final points = _decodePolyline(route);
        final polyline = Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
        );

        setState(() {
          _polylines = {polyline};
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBounds(points),
            50,
          ),
        );
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
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

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Text(_errorMessage!),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _searchNearbyPlaces();
            },
            markers: {..._markers, if (_selectedMarker != null) _selectedMarker!},
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: (_) {
              setState(() {
                _selectedMarker = null;
                _polylines = {};
              });
            },
          ),
          if (_markers.isEmpty)
            const Center(
              child: Text(
                'მახლობლად არაფერი ვერ მოიძებნა',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 