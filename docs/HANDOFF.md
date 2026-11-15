# Handoff

<<<<<<< HEAD
- **Done:** Imported 2201 Tbilisi lots from 2026-11-20 shapefile into Firestore `parkings` (was 2108); orphans deleted; import script under `tools/lots-import/`.
- **Next:** Optional app release if cache/comment-only change needs shipping; devices refresh lots from Firestore on next fetch (≤15 min cache).
- **Report:** store `docs/lots-import-report.md`
=======
## Current goal

Release **1.1.14 (vc20)**: banner-only ads + 10s parking dwell.

## Done

- Removed interstitial load/show on სერვისები open; banner unit → `…/5359269234`.
- Native `LotPromptPolicy.DWELL_MS` and Dart `StationaryDetector.settle` default: **5s → 10s**.
- 10s purpose (LM): traffic jam / crawl / brief stop ≠ parking; only a real ~10s stop.
- AD_ID permission kept/added; targetSdk 36; version **1.1.14+20**.
- Unit tests updated for 10s dwell / pass-by.
- Walkthrough (ka): store `docs/app-how-it-works.md`.

## Next

- Browser worker: upload AAB + mapping to Play (no API path in this agent).
- Merge PR into `ios-codemagic` when reviewed.
- CI pinned to Flutter **3.47.9** (3.50 + AGP 8.11.1 breaks `debug-apk`).

## Files touched

- `lib/config/ad_config.dart`, `lib/screens/splash_screen.dart`
- `lib/utils/stationary_detector.dart`, `lib/utils/lot_prompt_policy.dart`
- `android/.../LotPromptPolicy.kt`, `AndroidManifest.xml`, `build.gradle.kts`
- `pubspec.yaml`, `test/stationary_detector_test.dart`, `docs/*`
>>>>>>> 9dc9993 (ci: pin Flutter 3.47.9 for AGP 8.11.1 debug builds)
