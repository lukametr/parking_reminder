# Project map — Parking Reminder+

**What:** Tbilisi zonal parking helper — detect stop on paid lot, offer MSDA app, remind to stop billing after leave. Per-minute billing (no 55-min ticket timer).

**Package:** `com.lukacode.sosapp` · **Branch:** `ios-codemagic` · **Version:** 1.1.15+21

## Stack

- Flutter (Dart) UI + Firebase (Firestore parkings, Crashlytics, Remote Config)
- Android FGS: `ParkingMonitorService` + Activity Recognition + geofences
- AdMob: **banner only** (`google_mobile_ads`)

## Important paths

- `lib/screens/splash_screen.dart` — home, SOS, სერვისები, banner ad
- `lib/config/ad_config.dart` — banner unit IDs
- `lib/utils/stationary_detector.dart` — Dart dwell gate (default 10s)
- `lib/utils/lot_prompt_policy.dart` — decline cooldown / same-lot silence
- `android/.../location/ParkingMonitorService.kt` — native dwell + prompt
- `android/.../location/ParkingNotifier.kt` — lock-screen FSI + wake channel + beep
- `android/.../location/LotPromptPolicy.kt` — `DWELL_MS = 10_000`
- `android/.../location/LotIndex.kt` — nearest lot ≤ ~8 m
- `android/app/src/main/res/raw/notification_beep.mp3` — short alert tone

## Run / test / build

```bash
flutter test
flutter build appbundle --release
```

Signed release needs `android/key.properties` + upload keystore (gitignored).
