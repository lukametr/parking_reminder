import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/services/parking_session_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('beginSession stores lot locally without a countdown', () async {
    final ParkingSessionTracker t = ParkingSessionTracker(emitNotifications: false);
    await t.beginSession(
      lotNumber: 'A010',
      latitude: 41.7,
      longitude: 44.8,
    );
    expect(t.activeLot, 'A010');
    await t.endSession();
    expect(t.activeLot, isNull);
  });

  test('restore then leave past buffer ends session once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'currentParkingLot': 'B12',
      'currentParkingLat': 41.7,
      'currentParkingLng': 44.8,
    });
    String? left;
    final ParkingSessionTracker t = ParkingSessionTracker(
      emitNotifications: false,
      onLeftLot: (String lot) => left = lot,
    );
    await t.restore();
    expect(t.activeLot, 'B12');
    await t.processFix(latitude: 41.71, longitude: 44.81);
    expect(left, 'B12');
    expect(t.activeLot, isNull);

    await t.processFix(latitude: 41.72, longitude: 44.82);
    expect(left, 'B12');
  });

  test('staying within buffer does not end session', () async {
    final ParkingSessionTracker t = ParkingSessionTracker(emitNotifications: false);
    await t.beginSession(
      lotNumber: 'C01',
      latitude: 41.7,
      longitude: 44.8,
    );
    await t.processFix(latitude: 41.7003, longitude: 44.8003);
    expect(t.activeLot, 'C01');
  });
}
