#!/usr/bin/env python3
"""Convert Tbilisi parking shapefile ZIP → Firestore `parkings` docs and import.

App schema (Parking Reminder+ / com.lukacode.sosapp):
  collection: parkings
  doc id: lot code (ZONE_CODE), e.g. A387
  fields:
    lotNumber: string
    location: GeoPoint(lat, lng)

Geometry: polygons in WGS84 UTM 38N (EPSG:32638). We store the
area-weighted polygon centroid transformed to WGS84 (EPSG:4326).

Auth: uses Firebase CI refresh token (same as `firebase login:ci`) via
OAuth client embedded in firebase-tools, OR GOOGLE_APPLICATION_CREDENTIALS
service account JSON.

Usage:
  pip install pyshp pyproj
  export FIREBASE_TOKEN='1//...'   # or pass --token-file
  python3 convert_and_import.py \\
    --zip /path/to/PARKING_TB_20_11_2026.zip \\
    --project parkingreminder-6466d \\
    --out-dir ./out \\
    --apply
"""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

try:
    import shapefile
    from pyproj import Transformer
except ImportError as e:  # pragma: no cover
    raise SystemExit("Install deps: pip install pyshp pyproj") from e

FIREBASE_OAUTH_CLIENT_ID = (
    "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
)
FIREBASE_OAUTH_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"
BATCH = 400


def centroid_utm(shape) -> tuple[float, float]:
    parts = list(shape.parts) + [len(shape.points)]
    pts = [(p[0], p[1]) for p in shape.points]
    rings = []
    for j in range(len(parts) - 1):
        ring = pts[parts[j] : parts[j + 1]]
        if len(ring) >= 3:
            rings.append(ring)
    if not rings:
        rings = [pts]
    total_a = 0.0
    wcx = 0.0
    wcy = 0.0
    for ring in rings:
        r = ring[:-1] if ring and ring[0] == ring[-1] else ring
        n = len(r)
        if n < 1:
            continue
        a = 0.0
        cx = 0.0
        cy = 0.0
        for k in range(n):
            x0, y0 = r[k]
            x1, y1 = r[(k + 1) % n]
            cross = x0 * y1 - x1 * y0
            a += cross
            cx += (x0 + x1) * cross
            cy += (y0 + y1) * cross
        a *= 0.5
        if abs(a) < 1e-9:
            cx = sum(p[0] for p in r) / n
            cy = sum(p[1] for p in r) / n
            aa = 1e-12
        else:
            cx = cx / (6 * a)
            cy = cy / (6 * a)
            aa = abs(a)
        total_a += aa
        wcx += cx * aa
        wcy += cy * aa
    return wcx / total_a, wcy / total_a


def convert_shapefile(shp_path: Path) -> list[dict]:
    sf = shapefile.Reader(str(shp_path))
    field_names = [f[0] for f in sf.fields[1:]]
    xform = Transformer.from_crs("EPSG:32638", "EPSG:4326", always_xy=True)
    lots: list[dict] = []
    for rec, sh in zip(sf.records(), sf.shapes()):
        d = dict(zip(field_names, rec))
        code = str(d.get("ZONE_CODE") or "").strip()
        if not code:
            raise SystemExit(f"Missing ZONE_CODE in record: {d}")
        ux, uy = centroid_utm(sh)
        lng, lat = xform.transform(ux, uy)
        lots.append(
            {
                "id": code,
                "lotNumber": code,
                "location": {"latitude": float(lat), "longitude": float(lng)},
            }
        )
    return lots


def unzip_find_shp(zip_path: Path, extract_dir: Path) -> Path:
    extract_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(extract_dir)
    shp = next(extract_dir.rglob("*.shp"), None)
    if shp is None:
        raise SystemExit(f"No .shp in {zip_path}")
    return shp


