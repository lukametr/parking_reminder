import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/services/parking_session_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('beginSession stores lot locally without a countdown', () async {
    final ParkingSessionTracker t = ParkingSessionTracker();
    await t.beginSession(
      lotNumber: 'A010',
      latitude: 41.7,
      longitude: 44.8,
    );
    expect(t.activeLot, 'A010');
    await t.endSession();
    expect(t.activeLot, isNull);
  });
}
