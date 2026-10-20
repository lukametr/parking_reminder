import 'dart:math' as math;

import '../models/parking_lot.dart';

/// ~50 m cells. 2108 Tbilisi lots fit in memory; avoids O(n) scans on every fix.
class LotIndex {
  LotIndex(this.lots, {this.cellDegrees = 0.00045}) {
    for (final ParkingLot lot in lots) {
      _cells
          .putIfAbsent(_cellKey(lot.latitude, lot.longitude), () => <ParkingLot>[])
          .add(lot);
    }
  }

  final List<ParkingLot> lots;
  final double cellDegrees;
  final Map<String, List<ParkingLot>> _cells = <String, List<ParkingLot>>{};

  String _cellKey(double lat, double lng) {
    final int i = (lat / cellDegrees).floor();
    final int j = (lng / cellDegrees).floor();
    return '$i:$j';
  }

  List<ParkingLot> nearby(double lat, double lng, {double radiusMeters = 8}) {
    final List<ParkingLot> out = <ParkingLot>[];
    final int i0 = (lat / cellDegrees).floor();
    final int j0 = (lng / cellDegrees).floor();
    final double cellMeters = cellDegrees * 111000;
    final int ring = math.max(1, (radiusMeters / cellMeters).ceil() + 1);
    for (int di = -ring; di <= ring; di++) {
      for (int dj = -ring; dj <= ring; dj++) {
        final List<ParkingLot>? cell = _cells['${i0 + di}:${j0 + dj}'];
        if (cell == null) continue;
        for (final ParkingLot lot in cell) {
          if (haversineMeters(lat, lng, lot.latitude, lot.longitude) <=
              radiusMeters) {
            out.add(lot);
          }
        }
      }
    }
    out.sort(
      (a, b) => haversineMeters(lat, lng, a.latitude, a.longitude).compareTo(
        haversineMeters(lat, lng, b.latitude, b.longitude),
      ),
    );
    return out;
  }

  /// Single closest lot if it is inside [radiusMeters]; otherwise null.
  ParkingLot? nearestWithin(double lat, double lng, {double radiusMeters = 8}) {
    final List<ParkingLot> hits = nearby(lat, lng, radiusMeters: radiusMeters);
    return hits.isEmpty ? null : hits.first;
  }

  static double haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double r = 6371000;
    final double p1 = lat1 * 0.017453292519943295;
    final double p2 = lat2 * 0.017453292519943295;
    final double dLat = (lat2 - lat1) * 0.017453292519943295;
    final double dLng = (lng2 - lng1) * 0.017453292519943295;
    final double sinLat = math.sin(dLat / 2);
    final double sinLng = math.sin(dLng / 2);
    final double a =
        sinLat * sinLat + math.cos(p1) * math.cos(p2) * sinLng * sinLng;
    final double c = 2 * math.asin(math.sqrt(a > 1 ? 1 : a));
    return r * c;
  }
}
