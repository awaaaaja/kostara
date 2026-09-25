#!/usr/bin/env python3
"""Unduh public benchmark AirROI Asia-Pacific via Kaggle CLI resmi (§17).

Kredensial: ~/.kaggle/kaggle.json atau KAGGLE_API_TOKEN — TIDAK di repo.
Raw files tidak diubah in-place. Output: data/raw/price/public/airroi_apac/

Usage: .venv-ml/bin/python experiments/price/download_airroi.py
Verifikasi ulang tanpa unduh:  .../download_airroi.py --verify
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEST = ROOT / "data" / "raw" / "price" / "public" / "airroi_apac"
SLUG = "jasonairroi/airbnb-market-data-asia-pacific"

# Checksum dataset per unduhan 2026-09-26 (versi Kaggle saat itu) —
# bila gagal, dataset upstream berubah: perbarui eksplisit + catat di card.
PINNED_SHA256 = {
    "listings.csv": "4f782c93fb98304037f1f495a344a97dd30cf5ec62a61eb657bc28cbf79f018c",
    "listings.parquet": "0fe2b5597430943c146f91908228e38e90452a30072e653e06f123ef4a957434",
    "past_rates.csv": "1f12f7c37e421274d56e0aa837523723a489a95700a7c4ce05317aede66eb02c",
    "past_rates.parquet": "f5527fdf61f6f597dff6a161669e033177b103f2082d1d25ff6d95edbe5f1c05",
}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def verify() -> int:
    ok = True
    for name, pinned in PINNED_SHA256.items():
        p = DEST / name
        if not p.exists():
            print(f"  MISSING {name}")
            ok = False
            continue
        got = sha256(p)
        match = got == pinned
        ok &= match
        print(f"  {'OK  ' if match else 'DIFF'} {name} {got[:16]}")
    return 0 if ok else 1


def main() -> None:
    if "--verify" in sys.argv:
        sys.exit(verify())
    DEST.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(
        [sys.executable, "-m", "kaggle", "datasets", "download",
         "-d", SLUG, "-p", str(DEST), "--unzip"],
        cwd=ROOT,
    )
    if r.returncode != 0:
        print("unduh gagal — cek kredensial ~/.kaggle/kaggle.json")
        sys.exit(r.returncode)
    rc = verify()
    files = sorted(p.name for p in DEST.iterdir() if p.is_file())
    print("file list:", files)
    meta = {
        "dataset": SLUG,
        "retrieved_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "files": files,
        "pinned_sha256": PINNED_SHA256,
        "download_verified": rc == 0,
        "source_note": "Kaggle public benchmark — hanya untuk pipeline dev/"
                       "benchmark, TIDAK pernah masuk training KOSTARA Padang",
    }
    (DEST / "source_metadata.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(f"metadata -> {DEST.relative_to(ROOT)}/source_metadata.json")
    sys.exit(rc)


if __name__ == "__main__":
    main()
