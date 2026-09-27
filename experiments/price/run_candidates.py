#!/usr/bin/env python3
"""Phase E — model kandidat (§27 Phase E, §10) dengan split & metrik yang
sama persis seperti Phase D (cv() di run_baselines — satu jalur evaluasi):

  C1 RandomForestRegressor   default + seed
  C2 XGBRegressor            default + seed (early stopping = Phase F)
  C3 CatBoostRegressor       default + seed, verbose off

Keluaran: experiments/price/runs/<ts>/candidates_metrics.json + cv_results.csv
Determinism: run 2×, metrik (tanpa timing) wajib identik.

Usage: .venv-ml/bin/python experiments/price/run_candidates.py
"""

from __future__ import annotations

import csv
import json
import pathlib
import sys
import time
from datetime import datetime, timezone

import numpy as np
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import price_io  # noqa: E402
import run_baselines as rb  # noqa: E402

RAW = ROOT / "data" / "raw" / "price"
SEED = 42


def candidate_models(num: list[str], cat: list[str]) -> dict:
    from catboost import CatBoostRegressor
    from sklearn.compose import ColumnTransformer
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.impute import SimpleImputer
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import OneHotEncoder, StandardScaler
    from xgboost import XGBRegressor

    def prepared(X):
        """imputer median (num) + imputer+one-hot (cat) — sama seperti B1."""
        return ColumnTransformer([
            ("num", SimpleImputer(strategy="median"), num),
            ("cat", Pipeline([
                ("imp", SimpleImputer(strategy="most_frequent")),
                ("oh", OneHotEncoder(handle_unknown="ignore")),
            ]), cat),
        ], sparse_threshold=0.3).fit(X)

    def fit_rf(X, y, g):
        prep = prepared(X)
        m = RandomForestRegressor(n_estimators=200, random_state=SEED, n_jobs=-1)
        m.fit(prep.transform(X), y)
        return lambda Xte, gte: m.predict(prep.transform(Xte))

    def fit_xgb(X, y, g):
        prep = ColumnTransformer([
            ("num", Pipeline([
                ("imp", SimpleImputer(strategy="median")),
                ("sc", StandardScaler()),
            ]), num),
            ("cat", Pipeline([
                ("imp", SimpleImputer(strategy="most_frequent")),
                ("oh", OneHotEncoder(handle_unknown="ignore")),
            ]), cat),
        ], sparse_threshold=0.3).fit(X)
        m = XGBRegressor(n_estimators=200, random_state=SEED, n_jobs=-1,
                         tree_method="hist")
        m.fit(prep.transform(X), y)
        return lambda Xte, gte: m.predict(prep.transform(Xte))

    def fit_cb(X, y, g):
        # CatBoost memakai kolom kategori asli (tanpa one-hot)
        Xt = X.copy()
        for c in cat:
            Xt[c] = Xt[c].astype("object").fillna("__missing__").astype(str)
        for c in num:
            Xt[c] = pd.to_numeric(Xt[c], errors="coerce")
        m = CatBoostRegressor(iterations=500, random_seed=SEED, verbose=False,
                              allow_writing_files=False, cat_features=list(cat))
        m.fit(Xt, y)

        def predict(Xte, gte):
            Z = Xte.copy()
            for c in cat:
                Z[c] = Z[c].astype("object").fillna("__missing__").astype(str)
            for c in num:
                Z[c] = pd.to_numeric(Z[c], errors="coerce")
            return m.predict(Z)
        return predict

    return {"C1_random_forest": fit_rf, "C2_xgboost": fit_xgb,
            "C3_catboost": fit_cb}


def local_features(df: pd.DataFrame) -> list[str]:
    feats = ["district", "lat", "lng", "size_sqm", "room_type", "gender_policy",
             "amenities_count", "nearest_campus_km", "deposit"]
    for slug in ("ac", "wifi", "kamar-mandi-dalam", "parkir-motor"):
        df[slug] = df["facility_slugs"].apply(
            lambda s_, s=slug: int(isinstance(s_, list) and s in s_))
        feats.append(slug)
    return feats


