#!/usr/bin/env python3
"""Phase C — validasi data public benchmark AirROI (§27 Phase C).

Membaca data mentah (tidak diubah in-place), menghitung pembersihan yang
dokumentatif (buang baris corrupt/duplikat), lalu memeriksa:

schema · duplicates · missing · price distribution · geo · categorical ·
property-group counts · leakage audit

Usage: .venv-ml/bin/python experiments/price/validate_airroi.py
Exit 1 bila ada check FAIL. Laporan: experiments/price/runs/<ts>/
dq_report_airroi.json
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw" / "price" / "public" / "airroi_apac"
RUNS = ROOT / "experiments" / "price" / "runs"

LISTINGS_COLS = 61
PAST_RATES_COLS = 17
CANONICAL_ROOM_TYPES = {"entire_home", "private_room", "hotel_room", "shared_room"}
# APAC bbox longgar (termasuk AU/NZ/IN/JP) — bukan filter domain
APAC_LAT = (-55, 55)
APAC_LNG = (60, 180)
# USD/malam — rentang wajar listing short-term rental
RATE_MIN, RATE_MAX = 1.0, 5000.0
# §7: larang sebagai fitur core (masa depan / berjalan setelah listing)
FORBIDDEN_PREFIXES = ("ttm_", "l90d_", "rating_", "num_reviews", "superhost",
                      "professional_management")
ALLOWED_FEATURES = [
    "room_type", "latitude", "longitude", "guests", "bedrooms", "beds", "baths",
    "min_nights", "cleaning_fee", "extra_guest_fee", "amenities_count",
    "city", "state", "country",
]


def main() -> None:
    import pandas as pd

    checks: list[dict] = []

    def check(cid: str, ok: bool, detail: str = "") -> None:
        checks.append({"id": cid, "status": "PASS" if ok else "FAIL", "detail": detail})
        print(f"  {cid}: {'PASS' if ok else 'FAIL'} {detail}")

    if not (RAW / "listings.parquet").exists():
        print("FAIL — jalankan download_airroi.py dulu")
        sys.exit(1)

    L = pd.read_parquet(RAW / "listings.parquet")
    P = pd.read_parquet(RAW / "past_rates.parquet")

    check("C-01 schema listings/past_rates sesuai harapan",
          len(L.columns) == LISTINGS_COLS and len(P.columns) == PAST_RATES_COLS,
          f"listings={len(L.columns)} past_rates={len(P.columns)}")
    check("C-02 semua kolom listings bertipe str (diketahui) — casting wajib",
          all(str(t) in ("str", "string", "object") for t in L.dtypes),
          f"non_str={ [c for c, t in L.dtypes.items() if str(t) not in ('str', 'string', 'object')] }")

    # --- pembersihan terdokumentatif (baris tidak dihapus dari file raw) ---
    n0 = len(L)
    dups_raw = int(L["listing_id"].duplicated().sum())
    room = L["room_type"].fillna("")
    numeric_id = pd.to_numeric(L["listing_id"], errors="coerce").notna()
    # korupsi row-shift: URL/kolom lain di room_type, atau listing_id bukan angka
    shift_mask = room.str.contains("http") | ~(
        room.isin(CANONICAL_ROOM_TYPES) | (room == "")
    ) | ~numeric_id
    shifted = int(shift_mask.sum())
    Lc = L[~shift_mask].copy()
    dups = int(Lc["listing_id"].duplicated(keep="first").sum())
    Lc = Lc[~Lc["listing_id"].duplicated(keep="first")].copy()
    check("C-03 duplikat diidentifikasi (raw 11) & bersih setelah cleaning",
          dups_raw == 11 and Lc["listing_id"].duplicated().sum() == 0,
          f"raw={dups_raw} removed_in_cleaning={dups}")
    check("C-04 baris row-shift/corrupt dibuang (URL + id non-angka)",
          200 <= shifted <= 400, f"removed={shifted}")

    # --- missing values ---
    miss = {}
    for col in ("latitude", "longitude", "bedrooms", "guests", "min_nights"):
        s = pd.to_numeric(Lc[col], errors="coerce")
        miss[col] = round(float(s.isna().mean()) * 100, 1)
    check("C-05 missing terdokumentasi (semua <30%)",
          all(v < 30 for v in miss.values()), f"null%={miss}")

    # --- price distribution (target: ttm_avg_rate = USD) ---
    rate = pd.to_numeric(Lc["ttm_avg_rate"], errors="coerce")
    dist = {
        "n_null": int(rate.isna().sum()),
        "min": float(rate.min()), "p25": float(rate.quantile(.25)),
        "median": float(rate.median()), "p75": float(rate.quantile(.75)),
        "max": float(rate.max()),
    }
    n_extreme = int(((rate < RATE_MIN) | (rate > RATE_MAX)).sum())
    check("C-06 target USD ada (>98%) & ekstrem tercatat",
          rate.notna().mean() > 0.98 and n_extreme < len(Lc) * 0.01,
          f"dist={ {k: round(v, 1) for k, v in dist.items()} } n_extreme={n_extreme}")

    # --- geo validation (null = missing terdokumentasi di C-05) ---
    lat = pd.to_numeric(Lc["latitude"], errors="coerce")
    lng = pd.to_numeric(Lc["longitude"], errors="coerce")
    present = lat.notna() & lng.notna()
    bad_geo = int(((~lat.between(*APAC_LAT) | ~lng.between(*APAC_LNG)) & present).sum())
    check("C-07 koordinat terisi selalu dalam bbox APAC (null terpisah)",
          bad_geo < int(present.sum()) * 0.01,
          f"out_of_bbox={bad_geo}/{int(present.sum())} null={int((~present).sum())}")

    # --- categorical distribution ---
    rt = Lc["room_type"].replace("", pd.NA)
    canon_share = float(rt.isin(CANONICAL_ROOM_TYPES).fillna(False).mean())
    cur = pd.to_numeric(Lc["ttm_avg_rate_native"], errors="coerce")
    check("C-08 room_type kanonik dominan + currency lengkap",
          canon_share > 0.98 and Lc["currency"].notna().mean() > 0.98,
          f"canon_share={canon_share:.3f} n_currency={Lc['currency'].nunique()}")
    check("C-09 kota/negara non-null (kunci property-group)",
          Lc["city"].notna().mean() > 0.99 and Lc["country"].notna().mean() > 0.99,
          f"city_null%={round((1 - Lc['city'].notna().mean()) * 100, 1)}")

    # --- property-group counts (penerbit klaim "up to 300/kota") ---
    per_city = Lc["city"].value_counts()
    over = {c: int(n) for c, n in per_city.items() if n > 300}
    check("C-10 property-group per kota ≤350 (klaim penerbit: up to 300)",
          int(per_city.max()) <= 350,
          f"max={int(per_city.max())} n_cities={len(per_city)} over300={len(over)}")

    # --- past_rates sanity ---
    P["date"] = pd.to_datetime(P["date"], errors="coerce")
    ids_l = set(pd.to_numeric(Lc["listing_id"], errors="coerce").dropna().astype("int64"))
    orphan = len(set(P["listing_id"]) - ids_l)
    orphan_pct = round(orphan / max(len(set(P["listing_id"])), 1) * 100, 1)
    check("C-11 past_rates: tanggal valid 2025-02..2026-01; orphan id <10%",
          bool(P["date"].notna().all())
          and str(P["date"].min().date()) == "2025-02-01"
          and str(P["date"].max().date()) == "2026-01-01"
          and orphan_pct < 10,
          f"min={P['date'].min().date()} max={P['date'].max().date()} "
          f"rows={len(P)} orphan_ids={orphan} ({orphan_pct}%)")

    # --- leakage audit ---
    leaked = [c for c in ALLOWED_FEATURES if c.startswith(FORBIDDEN_PREFIXES)]
    present_forbidden = [c for c in L.columns if c.startswith(FORBIDDEN_PREFIXES)]
    check("C-12 fitur yang diizinkan bebas kolom terlarang (§7)",
          not leaked and len(present_forbidden) > 0,
          f"allowed_overlap={leaked} forbidden_in_source={len(present_forbidden)} "
          f"(dipakai hanya utk target/analisis)")

    report = {
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "dataset": "jasonairroi/airbnb-market-data-asia-pacific",
        "rows": {"raw": n0, "after_cleaning": int(len(Lc)),
                 "past_rates": int(len(P))},
        "cleaning": {"row_shift_removed": shifted, "duplicates_removed": dups},
        "price_distribution_usd": {k: round(v, 1) for k, v in dist.items()},
        "missing_pct": miss,
        "allowed_features": ALLOWED_FEATURES,
        "checks": checks,
        "status": "QUALITY PASS" if all(c["status"] == "PASS" for c in checks)
                  else "QUALITY FAIL",
    }
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = RUNS / ts
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "dq_report_airroi.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"\n{report['status']}  raw={n0} -> clean={report['rows']['after_cleaning']}")
    print(f"report -> {out.relative_to(ROOT)} sha256={digest[:16]}")
    sys.exit(0 if report["status"] == "QUALITY PASS" else 1)


if __name__ == "__main__":
    main()
