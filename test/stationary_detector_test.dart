import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/utils/stationary_detector.dart';

void main() {
  test('not stationary until settle elapsed', () {
    final StationaryDetector d = StationaryDetector(
      settle: const Duration(seconds: 10),
    );
    final DateTime t0 = DateTime.utc(2026, 1, 1);
    expect(
      d.isStationary(
        latitude: 41.7,
        longitude: 44.8,
        accuracyMeters: 8,
        speedMps: 0.1,
        now: t0,
      ),
      isFalse,
    );
    expect(
      d.isStationary(
        latitude: 41.70001,
        longitude: 44.80001,
        accuracyMeters: 8,
        speedMps: 0.1,
        now: t0.add(const Duration(seconds: 11)),
      ),
      isTrue,
    );
  });

  test('speed resets stillness', () {
    final StationaryDetector d = StationaryDetector(
      settle: const Duration(seconds: 5),
    );
    final DateTime t0 = DateTime.utc(2026, 1, 1);
    d.isStationary(
      latitude: 41.7,
      longitude: 44.8,
      accuracyMeters: 8,
      speedMps: 0,
      now: t0,
    );
    expect(
      d.isStationary(
        latitude: 41.7,
        longitude: 44.8,
        accuracyMeters: 8,
        speedMps: 8,
        now: t0.add(const Duration(seconds: 6)),
      ),
      isFalse,
    );
  });
}
