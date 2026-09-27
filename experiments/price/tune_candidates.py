#!/usr/bin/env python3
"""§15 Hyperparameter optimization (Optuna) — top-2 kandidat dari hasil Phase E.

Aturan §15:
  - hanya 2 model teratas (auto: cv_mae_mean terkecil dari candidates_metrics.json)
  - ≤50 completed trials per model (default 50, `--trials` untuk smoke run)
  - stop bila best MAE tidak membaik >0,5% relatif selama 10 completed trial
  - MedianPruner fold-based (pruning "where supported" — laporan per fold)
  - seed 42 (sampler TPE + model); log semua trial → trials CSV + JSON
  - XGBoost/CatBoost: best iteration = hyperparam n_estimators/iterations terbaik
  - RF tidak pernah dideskripsikan sebagai "converged"; frasa
    "MODEL SELECTION STABLE" hanya dicetak bila stop awal tercapai (stabil)

Target formulasi mengikuti `--label` (akhir `_log1p` → latih log1p, metrik IDR asli).

Usage:
  .venv-ml/bin/python experiments/price/tune_candidates.py                # default local
  .venv-ml/bin/python experiments/price/tune_candidates.py --label airroi_benchmark_usd --trials 5
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys
import time
from datetime import datetime, timezone

import numpy as np
import optuna
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import price_io  # noqa: E402
import run_candidates as rc  # noqa: E402

RAW = ROOT / "data" / "raw" / "price"
SEED = 42
FAMILY = {"C1_random_forest": "rf", "C2_xgboost": "xgb", "C3_catboost": "catboost"}


def load_label(label: str) -> tuple[pd.DataFrame, str, list[str], str, str]:
    """→ (df, target_col, features, groups_col, dataset_tag)"""
    if label.startswith("airroi"):
        df = price_io.load_airroi_clean(RAW / "public" / "airroi_apac")
        return df, "target_usd", price_io.ALLOWED_FEATURES, "group_city", "airroi"
    df = price_io.load_kostara_train(RAW)
    return df, "target_idr", rc.local_features(df), "group_property", "kostara"


def latest_candidates(label: str) -> tuple[pathlib.Path, dict]:
    files = sorted((ROOT / "experiments" / "price" / "runs")
                   .glob("*/candidates_metrics.json"))
    for f in reversed(files):
        s = json.loads(f.read_text()).get("summary", {})
        if label in s:
            return f, s[label]
    sys.exit(f"ERROR: candidates_metrics.json dengan label '{label}' belum ada "
             "— jalankan Phase E (run_candidates.py) dulu.")


def suggest(family: str, trial: optuna.Trial) -> dict:
    if family == "xgb":
        return {
            "n_estimators": trial.suggest_int("n_estimators", 100, 800),
            "max_depth": trial.suggest_int("max_depth", 3, 10),
            "learning_rate": trial.suggest_float("learning_rate", 1e-2, 3e-1, log=True),
            "subsample": trial.suggest_float("subsample", 0.6, 1.0),
            "colsample_bytree": trial.suggest_float("colsample_bytree", 0.6, 1.0),
            "min_child_weight": trial.suggest_int("min_child_weight", 1, 10),
            "reg_lambda": trial.suggest_float("reg_lambda", 1e-3, 10.0, log=True),
        }
    if family == "catboost":
        return {
            "iterations": trial.suggest_int("iterations", 100, 1000),
            "depth": trial.suggest_int("depth", 4, 10),
            "learning_rate": trial.suggest_float("learning_rate", 1e-2, 3e-1, log=True),
            "l2_leaf_reg": trial.suggest_float("l2_leaf_reg", 1e-3, 10.0, log=True),
        }
    return {  # rf — deskripsi: tidak pernah "converged"
        "n_estimators": trial.suggest_int("n_estimators", 100, 400),
        "max_depth": trial.suggest_categorical("max_depth", [None, 8, 12, 16, 24, 32]),
        "min_samples_leaf": trial.suggest_int("min_samples_leaf", 1, 10),
        "max_features": trial.suggest_categorical("max_features", ["sqrt", 0.5, 1.0]),
    }


def build_model(family: str, params: dict):
    """Model tanpa preprocessing (prep dilakukan per fold — tanpa leakage)."""
    if family == "rf":
        from sklearn.ensemble import RandomForestRegressor
        return RandomForestRegressor(random_state=SEED, n_jobs=-1, **params)
    if family == "xgb":
        from xgboost import XGBRegressor
        return XGBRegressor(random_state=SEED, n_jobs=1, tree_method="hist",
                            **params)
    from catboost import CatBoostRegressor
    return CatBoostRegressor(random_seed=SEED, verbose=False,
                             allow_writing_files=False, **params)


def make_prep(family: str, num: list[str], cat: list[str]) -> ColumnTransformer:
    if family == "xgb":
        return ColumnTransformer([
            ("num", Pipeline([
                ("imp", SimpleImputer(strategy="median")),
                ("sc", StandardScaler()),
            ]), num),
            ("cat", Pipeline([
                ("imp", SimpleImputer(strategy="most_frequent")),
                ("oh", OneHotEncoder(handle_unknown="ignore")),
            ]), cat),
        ], sparse_threshold=0.3)
    return ColumnTransformer([
        ("num", SimpleImputer(strategy="median"), num),
        ("cat", Pipeline([
            ("imp", SimpleImputer(strategy="most_frequent")),
            ("oh", OneHotEncoder(handle_unknown="ignore")),
        ]), cat),
    ], sparse_threshold=0.3)


def cat_frame(Xdf: pd.DataFrame, num: list[str], cat: list[str]) -> pd.DataFrame:
    """Kolom kategori CatBoost: object + '__missing__' (setara run_candidates)."""
    Z = Xdf.copy()
    for c in cat:
        Z[c] = Z[c].astype("object").fillna("__missing__").astype(str)
    for c in num:
        Z[c] = pd.to_numeric(Z[c], errors="coerce")
    return Z


def make_objective(df, target, features, groups_col, family, is_log, n_folds):
    num = [c for c in features if pd.api.types.is_numeric_dtype(df[c])]
    cat = [c for c in features if c not in num]
    y_orig = df[target].to_numpy(float)
    y_fit = np.log1p(y_orig) if is_log else y_orig
    X = df[features]
    groups = df[groups_col].to_numpy()
    folds = list(GroupKFold(n_splits=n_folds).split(X, y_fit, groups))

    def objective(trial: optuna.Trial) -> float:
        params = suggest(family, trial)
        model = build_model(family, params)
        if family == "catboost":
            # indeks kolom kategori dalam urutan `features` (cat_frame = urutan asli)
            model.set_params(cat_features=[i for i, c in enumerate(features)
                                           if c in cat])
        maes = []
        for k, (tr, te) in enumerate(folds, 1):
            if family == "catboost":
                Xtr = cat_frame(X.iloc[tr], num, cat)
                Xte = cat_frame(X.iloc[te], num, cat)
                model.fit(Xtr, y_fit[tr])
                p = model.predict(Xte)
            else:
                prep = make_prep(family, num, cat)
                Ztr = prep.fit_transform(X.iloc[tr])
                Zte = prep.transform(X.iloc[te])
                model.fit(Ztr, y_fit[tr])
                p = model.predict(Zte)
            if is_log:
                p = np.expm1(p)
            mae = float(np.mean(np.abs(y_orig[te] - p)))
            maes.append(mae)
            trial.report(float(np.mean(maes)), k)
            if trial.should_prune():
                raise optuna.TrialPruned()
        return float(np.mean(maes))

    return objective


class StopNoImprove:
    """§15.6: stop bila best MAE tidak membaik >0,5% relatif selama 10
    completed trial berturut-turut."""

    def __init__(self, min_rel: float = 0.005, patience: int = 10):
        self.min_rel = min_rel
        self.patience = patience
        self.best: float | None = None
        self.stale = 0
        self.triggered = False

    def __call__(self, study: optuna.Study, trial: optuna.FrozenTrial) -> None:
        if trial.state != optuna.trial.TrialState.COMPLETE:
            return
        if self.best is None or study.best_value < self.best * (1 - self.min_rel):
            self.best = study.best_value
            self.stale = 0
        else:
            self.stale += 1
            if self.stale >= self.patience:
                self.triggered = True
                study.stop()


def tune_one(family: str, label: str, args) -> tuple[dict, optuna.Study]:
    df, target, features, groups_col, _ = load_label(label)
    is_log = label.endswith("_log1p")
    objective = make_objective(df, target, features, groups_col, family,
                               is_log, args.folds)
    sampler = optuna.samplers.TPESampler(seed=SEED)
    pruner = optuna.pruners.MedianPruner(n_startup_trials=5, n_warmup_steps=1)
    study = optuna.create_study(direction="minimize", sampler=sampler,
                                pruner=pruner,
                                study_name=f"{label}_{family}_seed{SEED}")
    stop_cb = StopNoImprove()
    t0 = time.perf_counter()
    completed = 0
    attempts = 0
    max_attempts = max(args.trials * 2, args.trials + 10)  # gagal terus → berhenti
    while (completed < args.trials and not stop_cb.triggered
           and attempts < max_attempts):
        attempts += 1
        study.optimize(objective, n_trials=1, callbacks=[stop_cb],
                       catch=(Exception,))
        if study.trials[-1].state == optuna.trial.TrialState.COMPLETE:
            completed += 1
    wall = time.perf_counter() - t0

    n_pruned = sum(1 for t in study.trials
                   if t.state == optuna.trial.TrialState.PRUNED)
    result = {
        "family": family, "label": label, "seed": SEED,
        "n_folds": args.folds, "n_completed": completed, "n_pruned": n_pruned,
        "best_value_mae": round(float(study.best_value), 4),
        "best_params": {k: v for k, v in study.best_params.items()},
        "best_iteration": (study.best_params.get("n_estimators")
                           or study.best_params.get("iterations")),
        "stop_reason": ("early_stop_0.5pct_over_10" if stop_cb.triggered
                        else "max_trials_reached"),
        "stable": stop_cb.triggered,
        "wall_s": round(wall, 1),
    }
    # frasa §15: MODEL SELECTION STABLE hanya bila tuning stabil
    result["selection_phrase"] = ("MODEL SELECTION STABLE" if stop_cb.triggered
                                  else "tuning selesai (max trials) — "
                                       "klaim stabil BELUM boleh dipakai")
    return result, study


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--label", default="kostara_local_idr")
    ap.add_argument("--trials", type=int, default=50,
                    help="max completed trials per model (§15: maks 50)")
    ap.add_argument("--folds", type=int, default=3,
                    help="folds dlm objektif Optuna (evaluasi final tetap 5-fold cv)")
    ap.add_argument("--families", default="auto",
                    help="auto (top-2 dari candidates) atau comma list: xgb,catboost,rf")
    args = ap.parse_args()
    if args.trials > 50:
        sys.exit("ERROR: §15 membatasi 50 completed trials per model.")

    src, cand = latest_candidates(args.label)
    if args.families == "auto":
        ranked = sorted(cand.items(), key=lambda kv: kv[1]["cv_mae_mean"])
        fams = [FAMILY[name] for name, _ in ranked[:2]]
    else:
        fams = [f.strip() for f in args.families.split(",")]

    print(f"source candidates: {src.relative_to(ROOT)}")
    print(f"label={args.label} families={fams} trials<={args.trials} "
          f"folds={args.folds} seed={SEED}")

    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = ROOT / "experiments" / "price" / "runs" / ts
    out_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for fam in fams:
        print(f"\n=== tuning {fam} ===", flush=True)
        res, study = tune_one(fam, args.label, args)
        results.append(res)
        df_t = study.trials_dataframe()
        df_t.to_csv(out_dir / f"tuning_trials_{fam}.csv", index=False)
        print(f"  best MAE {res['best_value_mae']} · {res['n_completed']} completed · "
              f"{res['n_pruned']} pruned · {res['stop_reason']} · "
              f"{res['wall_s']}s", flush=True)

    payload = {"created_at": ts, "label": args.label, "source_candidates": str(src),
               "seed": SEED, "trials_budget": args.trials, "folds": args.folds,
               "results": results}
    (out_dir / f"tuning_{args.label}.json").write_text(
        json.dumps(payload, indent=2) + "\n")
    with (out_dir / f"tuning_summary_{args.label}.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(results[0].keys()))
        w.writeheader()
        w.writerows(results)
    print(f"\ntuning -> {out_dir.relative_to(ROOT)}/tuning_{args.label}.json")
    for r in results:
        print(f"  {r['family']}: {r['selection_phrase']}")


if __name__ == "__main__":
    main()
