#!/usr/bin/env python3
"""§16 Final model selection — holdout tak tersentuh + kriteria seleksi.

Formulasi: log1p (pemenang §9). Split: GroupShuffleSplit 20% per property_id
(seed 42, holdout TIDAK disentuh CV). Kandidat: tuned CatBoost + tuned XGB
(params dari runs/*/tuning_*.json) + B0 + B1 (referensi aman).

Output runs/<ts>/:
  metrics.json               CV + holdout + latency + kriteria + pemenang
  cv_results.csv             5-fold GroupKFold pada train saja
  holdout_predictions.csv    prediksi vs aktual per baris holdout
  feature_importance.csv     gain (tree) untuk kandidat tree
  experiment_manifest.json   dataset version, git commit, seed, params, ts
  artefak: ../../artifacts/{selected_model.joblib,preprocessor.joblib,
           feature_schema.json,training_config.json}

Usage: .venv-ml/bin/python experiments/price/select_final.py
"""

from __future__ import annotations

import csv
import json
import pathlib
import subprocess
import sys
import time
from datetime import datetime, timezone

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import GroupShuffleSplit

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import price_io  # noqa: E402
import run_baselines as rb  # noqa: E402
import run_candidates as rc  # noqa: E402
import tune_candidates as tc  # noqa: E402

RAW = ROOT / "data" / "raw" / "price"
SEED = 42
ART = ROOT / "experiments" / "price" / "artifacts"


def latest_tuning() -> dict:
    files = sorted((ROOT / "experiments" / "price" / "runs")
                   .glob("*/tuning_kostara_local_idr_log1p.json"))
    if not files:
        sys.exit("ERROR: tuning_*.json belum ada — jalankan §15 dulu.")
    data = json.loads(files[-1].read_text())
    return {r["family"]: r for r in data["results"]}


def metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict:
    return {
        "mae": round(float(mean_absolute_error(y_true, y_pred)), 4),
        "rmse": round(float(np.sqrt(mean_squared_error(y_true, y_pred))), 4),
        "r2": round(float(r2_score(y_true, y_pred)), 4) if len(set(y_true)) > 1 else None,
    }


def make_factories(tuning: dict, num, cat):
    """Semua kandidat pada formulasi log1p (y sudah ditransformasi pemanggil)."""
    def cb_fit(X, y, g):
        m = tc.build_model("catboost", tuning["catboost"]["best_params"])
        m.set_params(cat_features=[i for i, c in enumerate(X.columns) if c in cat])
        m.fit(tc.cat_frame(X, num, cat), y)
        te = tc.cat_frame
        return lambda Xte, gte: m.predict(te(Xte, num, cat))

    def xgb_fit(X, y, g):
        prep = tc.make_prep("xgb", num, cat)
        Z = prep.fit_transform(X)
        m = tc.build_model("xgb", tuning["xgb"]["best_params"])
        m.fit(Z, y)
        return lambda Xte, gte: m.predict(prep.transform(Xte))

    return {
        "tuned_catboost": cb_fit,
        "tuned_xgboost": xgb_fit,
        "B0_geo_median": rb.build_geo_median,
        "B1_linear_regression": rb.build_linear(num, cat),
    }


def latency_ms(factory, X: pd.DataFrame, y, groups, reps: int = 200) -> dict:
    predictor = factory(X, y, groups)
    X1 = X.iloc[[0]]
    g1 = groups[:1]
    t = []
    for _ in range(reps):
        t0 = time.perf_counter()
        predictor(X1, g1)
        t.append((time.perf_counter() - t0) * 1000)
    return {"p50_ms": round(float(np.percentile(t, 50)), 3),
            "p95_ms": round(float(np.percentile(t, 95)), 3)}


