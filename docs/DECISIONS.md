# Decisions — Parking Reminder+

Package: `com.lukacode.sosapp` only (never TinDoger).

## Ads (2026-11-15)

- **Banner only:** `ca-app-pub-8872582533953072/5359269234` (Standard Banner `main-banner`).
- **Removed / disabled:** Interstitial (`…/1616568991`), App Open, Rewarded — no full-screen ad when opening სერვისები / Resources.
- Small banners at bottom/top of screens are OK.
- Keep `com.google.android.gms.permission.AD_ID`.
- App ID: `ca-app-pub-8872582533953072~4948596381`.

## Parking dwell (2026-11-15)

- Count as a parking stop only after **~10 seconds** stationary on a lot (was ≥5s).
- Purpose: traffic jams, slow crawling, and brief stops must **not** count as parking.
- Do **not** show stay/offer prompt when just driving/passing by.
- Nearest lot only, max **~5–8 m** (never widen to 15–40 m).
- Prompt UI on screen (overlay / FSI), not click-only notification.
- Decline → **10-minute** global suppress + no same-lot re-prompt until leave.
- Billed per minute; **no** 55-minute ticket reminder.
- After accept: show lot number + open MSDA (`ge.msda.parking`); remind to turn off after leaving.

## Leave / exit distance (2026-11-27)

- Leave-parking reminder when GPS is ≈ **200 m** from the parked point (was ≈80 m).
- Native: `ParkingMonitorService.EXIT_BUFFER_METERS = 200.0`.
- Dart mirror: `ParkingSessionTracker.exitBufferMeters = 200`.
- Unchanged: 10s dwell, 5–8 m nearest-lot match, decline cooldown, lock-screen FSI/beep.

## Lock-screen parking alert (2026-11-18)

- Field bug: stay/offer only appeared with screen **on**; screen **off/locked** → nothing.
- Root cause: prompt was effectively Flutter-overlay / heads-up dependent; heads-up needs an interactive screen, and FSI/sound were not strong enough for lock/doze.
- Fix: dedicated native channel `parking_alerts_wake_v21` at **IMPORTANCE_HIGH** with `res/raw/notification_beep.mp3`, `CATEGORY_ALARM`, `setFullScreenIntent` when screen off **or** keyguard locked **or** app backgrounded, short `PARTIAL_WAKE_LOCK`, Android 13+ notification + API 34 FSI checks, one-time battery-optimization prompt.
- Unlocked overlay + accept/decline + 10s dwell + 5–8 m nearest lot: **unchanged**.

## Version / Play

- Production line branch: `ios-codemagic` (not `main` — divergent history).
- Current release target: **1.1.16+22**, targetSdk **36**.
