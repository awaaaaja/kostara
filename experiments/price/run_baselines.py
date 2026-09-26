#!/usr/bin/env python3
"""Phase D — baseline harga (§27 Phase D, §10):

  B0 Geographic Median  median target per geo-group (train fold),
                        fallback median global  — KOSTARA: district,
                        AirROI: city (district tidak ada di benchmark)
  B1 Linear Regression  imputer + one-hot + LR, preprocessing per fold

Cross-validation: GroupKFold per property (KOSTARA) / city (AirROI —
deviasi terdokumentasi: 1 baris per listing membuat group property
degeneratif; city adalah unit geografis B0 juga).

Keluaran: experiments/price/runs/<ts>/baselines_metrics.json + cv_results.csv
Determinism: run 2×, metrik wajib identik.

Usage: .venv-ml/bin/python experiments/price/run_baselines.py
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
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import price_io  # noqa: E402

RAW = ROOT / "data" / "raw" / "price"
SEED = 42


class GeoMedian:
    """B0 — median per group (fit pada train fold), fallback global."""

    def __init__(self) -> None:
        self.by_group: dict[str, float] = {}
        self.global_median = 0.0

    def fit(self, y: np.ndarray, groups: np.ndarray) -> "GeoMedian":
        s = pd.DataFrame({"g": groups, "y": y})
        self.by_group = s.groupby("g")["y"].median().to_dict()
        self.global_median = float(np.median(y))
        return self

    def predict(self, groups: np.ndarray) -> np.ndarray:
        return np.array([self.by_group.get(g, self.global_median) for g in groups])


def lr_pipeline(num_cols: list[str], cat_cols: list[str]) -> Pipeline:
    return Pipeline([
        ("prep", ColumnTransformer([
            ("num", SimpleImputer(strategy="median"), num_cols),
            ("cat", Pipeline([
                ("imp", SimpleImputer(strategy="most_frequent")),
                ("oh", OneHotEncoder(handle_unknown="ignore")),
            ]), cat_cols),
        ])),
        ("lr", LinearRegression()),
    ])


def cv(df: pd.DataFrame, *, target: str, features: list[str], groups_col: str,
       label: str, n_splits: int = 5) -> tuple[list[dict], dict]:
    # numerik/kategorikal ditentukan dari dtype aktual (fitur berbeda per dataset)
    num = [c for c in features if pd.api.types.is_numeric_dtype(df[c])]
    cat = [c for c in features if c not in num]
    gkf = GroupKFold(n_splits=min(n_splits, df[groups_col].nunique()))
    y = df[target].to_numpy(float)
    X = df[features]
    groups = df[groups_col].to_numpy()
    rows, preds_t, preds_p = [], [], []
    for i, (tr, te) in enumerate(gkf.split(X, y, groups), 1):
        Xtr, Xte = X.iloc[tr], X.iloc[te]
        ytr, yte = y[tr], y[te]
        t0 = time.perf_counter()
        b0 = GeoMedian().fit(ytr, groups[tr])
        p0 = b0.predict(groups[te])
        t_b0 = (time.perf_counter() - t0) * 1000
        t0 = time.perf_counter()
        model = lr_pipeline(num, cat).fit(Xtr, ytr)
        p1 = model.predict(Xte)
        t_b1 = (time.perf_counter() - t0) * 1000
        for name, p, infer_ms in (("B0_geo_median", p0, t_b0),
                                  ("B1_linear_regression", p1, t_b1)):
            rows.append({
                "dataset": label, "model": name, "fold": i,
                "n_train": len(tr), "n_test": len(te),
                "mae": float(mean_absolute_error(yte, p)),
                "rmse": float(np.sqrt(mean_squared_error(yte, p))),
                "r2": float(r2_score(yte, p)) if len(set(yte)) > 1 else None,
                "fit_predict_ms": round(infer_ms, 3),
            })
        preds_t.append(yte); preds_p.append((p0, p1))
    summary: dict[str, dict] = {}
    for name in ("B0_geo_median", "B1_linear_regression"):
        m = [r for r in rows if r["model"] == name]
        summary[name] = {
            "cv_mae_mean": round(float(np.mean([r["mae"] for r in m])), 4),
            "cv_mae_std": round(float(np.std([r["mae"] for r in m])), 4),
            "cv_rmse_mean": round(float(np.mean([r["rmse"] for r in m])), 4),
            "cv_rmse_std": round(float(np.std([r["rmse"] for r in m])), 4),
            "cv_r2_mean": (round(float(np.mean([r["r2"] for r in m])), 4)
                           if m[0]["r2"] is not None else None),
            "fit_predict_ms_mean": round(float(np.mean(
                [r["fit_predict_ms"] for r in m])), 3),
        }
    return rows, summary


def run_once() -> tuple[list[dict], dict]:
    rows: list[dict] = []

    # --- AirROI benchmark (USD/malam) ---
    air = price_io.load_airroi_clean(RAW / "public" / "airroi_apac")
    r, s = cv(air, target="target_usd", features=price_io.ALLOWED_FEATURES,
              groups_col="group_city", label="airroi_benchmark_usd")
    rows += r
    meta_air = {"n_rows": len(air), "target": "ttm_avg_rate (USD/malam)",
                "group": "city", "features": price_io.ALLOWED_FEATURES}

    # --- KOSTARA local (IDR/bulan) ---
    local = price_io.load_kostara_train(RAW)
    feats = ["district", "lat", "lng", "size_sqm", "room_type", "gender_policy",
             "amenities_count", "nearest_campus_km", "deposit"]
    # tambahkan fasilitas biner
    for slug in ("ac", "wifi", "kamar-mandi-dalam", "parkir-motor"):
        local[slug] = local["facility_slugs"].apply(
            lambda s_, s=slug: int(isinstance(s_, list) and s in s_))
        feats.append(slug)
    r, s2 = cv(local, target="target_idr", features=feats,
               groups_col="group_property", label="kostara_local_idr")
    rows += r
    meta_loc = {"n_rows": len(local), "target": "monthly_price (IDR/bulan)",
                "group": "property_id", "features": feats}
    return rows, {"airroi_benchmark_usd": s, "kostara_local_idr": s2,
                  "meta": {"airroi": meta_air, "kostara": meta_loc}}


def strip_timing(rows: list[dict], summary: dict) -> tuple[list[dict], dict]:
    """Determinism check membandingkan metrik kualitas saja (ms = wall clock)."""
    r = [{k: v for k, v in row.items() if k != "fit_predict_ms"} for row in rows]
    s = json.loads(json.dumps(summary))
    for ds in s.values():
        if not isinstance(ds, dict):
            continue
        for v in ds.values():
            if isinstance(v, dict):
                v.pop("fit_predict_ms_mean", None)
    return r, s


def main() -> None:
    rows, summary = run_once()
    rows2, summary2 = run_once()
    a, sa = strip_timing(rows, summary)
    b, sb = strip_timing(rows2, summary2)
    if sa != sb or a != b:
        print("DETERMINISM FAIL — run kedua berbeda")
        sys.exit(1)
    print("DETERMINISM OK (2 run identik, metrik dikecualikan dari timing)")
    for ds, models in summary.items():
        if ds == "meta":
            continue
        for m, v in models.items():
            print(f"  {ds} · {m}: MAE {v['cv_mae_mean']}±{v['cv_mae_std']} "
                  f"RMSE {v['cv_rmse_mean']}±{v['cv_rmse_std']} R2={v['cv_r2_mean']}")
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = ROOT / "experiments" / "price" / "runs" / ts
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "baselines_metrics.json").write_text(json.dumps(
        {"created_at": ts, "seed": SEED, "summary": summary}, indent=2) + "\n")
    with (out_dir / "cv_results.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"metrics -> {out_dir.relative_to(ROOT)}/baselines_metrics.json")


if __name__ == "__main__":
    main()
