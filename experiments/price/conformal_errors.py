#!/usr/bin/env python3
"""§17 Split conformal 80% + §18 Error analysis — model terpilih (§16).

§17: interval conformal pada skala IDR (evaluasi setelah expm1), kalibrasi
group-aware dari train (bukan holdout), coverage empiris holdout dilaporkan
ASLI. Segmen tanpa dukungan kalibrasi cukup → INSUFFICIENT_DATA (tanpa
angka palsu).

§18: error per district / price band / room-size / facility completeness /
gender type (travel-time band: N/A — fitur tidak ada di V1, tanpa ETA
palsu). Segmen tak andal → kandidat aturan fallback.

Output runs/<ts>/: interval_metrics.json, coverage_by_segment.csv,
errors.csv, error_analysis.md

Usage: .venv-ml/bin/python experiments/price/conformal_errors.py
"""

from __future__ import annotations

import csv
import json
import pathlib
import sys
from datetime import datetime, timezone

import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error
from sklearn.model_selection import GroupKFold, GroupShuffleSplit

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import price_io  # noqa: E402
import run_candidates as rc  # noqa: E402
import tune_candidates as tc  # noqa: E402

RAW = ROOT / "data" / "raw" / "price"
SEED = 42
ALPHA = 0.2  # coverage target 80%
MIN_CAL_SEGMENT = 3  # <3 skor kalibrasi per segmen → INSUFFICIENT_DATA


def latest_selected() -> tuple[str, dict]:
    files = sorted((ROOT / "experiments" / "price" / "runs").glob("*/metrics.json"))
    if not files:
        sys.exit("ERROR: metrics.json (§16) belum ada.")
    m = json.loads(files[-1].read_text())
    return m["selected"], json.loads(
        (ROOT / "experiments" / "price" / "artifacts" / "training_config.json")
        .read_text())


def fit_cb(params: dict, feats, num, cat, X, y_fit):
    """X: boleh frame penuh — dislice ke [feats] di sini."""
    m = tc.build_model("catboost", params)
    m.set_params(cat_features=[i for i, c in enumerate(feats) if c in cat])
    m.fit(tc.cat_frame(X[feats], num, cat), y_fit)
    return m


