# Project map — Parking Reminder+

- **Package:** `com.lukacode.sosapp`
- **Firebase:** `parkingreminder-6466d`
- **Stack:** Flutter + native Android FGS (`ParkingMonitorService`)
- **Lots:** Firestore `parkings` (`lotNumber` + `location` GeoPoint); device cache `parkings_cache.json`
- **Match:** nearest lot ≤ 8 m after ~10 s dwell
- **Import tooling:** `tools/lots-import/`
- **Branch of record:** `play-store-modernize` (Play releases)
