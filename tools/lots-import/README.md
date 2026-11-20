# Tbilisi lots import (`parkings`)

Converts the city shapefile ZIP into the Firestore schema used by
**Parking Reminder+** (`com.lukacode.sosapp`, project `parkingreminder-6466d`).

## Schema

| Firestore | Source |
| --- | --- |
| document id | `ZONE_CODE` (exact, e.g. `A387`) |
| `lotNumber` (string) | `ZONE_CODE` |
| `location` (GeoPoint) | polygon centroid → WGS84 |

Geometry in the ZIP is **polygon** in **EPSG:32638** (WGS84 UTM 38N). Matching
in the app is nearest lot within **8 m**, so centroids must stay accurate.

The app does **not** ship a bundled lots asset; native `parkings_cache.json` is
filled at runtime from Firestore. This folder also emits a cache-shaped JSON for
offline/testing.

## Convert only

```bash
pip install pyshp pyproj
python3 convert_and_import.py \
  --zip /path/to/PARKING_TB_20_11_2026.zip \
  --out-dir ./out
```

Outputs: `parkings_firestore.json`, `parkings_firestore.ndjson`, `parkings_cache.json`.

## Apply to Firestore

Requires a Firebase CI token (`firebase login:ci`) with write access to the
project. Client SDK rules deny writes; Admin/OAuth is required.

```bash
export FIREBASE_TOKEN='1//...'
python3 convert_and_import.py \
  --zip /path/to/PARKING_TB_20_11_2026.zip \
  --out-dir ./out \
  --project parkingreminder-6466d \
  --apply
```

Safe replace: upsert all new docs, then delete document IDs that are no longer
in the shapefile.
