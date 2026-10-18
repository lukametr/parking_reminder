# Play Console paste pack (`com.lukacode.sosapp` / Parking Reminder +)

## App content → Privacy policy

Paste exactly:

https://parkingreminder-6466d.web.app/privacy/

## Store listing

**App name:** Parking Reminder +

**Privacy policy URL:** https://parkingreminder-6466d.web.app/privacy/

**Short description:** თბილისის ზონალური პარკირება — ლოტი, ოფიციალური აპი, SOS.

**Full description:** (same as before — per-minute, MSDA start/stop, SOS, no countdown)

## Data safety (App content → Data safety)

| Question | Answer |
| --- | --- |
| Collects user data? | Yes |
| Precise location | Yes, **on-device**, required for core feature. **Collected in background: yes** |
| Approximate location | No |
| Account / name / email | No |
| Crash logs | Yes — Firebase Crashlytics, app functionality |
| Device or other IDs | Yes — Advertising ID (AdMob), advertising |
| Encrypted in transit | Yes |
| Users can request deletion | Location not uploaded; they can uninstall / revoke permission |
| Sold | No |
| Ads | Yes (AdMob banner + interstitial). Location **not** used for ads by us |

## Background location declaration (App content → Sensitive permissions)

**Text:** This app detects when a Tbilisi driver has stopped on a paid zonal parking lot so they can start or stop payment in the official MSDA app (`ge.msda.parking`). That requires precise location while the app is not on screen (foreground service + always-allow). Location is processed on-device; no GPS track is uploaded. Users see an in-app Georgian disclosure (continue/decline) **before** the system permission. They can decline and still use SOS. Persistent notification while monitoring.

**Video:** Open app → full-screen disclosure → Continue → Allow location → Allow all the time → minimize → stop on lot → reminder → leave lot → turn-off reminder. Show privacy icon opening the policy URL.

## Maps restriction (GCP)

Android app package **`com.lukacode.sosapp`** + upload SHA-1 `AC:FF:5F:5F:3A:48:8A:47:FD:68:B0:C6:29:10:B6:43:B3:CF:8E:4C`.
