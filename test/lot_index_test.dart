import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/models/parking_lot.dart';
import 'package:parking_reminder/utils/lot_index.dart';

void main() {
  test('nearby returns lots within radius, sorted', () {
    const ParkingLot a = ParkingLot(
      id: '1',
      lotNumber: 'A001',
      latitude: 41.7151,
      longitude: 44.7833,
    );
    const ParkingLot far = ParkingLot(
      id: '2',
      lotNumber: 'A999',
      latitude: 41.80,
      longitude: 44.90,
    );
    final LotIndex index = LotIndex(<ParkingLot>[a, far]);
    final List<ParkingLot> hit = index.nearby(41.71512, 44.78332, radiusMeters: 20);
    expect(hit.map((e) => e.lotNumber), <String>['A001']);
  });

  test('haversine is ~0 for identical points', () {
    expect(LotIndex.haversineMeters(41.7, 44.8, 41.7, 44.8), 0);
  });

  test('nearestWithin is only the closest lot inside 8 m', () {
    const ParkingLot a = ParkingLot(
      id: '1',
      lotNumber: 'NEAR',
      latitude: 41.71510,
      longitude: 44.78330,
    );
    const ParkingLot b = ParkingLot(
      id: '2',
      lotNumber: 'FARTHER',
      latitude: 41.71518,
      longitude: 44.78330,
    );
    final LotIndex index = LotIndex(<ParkingLot>[a, b]);
    final ParkingLot? hit = index.nearestWithin(41.71510, 44.78330);
    expect(hit?.lotNumber, 'NEAR');
    expect(index.nearestWithin(41.71600, 44.78330), isNull);
  });
}
