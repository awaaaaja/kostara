#!/usr/bin/env python3
"""Export dataset mentah Price Intelligence dari Supabase (service key dari
Aman.md — tidak di repo) ke data/raw/price/*.parquet + metadata sumber.

Raw rows di-git-ignored; tidak ada PII (owner_id / nama file dihapus).

Usage: python3 experiments/price/export_dataset.py
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import run_sql  # noqa: E402

SERVICE = run_sql.field("SERVICE_ROLE")
SUPA = f"https://{run_sql.REF}.supabase.co"
RAW = ROOT / "data" / "raw" / "price"

TABLES = {
    "properties": "properties",
    "rooms": "rooms",
    "property_facilities": "property_facilities",
    "facilities": "facilities",
    "campuses": "campuses",
    "districts": "districts",
    "room_price_observations": "room_price_observations",
}
# kolom identitas/PII yang tidak masuk training (data governance §4)
DROP = {"properties": ["owner_id", "description", "rules"]}
PAGE = 1000  # max-rows server default — paginate


def fetch(path: str) -> list[dict]:
    rows: list[dict] = []
    offset = 0
    while True:
        req = urllib.request.Request(
            f"{SUPA}/rest/v1/{path}?select=*&limit={PAGE}&offset={offset}",
            headers={"apikey": SERVICE, "Authorization": f"Bearer {SERVICE}"},
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            chunk = json.load(resp)
        rows += chunk
        if len(chunk) < PAGE:
            return rows
        offset += PAGE


def main() -> None:
    import pandas as pd

    RAW.mkdir(parents=True, exist_ok=True)
    digests = []
    row_counts = {}
    for name, path in TABLES.items():
        df = pd.DataFrame(fetch(path))
        for col in DROP.get(name, []):
            if col in df.columns:
                df = df.drop(columns=[col])
        # geometry: ekspor sebagai teks WKT tidak dibutuhkan — buang kolom
        # geom/location yang bertipe geography (fitur koordinat sudah ada di
        # feature_snapshot; district sudah jadi kolom nama)
        df = df.drop(columns=[c for c in ("geom", "location") if c in df.columns])
        out = RAW / f"{name}.parquet"
        df.to_parquet(out, index=False)
        digests.append(hashlib.sha256(out.read_bytes()).hexdigest())
        row_counts[name] = int(len(df))
        print(f"  {name}: {len(df)} rows -> {out.relative_to(ROOT)}")
    version = hashlib.sha256("".join(sorted(digests)).encode()).hexdigest()[:16]
    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True
    ).stdout.strip()
    meta = {
        "dataset_version": f"kostara-padang-v1-{version}",
        "source": f"supabase:{run_sql.REF} (dev)",
        "tables": row_counts,
        "file_sha256": dict(
            sorted(
                (f"{name}.parquet", digests[i]) for i, name in enumerate(TABLES)
            )
        ),
        "git_commit": commit or "unknown",
        "schema_version": "price-raw-v1",
    }
    (RAW / "metadata.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(f"dataset_version = {meta['dataset_version']}")


if __name__ == "__main__":
    main()
