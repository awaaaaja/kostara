#!/usr/bin/env python3
"""Loader dataset Price Intelligence (satu-satunya tempat aturan cleaning).

Kontrak: file di data/raw TIDAK pernah diubah; aturan di sini identik
dengan validate_airroi.py / validate_dataset.py — jumlah baris diassert
agar selisih aturan gagal keras, bukan diam-diam.
"""

from __future__ import annotations

import pandas as pd

CANONICAL_ROOM_TYPES = {"entire_home", "private_room", "hotel_room", "shared_room"}
# jumlah baris hasil cleaning gate QUALITY PASS (dq_report_airroi.json)
AIRROI_CLEAN_ROWS = 29_057
KOSTARA_TRAIN_ROWS = 40

ALLOWED_FEATURES = [
    "room_type", "latitude", "longitude", "guests", "bedrooms", "beds", "baths",
    "min_nights", "cleaning_fee", "extra_guest_fee", "amenities_count",
    "city", "country",
]
NUMERIC_FEATURES = [
    "latitude", "longitude", "guests", "bedrooms", "beds", "baths",
    "min_nights", "cleaning_fee", "extra_guest_fee", "amenities_count",
]
CATEGORICAL_FEATURES = ["room_type", "city", "country"]


def load_airroi_clean(base) -> pd.DataFrame:
    L = pd.read_parquet(base / "listings.parquet")
    room = L["room_type"].fillna("")
    numeric_id = pd.to_numeric(L["listing_id"], errors="coerce").notna()
    mask = room.str.contains("http") | ~(
        room.isin(CANONICAL_ROOM_TYPES) | (room == "")
    ) | ~numeric_id
    Lc = L[~mask].drop_duplicates("listing_id", keep="first").copy()
    assert len(Lc) == AIRROI_CLEAN_ROWS, f"cleaning drift: {len(Lc)} != {AIRROI_CLEAN_ROWS}"
    Lc["amenities_count"] = Lc["amenities"].fillna("").apply(
        lambda s: 0 if not s else len(s.split(","))
    )
    for c in NUMERIC_FEATURES:
        Lc[c] = pd.to_numeric(Lc[c], errors="coerce")
    Lc["target_usd"] = pd.to_numeric(Lc["ttm_avg_rate"], errors="coerce")
    Lc = Lc[Lc["target_usd"].notna()].reset_index(drop=True)
    Lc["group_city"] = Lc["city"].astype(str)
    return Lc


def load_kostara_train(raw_dir) -> pd.DataFrame:
    """Training view KOSTARA: observasi terakhir per kamar (40 baris)."""
    obs = pd.read_parquet(raw_dir / "room_price_observations.parquet")
    rooms = pd.read_parquet(raw_dir / "rooms.parquet")
    obs["observed_at"] = pd.to_datetime(obs["observed_at"], utc=True)
    latest = obs.sort_values("observed_at").drop_duplicates("room_id", keep="last")
    snap = pd.DataFrame(
        [s if isinstance(s, dict) else {} for s in latest["feature_snapshot"]],
        index=latest.index,
    )
    df = latest.join(snap, rsuffix="_snap")
    assert len(df) == KOSTARA_TRAIN_ROWS, f"{len(df)} != {KOSTARA_TRAIN_ROWS}"
    df["target_idr"] = df["monthly_price"].astype(float)
    df["group_property"] = df["property_id"].astype(str)
    df["room_type"] = df["room_type"].astype(str)
    df["district"] = df["district"].astype(str)
    df["city"] = "Padang"
    df["country"] = "Indonesia"
    df["amenities_count"] = df["facility_slugs"].apply(
        lambda x: len(x) if isinstance(x, (list, dict)) else 0
    )
    for c in ("lat", "lng", "size_sqm", "deposit", "nearest_campus_km"):
        df[c] = pd.to_numeric(df.get(c), errors="coerce")
    return df.reset_index(drop=True)
