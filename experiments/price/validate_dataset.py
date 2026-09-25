#!/usr/bin/env python3
"""Data quality pipeline untuk dataset Price Intelligence (ML_PRICE_INTELLIGENCE §8).

Membaca data/raw/price/*.parquet (hasil export_dataset.py, tidak dimodifikasi
in-place) → laporan dq ke experiments/price/runs/<ts>/dq_report.json.

Usage: python3 experiments/price/validate_dataset.py
Exit 1 bila ada check FAIL.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw" / "price"
RUNS = ROOT / "experiments" / "price" / "runs"

# Pilot bbox Kota Padang (dokumentasikan — bukan koordinat negara lain)
PILOT_LAT = (-1.10, -0.55)
PILOT_LNG = (100.20, 100.75)
PRICE_MIN, PRICE_MAX = 100_000, 20_000_000  # rupiah/bulan, wajar Padang
ROOM_TYPES = {"shared", "studio", "single"}
GENDER = {"female_only", "male_only", "any"}


def load(name: str):
    import pandas as pd

    return pd.read_parquet(RAW / f"{name}.parquet")


def main() -> None:
    import pandas as pd

    checks: list[dict] = []

    def check(cid: str, ok: bool, detail: str = "") -> None:
        checks.append({"id": cid, "status": "PASS" if ok else "FAIL", "detail": detail})
        print(f"  {cid}: {'PASS' if ok else 'FAIL'} {detail}")

    required = [
        "properties", "rooms", "property_facilities", "facilities",
        "campuses", "districts", "room_price_observations",
    ]
    missing = [t for t in required if not (RAW / f"{t}.parquet").exists()]
    if missing:
        print(f"FAIL — file mentah hilang: {missing}; jalankan export_dataset.py dulu")
        sys.exit(1)

    props = load("properties")
    rooms = load("rooms")
    obs = load("room_price_observations")
    districts = load("districts")
    facilities = load("facilities")
    pf = load("property_facilities")

    # Training view: observasi terakhir per kamar (replay ≤1 baris/kamar)
    obs["observed_at"] = pd.to_datetime(obs["observed_at"], utc=True)
    latest = obs.sort_values("observed_at").drop_duplicates(
        "room_id", keep="last"
    ).copy()
    # snapshot fitur = kolom fitur training; property_id dari observasi
    feat = pd.DataFrame(
        latest["feature_snapshot"].apply(lambda s: s if isinstance(s, dict) else {}).tolist(),
        index=latest.index,
    )
    df = latest.join(feat, rsuffix="_snap")
    # konsistensi pasangan room×property antara observasi dan tabel rooms
    room_owner = rooms.set_index("id")["property_id"]
    pair_consistent = bool(
        (latest["property_id"].values
         == latest["room_id"].map(room_owner).values).all()
    )

    check("DQ-01 unique observation id",
          bool(obs["id"].is_unique) and int(obs["id"].isna().sum()) == 0,
          f"n={len(obs)} unique={obs['id'].nunique()}")
    check("DQ-02 room/property reference valid",
          pair_consistent
          and set(df["property_id"]) <= set(props["id"])
          and set(latest["room_id"]) <= set(rooms["id"]),
          f"pair_consistent={pair_consistent}")
    check("DQ-03 monthly_price > 0",
          bool((df["monthly_price"] > 0).all()),
          f"min={df['monthly_price'].min()} max={df['monthly_price'].max()}")
    lat, lng = df["lat"], df["lng"]
    check("DQ-04 koordinat valid + dalam pilot bbox",
          bool(lat.between(-90, 90).all() and lng.between(-180, 180).all()
                and lat.between(*PILOT_LAT).all() and lng.between(*PILOT_LNG).all()),
          f"lat[{lat.min():.4f},{lat.max():.4f}] lng[{lng.min():.4f},{lng.max():.4f}]")
    check("DQ-05 area kamar positif",
          bool((df["size_sqm"] > 0).all() and df["size_sqm"].notna().all()),
          f"min={df['size_sqm'].min()} null={int(df['size_sqm'].isna().sum())}")
    extreme = df[(df["monthly_price"] < PRICE_MIN) | (df["monthly_price"] > PRICE_MAX)]
    check("DQ-06 tidak ada harga ekstrem tak wajar",
          len(extreme) == 0, f"n_extreme={len(extreme)}")
    dup = df.duplicated(subset=["room_id"]).sum()
    check("DQ-07 tanpa duplikat kamar di training view", dup == 0, f"dup={dup}")
    check("DQ-08 observed_at tersedia",
          bool(latest["observed_at"].notna().all()),
          f"null={int(latest['observed_at'].isna().sum())}")
    pii_cols = [c for c in feat.columns
                if c.lower() in {"email", "phone", "name", "owner_name", "address_full"}]
    check("DQ-09 tidak ada kolom PII mentah di feature snapshot", not pii_cols,
          f"pii_cols={pii_cols}; feature_cols={sorted(feat.columns)}")
    canon_ok = (
        set(df["room_type"]) <= ROOM_TYPES
        and set(df["gender_policy"].dropna()) <= GENDER
        and set(df["district"].dropna()) <= set(districts["nama"])
        and set(pf["facility_id"]) <= set(facilities["id"])
    )
    check("DQ-10 kategori kanonik (room_type/gender/district/facility)",
          bool(canon_ok),
          f"room_type={sorted(set(df['room_type']))} district={sorted(set(df['district'].dropna()))}")
    nulls = {c: int(df[c].isna().sum()) for c in df.columns if df[c].isna().any()}
    # subdistrict & travel_time: gap terdokumentasi (V1) — bukan kegagalan
    undocumented = {k: v for k, v in nulls.items()
                    if k not in {"subdistrict", "travel_time_to_nearest_campus_min",
                                 "reject_reason", "last_availability_update_at"}}
    check("DQ-11 missing values terdokumentasi (kecuali gap V1)", not undocumented,
          f"nulls={nulls}")

    report = {
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "dataset_version": json.loads((RAW / "metadata.json").read_text())["dataset_version"],
        "rows_raw": {"observations": int(len(obs)), "rooms": int(len(rooms)),
                     "properties": int(len(props))},
        "rows_training_view": int(len(df)),
        "price_distribution": {
            "min": int(df["monthly_price"].min()),
            "median": int(df["monthly_price"].median()),
            "max": int(df["monthly_price"].max()),
            "mean": int(df["monthly_price"].mean()),
        },
        "property_group_counts": {str(k): int(v)
                                  for k, v in df["property_id"].value_counts().items()},
        "feature_columns": sorted(feat.columns),
        "checks": checks,
        "status": "QUALITY PASS" if all(c["status"] == "PASS" for c in checks) else "QUALITY FAIL",
    }
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = RUNS / ts
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "dq_report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"\n{report['status']}  rows={report['rows_training_view']} "
          f"price[median]={report['price_distribution']['median']}")
    print(f"report -> {out.relative_to(ROOT)} sha256={digest[:16]}")
    sys.exit(0 if report["status"] == "QUALITY PASS" else 1)


if __name__ == "__main__":
    main()
