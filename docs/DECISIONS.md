# Decisions

- Lots source of truth: Firestore `parkings` on `parkingreminder-6466d`.
- Lot id / `lotNumber` = city `ZONE_CODE` (exact string).
- Geometry: polygon centroid from city shapefile (UTM 38N → WGS84).
- Full replace on authoritative city updates; delete orphan doc IDs.
- Keep Firestore fields minimal: `lotNumber` + `location` only (app schema).
- 2026-11-20 import from `PARKING_TB_20_11_2026.zip` → 2201 lots.