def write_outputs(lots: list[dict], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    cache = [
        {
            "id": x["id"],
            "lotNumber": x["lotNumber"],
            "lat": x["location"]["latitude"],
            "lng": x["location"]["longitude"],
        }
        for x in lots
    ]
    (out_dir / "parkings_firestore.json").write_text(
        json.dumps(lots, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (out_dir / "parkings_firestore.ndjson").write_text(
        "\n".join(json.dumps(x, ensure_ascii=False) for x in lots) + "\n",
        encoding="utf-8",
    )
    (out_dir / "parkings_cache.json").write_text(
        json.dumps(cache, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


class FirestoreClient:
    def __init__(self, project: str, refresh_token: str):
        self.project = project
        self.refresh_token = refresh_token
        self.access = self._refresh()
        self.base = (
            f"https://firestore.googleapis.com/v1/projects/{project}"
            f"/databases/(default)/documents"
        )
        self.commit_url = self.base + ":commit"
        self.agg_url = (
            f"https://firestore.googleapis.com/v1/projects/{project}"
            f"/databases/(default)/documents:runAggregationQuery"
        )

    def _refresh(self) -> str:
        data = urllib.parse.urlencode(
            {
                "client_id": FIREBASE_OAUTH_CLIENT_ID,
                "client_secret": FIREBASE_OAUTH_CLIENT_SECRET,
                "grant_type": "refresh_token",
                "refresh_token": self.refresh_token,
            }
        ).encode()
        req = urllib.request.Request(
            "https://oauth2.googleapis.com/token", data=data, method="POST"
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)["access_token"]

    def api(self, method: str, url: str, body=None, retries: int = 6):
        for attempt in range(retries):
            headers = {"Authorization": f"Bearer {self.access}"}
            data = None
            if body is not None:
                data = json.dumps(body).encode()
                headers["Content-Type"] = "application/json"
            req = urllib.request.Request(
                url, data=data, method=method, headers=headers
            )
            try:
                with urllib.request.urlopen(req, timeout=120) as r:
                    raw = r.read()
                    return r.status, json.loads(raw) if raw else {}
            except urllib.error.HTTPError as e:
                err = e.read().decode()
                if e.code in (401, 403) and attempt < retries - 1:
                    self.access = self._refresh()
                    continue
                if e.code in (429, 500, 503) and attempt < retries - 1:
                    time.sleep(2**attempt)
                    continue
                raise RuntimeError(f"{method} {url} -> {e.code} {err[:800]}") from e

    def upsert_lots(self, lots: list[dict]) -> None:
        for i in range(0, len(lots), BATCH):
            chunk = lots[i : i + BATCH]
            writes = []
            for lot in chunk:
                doc_name = (
                    f"projects/{self.project}/databases/(default)"
                    f"/documents/parkings/{lot['id']}"
                )
                writes.append(
                    {
                        "update": {
                            "name": doc_name,
                            "fields": {
                                "lotNumber": {
                                    "stringValue": str(lot["lotNumber"])
                                },
                                "location": {
                                    "geoPointValue": {
                                        "latitude": float(
                                            lot["location"]["latitude"]
                                        ),
                                        "longitude": float(
                                            lot["location"]["longitude"]
                                        ),
                                    }
                                },
                            },
                        }
                    }
                )
            self.api("POST", self.commit_url, {"writes": writes})
            print(f"upserted {min(i + BATCH, len(lots))}/{len(lots)}")

    def list_ids(self) -> list[str]:
        ids: list[str] = []
        token = None
        while True:
            url = self.base + "/parkings?pageSize=300&mask.fieldPaths=__name__"
            if token:
                url += "&pageToken=" + urllib.parse.quote(token)
            _, data = self.api("GET", url)
            for doc in data.get("documents", []):
                ids.append(doc["name"].split("/")[-1])
            token = data.get("nextPageToken")
            if not token:
                break
        return ids

    def delete_ids(self, ids: list[str]) -> None:
        for i in range(0, len(ids), BATCH):
            chunk = ids[i : i + BATCH]
            writes = [
                {
                    "delete": (
                        f"projects/{self.project}/databases/(default)"
                        f"/documents/parkings/{oid}"
                    )
                }
                for oid in chunk
            ]
            self.api("POST", self.commit_url, {"writes": writes})
            print(f"deleted {min(i + BATCH, len(ids))}/{len(ids)}")

    def count(self) -> int:
        _, data = self.api(
            "POST",
            self.agg_url,
            {
                "structuredAggregationQuery": {
                    "structuredQuery": {
                        "from": [{"collectionId": "parkings"}]
                    },
                    "aggregations": [{"alias": "count", "count": {}}],
                }
            },
        )
        # JSON array
        if isinstance(data, list):
            return int(data[0]["result"]["aggregateFields"]["count"]["integerValue"])
        return int(data["result"]["aggregateFields"]["count"]["integerValue"])


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--zip", required=True, type=Path)
    p.add_argument("--project", default="parkingreminder-6466d")
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--token-file", type=Path, default=None)
    p.add_argument("--token", default=None)
    p.add_argument(
        "--apply",
        action="store_true",
        help="Upsert to Firestore and delete orphans not in the new set",
    )
    args = p.parse_args()

    extract = args.out_dir / "_shp"
    shp = unzip_find_shp(args.zip, extract)
    lots = convert_shapefile(shp)
    write_outputs(lots, args.out_dir)
    print(f"converted {len(lots)} lots → {args.out_dir}")

    if not args.apply:
        print("Dry run only (pass --apply to write Firestore).")
        return

    token = args.token
    if not token and args.token_file:
        token = args.token_file.read_text(encoding="utf-8").strip()
    if not token:
        import os

        token = os.environ.get("FIREBASE_TOKEN")
    if not token:
        raise SystemExit("Need --token / --token-file / FIREBASE_TOKEN")

    client = FirestoreClient(args.project, token)
    before = client.count()
    print(f"firestore before: {before}")
    client.upsert_lots(lots)
    new_ids = {x["id"] for x in lots}
    orphans = [i for i in client.list_ids() if i not in new_ids]
    print(f"orphans: {len(orphans)}")
    if orphans:
        client.delete_ids(orphans)
    after = client.count()
    print(f"firestore after: {after} (expected {len(lots)})")
    if after != len(lots):
        raise SystemExit("Count mismatch after import")


if __name__ == "__main__":
    main()
