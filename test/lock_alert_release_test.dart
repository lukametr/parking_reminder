import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release bumped to 1.1.16+22 for 200m leave distance', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('version: 1.1.16+22'), isTrue);
    final String gradle =
        File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle.contains('versionCode = 22'), isTrue);
    expect(gradle.contains('versionName = "1.1.16"'), isTrue);
  });

  test('native leave buffer is 200 meters', () {
    final String src = File(
      'android/app/src/main/kotlin/com/lukacode/sosapp/location/ParkingMonitorService.kt',
    ).readAsStringSync();
    expect(src.contains('EXIT_BUFFER_METERS = 200.0'), isTrue);
    expect(src.contains('EXIT_BUFFER_METERS = 80.0'), isFalse);
  });

  test('dart session tracker leave buffer defaults to 200 meters', () {
    final String src =
        File('lib/services/parking_session_tracker.dart').readAsStringSync();
    expect(src.contains('exitBufferMeters = 200'), isTrue);
    expect(src.contains('exitBufferMeters = 80'), isFalse);
  });
}
