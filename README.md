# პარკინგის შეხსენება

Android Flutter app for Tbilisi zonal parking lots (`com.findall.ParkingReminder`).

Lots are loaded from Firebase Firestore collection `parkings`. Monitoring uses a native **foreground location service** (Play Fused Location, Activity Recognition, nearby geofences) — not a 10-second Dart GPS poll.

## Run

```bash
# Maps/Places: put MAPS_API_KEY in android/local.properties (see android/maps.properties.example).
# Rotate the old public GitHub key before production.
flutter pub get
flutter test
flutter build apk --debug
```

`google-services.json` for this package is already in `android/app/` (project `parkingreminder-6466d`). Do not regenerate unless the Android app id changes.

## Play

See `docs/PLAY_SIGNING.md` and `privacy-policy.md`.
