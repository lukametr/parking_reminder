# Handoff

## Current goal

Release **1.1.15 (vc21)**: lock-screen / screen-off parking stay alert + short beep.

## Done

- Native `ParkingNotifier`: new high-importance channel `parking_alerts_wake_v21` + `notification_beep.mp3`.
- Full-screen intent when screen off, keyguard locked, or app not foreground; WakeLock on notify.
- Checks: POST_NOTIFICATIONS, `canUseFullScreenIntent` (API 34+), battery optimization (one-time prompt).
- Unlocked Flutter overlay + decline/accept + 10s dwell + 8 m nearest: unchanged.
- Version **1.1.15+21**; signed AAB + mapping in project store `docs/releases/`.
- Unit tests 20/20 including `lock_alert_release_test.dart`.

## Next

- Browser worker: upload AAB + mapping to Play (do **not** upload from this agent).
- Merge PR into `ios-codemagic` when reviewed.
- Field verify: lock phone, dwell 10s on lot → heads-up/FSI + beep without unlocking first.

## Files touched

- `android/.../location/ParkingNotifier.kt`, `MainActivity.kt`, `AndroidManifest.xml`
- `lib/services/parking_monitor.dart`, `lib/screens/splash_screen.dart`
- `android/app/build.gradle.kts`, `pubspec.yaml`
- `test/lock_alert_release_test.dart`, `docs/*`