def main() -> None:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    tuning = latest_tuning()
    df = price_io.load_kostara_train(RAW)
    feats = rc.local_features(df)
    num = [c for c in feats if pd.api.types.is_numeric_dtype(df[c])]
    cat = [c for c in feats if c not in num]
    y = df["target_idr"].to_numpy(float)
    y_fit = np.log1p(y)
    groups = df["group_property"].to_numpy()

    tr, te = next(GroupShuffleSplit(n_splits=1, test_size=0.2,
                                    random_state=SEED).split(df, y, groups))
    train, hold = df.iloc[tr], df.iloc[te]
    g_tr, g_te = groups[tr], groups[te]
    ytr_orig, yte_orig = y[tr], y[te]
    ytr_fit = y_fit[tr]
    print(f"train n={len(train)} ({train['group_property'].nunique()} grup) · "
          f"holdout n={len(hold)} ({hold['group_property'].nunique()} grup) "
          f"seed={SEED}")

    factories = make_factories(tuning, num, cat)

    # --- CV 5-fold pada train saja (stabilitas) ---
    cv_rows, cv_sum = rb.cv(train, target="target_idr", features=feats,
                            groups_col="group_property",
                            label="train_cv5_fold_log1p", models=factories,
                            train_transform=np.log1p, inverse_transform=np.expm1)

    # --- Holdout (tak tersentuh) ---
    hold_rows, hold_metrics = [], {}
    for name, factory in factories.items():
        predictor = factory(train[feats], ytr_fit, g_tr)
        p = np.expm1(predictor(hold[feats], g_te))
        m = metrics(yte_orig, p)
        lat = latency_ms(factory, train[feats], ytr_fit, g_tr)
        hold_metrics[name] = {**m, **lat}
        for i, idx in enumerate(hold.index):
            hold_rows.append({
                "model": name, "room_id": str(hold.iloc[i]["room_id"]),
                "property_id": str(g_te[i]),
                "district": str(hold.iloc[i].get("district", "")),
                "actual_idr": float(yte_orig[i]), "pred_idr": float(p[i]),
                "abs_error_idr": float(abs(yte_orig[i] - p[i])),
            })

    # --- Kriteria seleksi §16 ---
    criteria = {}
    for name in factories:
        cv, ho = cv_sum[name], hold_metrics[name]
        criteria[name] = {
            "holdout_mae": ho["mae"], "holdout_rmse": ho["rmse"],
            "holdout_r2": ho["r2"],
            "cv_mae_mean": cv["cv_mae_mean"], "cv_mae_std": cv["cv_mae_std"],
            "cv_rmse_mean": cv["cv_rmse_mean"],
            "generalization_gap": round(abs(cv["cv_mae_mean"] - ho["mae"]), 4),
            "latency_p50_ms": ho["p50_ms"], "latency_p95_ms": ho["p95_ms"],
            "complexity": {"tuned_catboost": 3, "tuned_xgboost": 3,
                           "B0_geo_median": 1, "B1_linear_regression": 2}[name],
            "stability_rank": round(cv["cv_mae_std"], 4),
        }
    # Urutan: holdout MAE dulu, lalu CV std, lalu kompleksitas (§16.1-8)
    ranked = sorted(criteria,
                    key=lambda n: (criteria[n]["holdout_mae"],
                                   criteria[n]["cv_mae_std"],
                                   criteria[n]["complexity"]))
    winner = ranked[0]

    # --- Feature importance (tree) ---
    fi_rows = []
    for name in ("tuned_catboost", "tuned_xgboost"):
        # rebuild model utk importance (predictor lambda menyimpan via closure)
        if name == "tuned_xgboost":
            prep = tc.make_prep("xgb", num, cat)
            Z = prep.fit_transform(train[feats])
            m = tc.build_model("xgb", tuning["xgb"]["best_params"])
            m.fit(Z, ytr_fit)
            names = prep.get_feature_names_out()
            imp = m.feature_importances_
        else:
            m = tc.build_model("catboost", tuning["catboost"]["best_params"])
            m.set_params(cat_features=[i for i, c in enumerate(feats) if c in cat])
            m.fit(tc.cat_frame(train[feats], num, cat), ytr_fit)
            names = np.array(feats)
            imp = m.feature_importances_
        for n_, v_ in zip(names, imp):
            fi_rows.append({"model": name, "feature": str(n_),
                            "importance": round(float(v_), 6)})

    # --- Artefak model terpilih ---
    ART.mkdir(parents=True, exist_ok=True)
    if winner == "tuned_catboost":
        m = tc.build_model("catboost", tuning["catboost"]["best_params"])
        m.set_params(cat_features=[i for i, c in enumerate(feats) if c in cat])
        m.fit(tc.cat_frame(df[feats], num, cat), y_fit)  # final: seluruh data
        joblib.dump({"model": m, "kind": "catboost",
                     "cat_features": [c for c in feats if c in cat],
                     "features": feats, "target_transform": "log1p"},
                    ART / "selected_model.joblib")
        pre = None
    else:
        prep = tc.make_prep("xgb", num, cat)
        Z = prep.fit_transform(df[feats])
        m = tc.build_model("xgb", tuning["xgb"]["best_params"])
        m.fit(Z, y_fit)
        joblib.dump({"model": m, "kind": "xgboost", "features": feats,
                     "target_transform": "log1p"},
                    ART / "selected_model.joblib")
        joblib.dump(prep, ART / "preprocessor.joblib")
        pre = "preprocessor.joblib"
    (ART / "feature_schema.json").write_text(json.dumps({
        "features": feats, "numeric": num, "categorical": cat,
        "target": "monthly_price", "target_transform": "log1p",
        "district": "properties.district (trigger, 11 kode 13.71.*)",
    }, indent=2) + "\n")
    training_config = {
        "seed": SEED, "split": "GroupShuffleSplit test_size=0.2",
        "formulation": "log1p", "folds_cv": 5,
        "best_params": {n_: tuning[n_]["best_params"]
                        for n_ in tuning},
        "tuning_stop": {n_: tuning[n_]["stop_reason"] for n_ in tuning},
        "dataset_version": "kostara-padang-v1-ed0ada2321be30cd",
    }
    (ART / "training_config.json").write_text(json.dumps(training_config, indent=2) + "\n")

    # --- Simpan runs/<ts>/ ---
    out = ROOT / "experiments" / "price" / "runs" / ts
    out.mkdir(parents=True, exist_ok=True)
    (out / "metrics.json").write_text(json.dumps({
        "created_at": ts, "label": "kostara_local_idr_log1p", "seed": SEED,
        "n_train": len(train), "n_holdout": len(hold),
        "cv_summary": cv_sum, "holdout": hold_metrics,
        "criteria": criteria, "ranking": ranked, "selected": winner,
    }, indent=2) + "\n")
    with (out / "cv_results.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(cv_rows[0].keys()))
        w.writeheader(); w.writerows(cv_rows)
    with (out / "holdout_predictions.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(hold_rows[0].keys()))
        w.writeheader(); w.writerows(hold_rows)
    with (out / "feature_importance.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(fi_rows[0].keys()))
        w.writeheader(); w.writerows(fi_rows)
    git = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                         capture_output=True, text=True).stdout.strip()
    (out / "experiment_manifest.json").write_text(json.dumps({
        "experiment_id": "PRICE-EXP-001", "created_at": ts,
        "dataset_version": "kostara-padang-v1-ed0ada2321be30cd",
        "git_commit": git, "seed": SEED,
        "hyperparameters": training_config["best_params"],
        "metrics_file": "metrics.json",
        "artifact_path": "experiments/price/artifacts/selected_model.joblib",
        "preprocessor": pre,
        "holdout_group_ids": sorted(set(g_te)),
    }, indent=2) + "\n")

    print(f"\n=== Kriteria (holdout MAE · CV MAE±std · gap · p50/p95) ===")
    for n_ in ranked:
        c = criteria[n_]
        print(f"  {n_:22s} hold {c['holdout_mae']:>12,.1f} · "
              f"cv {c['cv_mae_mean']:>12,.1f}±{c['cv_mae_std']:>10,.1f} · "
              f"gap {c['generalization_gap']:>10,.1f} · "
              f"p50 {c['latency_p50_ms']}ms p95 {c['latency_p95_ms']}ms")
    print(f"SELECTED: {winner}  (holdout n={len(hold)} — "
          f"SEDIKIT, baca bersama CV & benchmark AirROI)")
    print(f"metrics -> {out.relative_to(ROOT)}/metrics.json")
    print(f"artifact -> {ART.relative_to(ROOT)}/selected_model.joblib")


if __name__ == "__main__":
    main()
