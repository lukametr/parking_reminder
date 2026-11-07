import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_category.dart';
import '../services/nearby_places_service.dart';
import '../utils/location_disclosure_gate.dart';

enum _Status {
  locating,
  loading,
  ready,
  empty,
  error,
  disclosureDeclined,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
}

class NearbyPlacesScreen extends StatefulWidget {
  final NearbyCategory category;

  const NearbyPlacesScreen({super.key, required this.category});

  @override
  State<NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<NearbyPlacesScreen> {
  static const LatLng _georgia = LatLng(42.3154, 43.3569);

  final MapController _map = MapController();
  final NearbyPlacesService _service = NearbyPlacesService();
  final ScrollController _cards = ScrollController();

  _Status _status = _Status.locating;
  LatLng? _me;
  List<NearbyPlace> _places = const [];
  int _radius = 0;
  String? _selectedId;
  bool _mapReady = false;
  StreamSubscription<Position>? _positionSub;

  NearbyCategory get _c => widget.category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cards.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _status = _Status.locating);
    if (!await ensureLocationDisclosureAccepted(context)) {
      if (mounted) setState(() => _status = _Status.disclosureDeclined);
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _status = _Status.serviceDisabled);
      return;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (perm == LocationPermission.deniedForever) {
      setState(() => _status = _Status.permissionDeniedForever);
      return;
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) {
      setState(() => _status = _Status.permissionDenied);
      return;
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (!mounted) return;
    if (pos == null) {
      setState(() => _status = _Status.error);
      return;
    }
    _me = LatLng(pos.latitude, pos.longitude);
    _moveTo(_me!, 15);
    _watchPosition();
    await _search();
  }

