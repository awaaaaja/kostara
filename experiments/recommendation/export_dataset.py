#!/usr/bin/env python3
"""Export dataset mentah dari Supabase (service key dari Aman.md — tidak di repo)
ke data/raw/*.parquet. Output row-level di-git-ignored (CP-02 A2).

Usage: python3 experiments/recommendation/export_dataset.py
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import run_sql  # noqa: E402

SERVICE = run_sql.field("SERVICE_ROLE")
SUPA = f"https://{run_sql.REF}.supabase.co"
RAW = ROOT / "data" / "raw"

TABLES = {
    "events": "interactions",
    "properties": "properties",
    "rooms": "rooms",
    "property_facilities": "property_facilities",
    "facilities": "facilities",
    "campuses": "campuses",
    "reviews": "reviews",
    "owner_profiles": "owner_profiles",
    "user_preferences": "user_preferences",
}
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
    for name, path in TABLES.items():
        rows = fetch(path)
        df = pd.DataFrame(rows)
        out = RAW / f"{name}.parquet"
        df.to_parquet(out, index=False)
        digests.append(hashlib.sha256(out.read_bytes()).hexdigest())
        print(f"  {name}: {len(df)} rows -> {out.relative_to(ROOT)}")
    version = hashlib.sha256("".join(sorted(digests)).encode()).hexdigest()[:16]
    (RAW / "DATASET_VERSION.txt").write_text(version + "\n")
    print(f"dataset_version = {version}")


if __name__ == "__main__":
    main()
