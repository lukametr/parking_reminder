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

## Version / Play

- Production line branch: `ios-codemagic` (not `main` — divergent history).
- Current release target: **1.1.14+20**, targetSdk **36**.
