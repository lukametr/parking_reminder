# Handoff

- **Done:** Imported 2201 Tbilisi lots from 2026-11-20 shapefile into Firestore `parkings` (was 2108); orphans deleted; import script under `tools/lots-import/`.
- **CI:** Pinned Flutter **3.47.9** in `.github/workflows/ci.yml` (3.50 + AGP 8.11.1 breaks `debug-apk` via `getDefaultConfig` / `evaluationDependsOn(":app")`).
- **Next:** Optional app release if cache/comment-only change needs shipping; devices refresh lots from Firestore on next fetch (≤15 min cache).
- **Report:** store `docs/lots-import-report.md`