def run_once() -> tuple[list[dict], dict]:
    rows: list[dict] = []
    summary: dict[str, dict] = {}
    variants = (("", None, None), ("_log1p", np.log1p, np.expm1))

    air = price_io.load_airroi_clean(RAW / "public" / "airroi_apac")
    num_a = [c for c in price_io.ALLOWED_FEATURES
             if pd.api.types.is_numeric_dtype(air[c])]
    cat_a = [c for c in price_io.ALLOWED_FEATURES if c not in num_a]
    meta_air = {"n_rows": len(air), "target": "ttm_avg_rate (USD/malam)",
                "group": "city", "models": ["C1", "C2", "C3"]}
    for suffix, tr, inv in variants:
        label = f"airroi_benchmark_usd{suffix}"
        r, s = rb.cv(air, target="target_usd", features=price_io.ALLOWED_FEATURES,
                     groups_col="group_city", label=label,
                     models=candidate_models(num_a, cat_a),
                     train_transform=tr, inverse_transform=inv)
        rows += r
        summary[label] = s

    local = price_io.load_kostara_train(RAW)
    feats = local_features(local)
    num_l = [c for c in feats if pd.api.types.is_numeric_dtype(local[c])]
    cat_l = [c for c in feats if c not in num_l]
    meta_loc = {"n_rows": len(local), "target": "monthly_price (IDR/bulan)",
                "group": "property_id", "models": ["C1", "C2", "C3"]}
    for suffix, tr, inv in variants:
        label = f"kostara_local_idr{suffix}"
        r, s = rb.cv(local, target="target_idr", features=feats,
                     groups_col="group_property", label=label,
                     models=candidate_models(num_l, cat_l),
                     train_transform=tr, inverse_transform=inv)
        rows += r
        summary[label] = s

    summary["meta"] = {"airroi": meta_air, "kostara": meta_loc}
    return rows, summary


def strip_timing(rows: list[dict], summary: dict) -> tuple[list[dict], dict]:
    r = [{k: v for k, v in row.items() if k != "fit_predict_ms"} for row in rows]
    s = json.loads(json.dumps(summary))
    for ds in s.values():
        if not isinstance(ds, dict):
            continue
        for v in ds.values():
            if isinstance(v, dict):
                v.pop("fit_predict_ms_mean", None)
    return r, s


def near(x, y, tol: float = 1e-6) -> bool:
    """Perbandingan determinism rekursif dengan toleransi float.

    RandomForest n_jobs>1 mengakumulasi prediksi antar-thread → noise float
    ~1e-13 pada prediksi (terverifikasi: maxdiff 2.3e-13, XGB/CB exact EQUAL).
    Toleransi 1e-6 relatif terhadap skala nilai menangkap perbedaan model
    nyata tanpa gagal karena noise akumulasi floating point; struktur/teks
    (label, nama model, kunci) tetap dibandingkan eksak.
    """
    if isinstance(x, dict) and isinstance(y, dict):
        return x.keys() == y.keys() and all(near(x[k], y[k]) for k in x)
    if isinstance(x, list) and isinstance(y, list):
        return len(x) == len(y) and all(near(i, j) for i, j in zip(x, y))
    if isinstance(x, float) and isinstance(y, float):
        return abs(x - y) <= tol * max(1.0, abs(x), abs(y))
    return x == y


def main() -> None:
    t0 = time.perf_counter()
    rows, summary = run_once()
    rows2, summary2 = run_once()
    a, sa = strip_timing(rows, summary)
    b, sb = strip_timing(rows2, summary2)
    if not near(a, b) or not near(sa, sb):
        print("DETERMINISM FAIL — run kedua berbeda")
        for i, (x, y) in enumerate(zip(a, b)):
            if not near([x], [y]):
                diff = {k: (x[k], y[k]) for k in x if not near(x[k], y.get(k))}
                print(f"  row[{i}] differs: {diff}")
        for label in sa:
            if not near([sa.get(label)], [sb.get(label)]):
                print(f"  summary[{label}] run1={sa.get(label)}")
                print(f"  summary[{label}] run2={sb.get(label)}")
        sys.exit(1)
    print(f"DETERMINISM OK (2 run identik) · wall {time.perf_counter() - t0:.1f}s")
    for ds, models in summary.items():
        if ds == "meta":
            continue
        for m, v in models.items():
            print(f"  {ds} · {m}: MAE {v['cv_mae_mean']}±{v['cv_mae_std']} "
                  f"RMSE {v['cv_rmse_mean']}±{v['cv_rmse_std']} R2={v['cv_r2_mean']} "
                  f"ms={v['fit_predict_ms_mean']}")
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = ROOT / "experiments" / "price" / "runs" / ts
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "candidates_metrics.json").write_text(json.dumps(
        {"created_at": ts, "seed": SEED, "summary": summary}, indent=2) + "\n")
    with (out_dir / "cv_results.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"metrics -> {out_dir.relative_to(ROOT)}/candidates_metrics.json")


if __name__ == "__main__":
    main()