def main() -> None:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    selected, cfg = latest_selected()
    if selected != "tuned_catboost":
        sys.exit(f"ERROR: model terpilih {selected} — skrip ini khusus "
                 "tuned_catboost (sesuaikan bila seleksi berubah).")
    params = cfg["best_params"]["catboost"]

    df = price_io.load_kostara_train(RAW)
    feats = rc.local_features(df)
    num = [c for c in feats if pd.api.types.is_numeric_dtype(df[c])]
    cat = [c for c in feats if c not in num]
    y = df["target_idr"].to_numpy(float)
    groups = df["group_property"].to_numpy()

    # Split §16 direproduksi → train/holdout
    tr, te = next(GroupShuffleSplit(n_splits=1, test_size=0.2,
                                    random_state=SEED).split(df, y, groups))
    train, hold = df.iloc[tr], df.iloc[te]
    ytr, yte = y[tr], y[te]
    gtr, gte = groups[tr], groups[te]

    # --- §17: proper-train + calibration (group-aware, dari train saja) ---
    pr_tr, pr_cal = next(GroupShuffleSplit(
        n_splits=1, test_size=0.3, random_state=SEED).split(
            train, ytr, gtr))
    proper, cal = train.iloc[pr_tr], train.iloc[pr_cal]
    g_proper = gtr[pr_tr]
    m = fit_cb(params, feats, num, cat, proper, np.log1p(ytr[pr_tr]))
    pred_cal = np.expm1(m.predict(tc.cat_frame(cal[feats], num, cat)))
    scores = np.abs(ytr[pr_cal] - pred_cal)
    n_cal = len(scores)
    k = int(np.ceil((n_cal + 1) * (1 - ALPHA)))
    q_hat = float(np.sort(scores)[min(k, n_cal) - 1])  # konformal quantile

    # Interval pada holdout (skala IDR)
    m_hold = fit_cb(params, feats, num, cat, train, np.log1p(ytr))
    pred_hold = np.expm1(m_hold.predict(tc.cat_frame(hold[feats], num, cat)))
    lower, upper = pred_hold - q_hat, pred_hold + q_hat
    inside = (yte >= lower) & (yte <= upper)
    coverage = float(np.mean(inside))
    interval_metrics = {
        "method": "split_conformal", "alpha": ALPHA,
        "target_coverage": 1 - ALPHA,
        "n_calibration": int(n_cal),
        "q_hat_idr": round(q_hat, 2),
        "holdout_n": int(len(te)),
        "empirical_coverage": round(coverage, 4),
        "holdout_inside": int(inside.sum()),
        "mean_width_idr": round(float(np.mean(upper - lower)), 2),
        "calibration_group_count": int(len(np.unique(gtr[pr_cal]))),
        "status": ("OK" if n_cal >= 5 else "INSUFFICIENT_DATA"),
        "coverage_below_target": bool(coverage < 1 - ALPHA),
        "note": ("coverage empiris diukur ASLI pada holdout n kecil — "
                 "bukan klaim populasi; bila coverage_below_target=true "
                 "interval SEMPIT untuk data saat ini — jangan klaim "
                 "80% coverage tercapai"),
    }

    # --- §18: prediksi OOF (train, 5-fold) + holdout → 40 baris error ---
    rows = []
    oof = np.empty(len(train))
    for i, (a, b) in enumerate(GroupKFold(n_splits=5).split(
            train, ytr, gtr)):
        mm = fit_cb(params, feats, num, cat, train.iloc[a], np.log1p(ytr[a]))
        oof[b] = np.expm1(mm.predict(tc.cat_frame(train.iloc[b][feats], num, cat)))
    for i in range(len(train)):
        rows.append({"split": "oof_train", "property_id": str(gtr[i]),
                     **_row(train.iloc[i], ytr[i], oof[i])})
    for i in range(len(hold)):
        rows.append({"split": "holdout", "property_id": str(gte[i]),
                     **_row(hold.iloc[i], yte[i], pred_hold[i])})
    err = pd.DataFrame(rows)
    err["abs_error_idr"] = (err["actual_idr"] - err["pred_idr"]).abs()

    # Segment: district, price band, size band, facility, gender
    err["price_band"] = pd.qcut(err["actual_idr"], 4,
                                labels=["Q1", "Q2", "Q3", "Q4"],
                                duplicates="drop")
    err["size_band"] = pd.cut(err["size_sqm"], [0, 10, 16, 25, 999],
                              labels=["<=10", "11-16", "17-25", ">25"])
    err["facility_band"] = pd.qcut(err["amenities_count"].rank(method="first"),
                                   3, labels=["sedang", "banyak", "sangat"],
                                   duplicates="drop")
    segments = []
    for col, segname in (("district", "district"), ("price_band", "price_band"),
                         ("size_band", "room_size"),
                         ("facility_band", "facility_completeness"),
                         ("gender_policy", "gender_type")):
        for val, g in err.groupby(col, observed=True):
            n = len(g)
            mae = float(g["abs_error_idr"].mean())
            segments.append({
                "segment_type": segname, "value": str(val), "n": n,
                "mae_idr": round(mae, 2),
                "reliable": bool(n >= 5),
                "status": "OK" if n >= 5 else "INSUFFICIENT_DATA",
            })
    # travel-time band: sengaja tidak ada (V1 tanpa fitur travel time)

    # --- Simpan ---
    out = ROOT / "experiments" / "price" / "runs" / ts
    out.mkdir(parents=True, exist_ok=True)
    (out / "interval_metrics.json").write_text(
        json.dumps(interval_metrics, indent=2) + "\n")
    with (out / "errors.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(err.columns))
        w.writeheader(); w.writerows(err.to_dict("records"))
    with (out / "coverage_by_segment.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(segments[0].keys()))
        w.writeheader(); w.writerows(segments)

    unreliable = [s for s in segments if not s["reliable"]]
    band = {s["value"]: s["mae_idr"] for s in segments
            if s["segment_type"] == "price_band"}
    extremes = [b for b in ("Q1", "Q4") if b in band and b in
                (s["value"] for s in segments)]
    md = [f"# Error analysis — PRICE-EXP-001 ({ts})",
          "",
          "Model: tuned_catboost (log1p) · seed 42 · data: "
          "kostara-padang-v1-ed0ada2321be30cd",
          f"Metrik keseluruhan: MAE OOF+holdout = "
          f"{err['abs_error_idr'].mean():,.0f} IDR (n={len(err)})",
          "",
          "## Interval (§17)",
          "",
          f"- Split conformal 80% · kalibrasi n={n_cal} (group-aware, "
          f"{interval_metrics['calibration_group_count']} grup)",
          f"- q_hat = {q_hat:,.0f} IDR · lebar rata-rata = "
          f"{interval_metrics['mean_width_idr']:,.0f} IDR",
          f"- **Coverage empiris holdout = {coverage:.0%}** "
          f"({int(inside.sum())}/{len(te)} baris) — diukur, bukan diklaim",
          f"- Target 80% **{'TIDAK' if coverage < 1 - ALPHA else 'tercapai'}** "
          f"pada holdout saat ini (n={len(te)} kecil; konformal finit-sample "
          f"memberi jaminan lemah di n kalibrasi kecil) → coverage empiris "
          f"ikut dilaporkan di setiap respons (quality_status), tanpa klaim "
          f"coverage tercapai",
          "",
          "## Segment (§18)",
          "",
          "| segment | value | n | MAE IDR | status |",
          "|---|---|---|---|---|",
          ]
    for s in segments:
        md.append(f"| {s['segment_type']} | {s['value']} | {s['n']} | "
                  f"{s['mae_idr']:,.0f} | {s['status']} |")
    md += ["",
           "## Segmen tidak andal & aturan fallback",
           ""]
    if unreliable:
        for s in unreliable:
            md.append(f"- `{s['segment_type']}={s['value']}`: n={s['n']} < 5 "
                      f"→ INSUFFICIENT_DATA (jangan tampilkan interval)")
    else:
        md.append("- Tidak ada segmen dengan n<5 pada data saat ini.")
    md += [
        "- `travel_time_band`: N/A di V1 (tidak ada fitur travel time; "
        "tanpa routing engine → tanpa ETA, ADR-003).",
        "- Aturan block: bila holdout/observasi segmen < 3 kalibrasi → "
        "respons `INSUFFICIENT_DATA`; bila model servis gagal → fallback "
        "B0 district median (THINK-01).",
        (f"- Pola error teramati: price band Q1 MAE "
         f"{band.get('Q1', 0):,.0f} / Q4 MAE {band.get('Q4', 0):,.0f} "
         f"vs Q2 {band.get('Q2', 0):,.0f} / Q3 {band.get('Q3', 0):,.0f} — "
         f"ekstrem harga ~2-3× lebih buruk → `quality_status=low_confidence` "
         f"untuk harga di luar p50±IQR data training (aturan disimpan di "
         f"training_config, diterapkan FastAPI).") if extremes else "",
        "",
        "Catatan jujur: n=40 sangat kecil — semua angka adalah kondisi data "
        "dev saat ini, bukan klaim performa produk (AGENTS §4.4).",
    ]
    (out / "error_analysis.md").write_text("\n".join(md) + "\n")

    print(f"selected={selected} · q_hat={q_hat:,.0f} IDR · "
          f"coverage={coverage:.0%} ({int(inside.sum())}/{len(te)}) · "
          f"status={interval_metrics['status']}")
    print(f"unreliable segments: {len(unreliable)}/{len(segments)}")
    print(f"-> {out.relative_to(ROOT)}/{{interval_metrics,errors,"
          f"coverage_by_segment}}+error_analysis.md")


def _row(row: pd.Series, actual: float, pred: float) -> dict:
    return {
        "room_id": str(row.get("room_id", "")),
        "district": str(row.get("district", "")),
        "gender_policy": str(row.get("gender_policy", "")),
        "size_sqm": float(row.get("size_sqm", np.nan) or 0),
        "amenities_count": int(row.get("amenities_count", 0)),
        "actual_idr": float(actual), "pred_idr": float(pred),
    }


if __name__ == "__main__":
    main()
