# Handoff

## Current goal

Release **1.1.16 (vc22)**: leave/exit reminder distance **200 m** (was ≈80 m).

## Done

- `ParkingMonitorService.EXIT_BUFFER_METERS`: **80.0 → 200.0**.
- `ParkingSessionTracker.exitBufferMeters`: **80 → 200**.
- Version **1.1.16+22**; other logic unchanged (10s dwell, 5–8 m match, lock-screen FSI/beep).
- Store + repo docs updated for 200 m leave distance.

## Next

- Browser worker: upload AAB + mapping to Play only when LM asks (this agent does **not** Play-upload).
- Merge PR into `ios-codemagic` when reviewed.
- Field verify: accept stay → drive ~200 m away → leave reminder.

## Files touched

- `android/.../location/ParkingMonitorService.kt`
- `lib/services/parking_session_tracker.dart`
- `pubspec.yaml`, `test/lock_alert_release_test.dart`
- `docs/DECISIONS.md`, `docs/HANDOFF.md`, `docs/PROJECT_MAP.md`
