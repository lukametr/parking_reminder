import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release bumped to 1.1.15+21 for lock-screen alert', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('version: 1.1.15+21'), isTrue);
  });

  test('native wake alert channel id stays unique (importance/sound upgrade)', () {
    final String notifier = File(
      'android/app/src/main/kotlin/com/lukacode/sosapp/location/ParkingNotifier.kt',
    ).readAsStringSync();
    expect(notifier.contains('parking_alerts_wake_v21'), isTrue);
    expect(notifier.contains('IMPORTANCE_HIGH'), isTrue);
    expect(notifier.contains('notification_beep'), isTrue);
    expect(notifier.contains('setFullScreenIntent'), isTrue);
    expect(notifier.contains('CATEGORY_ALARM'), isTrue);
    expect(notifier.contains('PARTIAL_WAKE_LOCK'), isTrue);
    // Must not only depend on Flutter overlay when screen is off.
    expect(notifier.contains('shouldUseFullScreenIntent'), isTrue);
  });

  test('beep asset packaged under res/raw', () {
    expect(
      File('android/app/src/main/res/raw/notification_beep.mp3').existsSync(),
      isTrue,
    );
  });

  test('manifest keeps FSI + notification + FGS location + battery opt', () {
    final String manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('POST_NOTIFICATIONS'), isTrue);
    expect(manifest.contains('USE_FULL_SCREEN_INTENT'), isTrue);
    expect(manifest.contains('FOREGROUND_SERVICE_LOCATION'), isTrue);
    expect(manifest.contains('REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'), isTrue);
    expect(
      manifest.contains('android:foregroundServiceType="location"'),
      isTrue,
    );
  });
}