  void _watchPosition() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((Position p) {
      if (mounted) setState(() => _me = LatLng(p.latitude, p.longitude));
    }, onError: (_) {});
  }

  Future<void> _search() async {
    final LatLng? me = _me;
    if (me == null) return;
    setState(() {
      _status = _Status.loading;
      _selectedId = null;
    });
    try {
      final result = await _service.search(
        category: _c,
        lat: me.latitude,
        lng: me.longitude,
      );
      if (!mounted) return;
      setState(() {
        _places = result.places;
        _radius = result.radiusMeters;
        _status = result.places.isEmpty ? _Status.empty : _Status.ready;
      });
      _fitResults();
    } catch (_) {
      if (mounted) setState(() => _status = _Status.error);
    }
  }

  void _moveTo(LatLng p, double zoom) {
    if (_mapReady) _map.move(p, zoom);
  }

  void _fitResults() {
    final LatLng? me = _me;
    if (!_mapReady || me == null || _places.isEmpty) return;
    final List<LatLng> pts = [me, ..._places.take(8).map((p) => LatLng(p.lat, p.lng))];
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.fromLTRB(48, 110, 48, 200),
        maxZoom: 16.5,
      ),
    );
  }

  void _recenter() {
    final LatLng? me = _me;
    if (me == null) {
      _start();
      return;
    }
    _moveTo(me, 16);
  }

  void _select(NearbyPlace place, {bool openSheet = true}) {
    setState(() => _selectedId = place.id);
    _moveTo(LatLng(place.lat, place.lng), 16.5);
    final int index = _places.indexOf(place);
    if (index >= 0 && _cards.hasClients) {
      _cards.animateTo(
        index * 252.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (openSheet) _showDetails(place);
  }

  Future<void> _navigate(NearbyPlace place) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${place.lat},${place.lng}&travelmode=driving',
    );
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ნავიგაციის გახსნა ვერ მოხერხდა')),
      );
    }
  }

  Future<void> _call(String phone) async {
    final String cleaned = phone.split(RegExp(r'[;,]')).first.replaceAll(RegExp(r'[^0-9+]'), '');
    await launchUrl(Uri(scheme: 'tel', path: cleaned));
  }

  void _showDetails(NearbyPlace place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _c.color,
                      child: Icon(_c.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${place.kind} · ${NearbyPlacesService.formatDistance(place.distanceMeters)}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow(Icons.place_outlined, place.address ?? 'მისამართი არ არის მითითებული'),
                if (place.openingHours != null)
                  _detailRow(Icons.schedule, place.openingHours!),
                if (place.phone != null)
                  InkWell(
                    onTap: () => _call(place.phone!),
                    child: _detailRow(Icons.phone, place.phone!, link: true),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _navigate(place);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text(
                      'ნავიგაცია',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String text, {bool link = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: link ? Colors.blue.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: Text(_c.screenTitle, style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'განახლება',
            icon: const Icon(Icons.refresh),
            onPressed: _status == _Status.loading || _status == _Status.locating
                ? null
                : (_me == null ? _start : _search),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          Positioned(top: 12, left: 12, right: 12, child: Center(child: _buildStatusChip())),
          if (_blockingMessage() != null) _buildMessageCard(),
          Positioned(
            right: 16,
            bottom: _status == _Status.ready ? 150 : 24,
            child: FloatingActionButton(
              heroTag: 'recenter',
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              tooltip: 'ჩემი მდებარეობა',
              onPressed: _recenter,
              child: const Icon(Icons.my_location),
            ),
          ),
          if (_status == _Status.ready)
            Positioned(left: 0, right: 0, bottom: 16, child: _buildCards()),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final List<Marker> markers = [
      for (final NearbyPlace p in _places)
        if (p.id != _selectedId) _placeMarker(p, selected: false),
      for (final NearbyPlace p in _places)
        if (p.id == _selectedId) _placeMarker(p, selected: true),
      if (_me != null)
        Marker(
          point: _me!,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
          ),
        ),
    ];
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _me ?? _georgia,
        initialZoom: _me == null ? 7 : 15,
        minZoom: 5,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _mapReady = true;
          if (_places.isNotEmpty) {
            _fitResults();
          } else if (_me != null) {
            _moveTo(_me!, 15);
          }
        },
        onTap: (_, __) => setState(() => _selectedId = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.lukacode.sosapp',
          maxNativeZoom: 19,
        ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Marker _placeMarker(NearbyPlace p, {required bool selected}) {
    final double size = selected ? 52 : 40;
    return Marker(
      key: ValueKey<String>(p.id),
      point: LatLng(p.lat, p.lng),
      width: size,
      height: size,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _select(p),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(Icons.location_on, size: size, color: selected ? Colors.red : _c.color,
                shadows: const [Shadow(color: Colors.black38, blurRadius: 4)]),
            Padding(
              padding: EdgeInsets.only(top: size * 0.17),
              child: Icon(_c.icon, size: size * 0.32, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    String? text;
    bool spinner = false;
    switch (_status) {
      case _Status.locating:
        text = 'მდებარეობის განსაზღვრა...';
        spinner = true;
      case _Status.loading:
        text = 'ვეძებთ ახლომდებარე ობიექტებს...';
        spinner = true;
      case _Status.ready:
        text = '${_places.length} ობიექტი · ${NearbyPlacesService.formatDistance(_radius.toDouble())} რადიუსში';
      default:
        text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
              ),
              const SizedBox(width: 10),
            ] else ...[
              Icon(_c.icon, size: 18, color: _c.color),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, String title, String body, String action, VoidCallback onAction})?
      _blockingMessage() {
    switch (_status) {
      case _Status.empty:
        return (
          icon: Icons.search_off,
          title: 'ახლოს ვერაფერი მოიძებნა',
          body: '${NearbyPlacesService.formatDistance(_radius.toDouble())} რადიუსში '
              '${_c.singular} ვერ ვიპოვეთ.',
          action: 'თავიდან ცდა',
          onAction: _search,
        );
      case _Status.error:
        return (
          icon: Icons.cloud_off,
          title: 'ჩატვირთვა ვერ მოხერხდა',
          body: 'შეამოწმეთ ინტერნეტ კავშირი და სცადეთ თავიდან.',
          action: 'თავიდან ცდა',
          onAction: _me == null ? _start : _search,
        );
      case _Status.disclosureDeclined:
        return (
          icon: Icons.location_off,
          title: 'ლოკაციაზე თანხმობა საჭიროა',
          body: 'ახლომდებარე ობიექტების საჩვენებლად საჭიროა თქვენი მდებარეობა.',
          action: 'თანხმობა',
          onAction: _start,
        );
      case _Status.permissionDenied:
        return (
          icon: Icons.location_off,
          title: 'ლოკაციის ნებართვა არ არის',
          body: 'ახლომდებარე ობიექტების საჩვენებლად დაუშვით ლოკაციაზე წვდომა.',
          action: 'ნებართვის მიცემა',
          onAction: _start,
        );
      case _Status.permissionDeniedForever:
        return (
          icon: Icons.location_off,
          title: 'ლოკაციის ნებართვა გამორთულია',
          body: 'ჩართეთ ლოკაციის ნებართვა აპის პარამეტრებში.',
          action: 'პარამეტრები',
          onAction: () async {
            await Geolocator.openAppSettings();
          },
        );
      case _Status.serviceDisabled:
        return (
          icon: Icons.gps_off,
          title: 'GPS გამორთულია',
          body: 'ჩართეთ მდებარეობის სერვისი და სცადეთ თავიდან.',
          action: 'GPS-ის ჩართვა',
          onAction: () async {
            await Geolocator.openLocationSettings();
            if (mounted) _start();
          },
        );
      default:
        return null;
    }
  }

  Widget _buildMessageCard() {
    final msg = _blockingMessage()!;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(msg.icon, size: 44, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              msg.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(msg.body, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: msg.onAction,
              child: Text(msg.action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCards() {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        controller: _cards,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _places.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int i) {
          final NearbyPlace p = _places[i];
          final bool selected = p.id == _selectedId;
          return SizedBox(
            width: 240,
            child: Material(
              color: Colors.white,
              elevation: selected ? 6 : 3,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _select(p),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? Colors.red : Colors.transparent, width: 2),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_c.icon, size: 18, color: _c.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.address ?? p.kind,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            NearbyPlacesService.formatDistance(p.distanceMeters),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 32,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => _navigate(p),
                              icon: const Icon(Icons.directions, size: 18),
                              label: const Text('ნავიგაცია'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
