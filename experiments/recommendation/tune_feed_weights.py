#!/usr/bin/env python3
"""Parity training-serving rekomendasi (opsi C, dijalankan sebelum CP-05A).

Masalah (ADR-005 / MODEL_CARD §4): evaluasi offline memakai cosine+geo+blend,
sedangkan serving `feed_recommendations` (migrasi 010010 :492-706) memakai
weighted-sum 5 komponen SQL. Skrip ini men-port formula SQL ke Python, lalu:

  1. grid-tune w_budget/w_campus/w_facility/w_rating/w_trending pada split
     `val` (yang selama ini tidak terpakai);
  2. membandingkan 3 kandidat pada split `test` dengan formula yang SAMA:
       sql_popularity  = (0,0,0,0,1)  — murni trending (skor murni popularity)
       sql_hand        = PARAMS activate_model (hardcoded CP-04B)
       sql_tuned       = hasil grid val (anchor: sql_hand)
  3. menulis feed_runs/<ts>/{metrics.json,manifest.json}; activate_model.py
     membaca `feed_params` dari manifest terakhir (bukan hardcoded).

Parity notes (jujur, ikut manifest):
  - komponen/skor/tie-break SQL dipors 1:1 (termasuk filter available>0);
  - jarak: haversine (sphere) vs PostGIS geography (spheroid) — delta kecil,
    hanya memengaruhi comp_campus dekat batas radius;
  - popularity komponen/tie-break: hitungan interaksi AS-OF train-only
    (anti-leakage, AGENTS §11.4). Serving SQL memakai all-time count —
    limitasi serving yang dicatat, bukan dikejar di evaluasi;
  - tanpa budget (bmax null/0) → comp_budget = 0.5 (sama dgn SQL :615);
  - skor = ranking 0-100, BUKAN probabilitas (FR-REC-04).

Usage:
  python3 experiments/recommendation/tune_feed_weights.py
  python3 experiments/recommendation/tune_feed_weights.py --selftest
"""

from __future__ import annotations

import argparse
import datetime as dt
import itertools
import json
import math
import pathlib
import subprocess
import sys

import numpy as np
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_baselines import (  # noqa: E402
    KS, SEED, _haversine, candidates_for, load, metrics_at_k, temporal_split,
)

FEED_RUNS = pathlib.Path(__file__).resolve().parent / "feed_runs"
RAW = ROOT / "data" / "raw"

# Bobot hardcoded CP-04B (activate_model.py) — kandidat "hand".
HAND = {"w_budget": 0.245, "w_campus": 0.21, "w_facility": 0.105,
        "w_rating": 0.14, "w_trending": 0.3}
W_KEYS = ("w_budget", "w_campus", "w_facility", "w_rating", "w_trending")
POPULARITY_PARAMS = {k: 0.0 for k in W_KEYS} | {"w_trending": 1.0}
GRID_STEP = 0.1  # 7^5 - 1 non-zero + anchor hand = 16.807 konfigurasi


# ---------------------------------------------------------------- formula SQL

def comp_budget(price: float, bmin, bmax) -> float:
    """Port persis scored.comp_budget (migrasi 010010 :614-622)."""
    if bmax is None or pd.isna(bmax) or float(bmax) == 0:
        return 0.5
    bmax = float(bmax)
    bmin_f = None if bmin is None or pd.isna(bmin) else float(bmin)
    if bmin_f is not None and bmin_f <= price <= bmax:
        return max(0.0, 1.0 - abs(price - (bmin_f + bmax) / 2.0)
                   / max(bmax - bmin_f, 1.0))
    lo = abs(price - bmax)
    hi = abs(price - (bmin_f if bmin_f is not None else 0.0))
    return max(0.0, 1.0 - min(lo, hi) / max(bmax, 1.0))


def comp_campus(distance_m, max_dist) -> float:
    if distance_m is None or (isinstance(distance_m, float)
                              and math.isnan(distance_m)):
        return 0.5
    return max(0.0, 1.0 - float(distance_m) / max(int(max_dist), 1))


def comp_facility(matched: int, facs) -> float:
    n = 0 if facs is None else len(facs)
    if n == 0:
        return 0.5
    return float(matched) / n


def comp_rating(rating_avg: float, rating_count: int) -> float:
    return 0.5 if rating_count == 0 else float(rating_avg) / 5.0


def comp_trending(popularity: int) -> float:
    return math.log(1 + max(int(popularity), 0)) / math.log(101)


def sql_score(comps: tuple, params: tuple) -> int:
    """Port with_score (:643-652): half-up, clip 0..100, /max(sum,1e-4)."""
    total = sum(params)
    num = sum(w * c for w, c in zip(params, comps))
    s = 100.0 * num / max(total, 0.0001)
    return int(max(0, min(100, math.floor(s + 0.5))))


# ---------------------------------------------------------------- eval parity

def _norm_facs(p) -> list | None:
    fp = p.get("facility_priority")
    if isinstance(fp, (list, np.ndarray, tuple)):
        return [f for f in fp]
    return None


def build_cases(ev: pd.DataFrame, split_pos: str, item, prefs, camp_pts,
                fac_idx, avail_ids: set) -> tuple[list, int]:
    """Precompute eval case per user: kandidat SQL (verified+active+
    available>0) + komponen per kandidat (komponen independen params →
    grid loop murni aritmetika)."""
    pop_count = ev[ev["split"] == "train"].groupby("property_id").size()
    pos = ev[(ev["split"] == split_pos) & (ev["event_weight"] > 0)]
    eval_users = sorted(pos["user_id"].unique())
    cases, n_filtered = [], 0

    for uid in eval_users:
        cands = [c for c in candidates_for(uid, item, prefs, camp_pts, fac_idx)
                 if c in avail_ids]
        rel_all = set(pos[pos["user_id"] == uid]["property_id"])
        n_filtered += len(rel_all - set(cands))
        rel = rel_all & set(cands)
        if not rel:
            continue

        p = prefs.loc[uid] if uid in prefs.index else None
        bmin = bmax = None
        facs = None
        max_dist = 3000
        clat = clng = None
        if p is not None:
            bmin, bmax = p.get("budget_min"), p.get("budget_max")
            facs = _norm_facs(p)
            md = p.get("max_distance_m")
            if md is not None and not pd.isna(md):
                max_dist = int(md)
            cid = p.get("primary_campus_id")
            if cid is not None and not pd.isna(cid) and cid in camp_pts:
                clat, clng = camp_pts[cid]

        comps = []
        for pid, row in item.loc[cands].iterrows():
            dist = None
            if clat is not None and pd.notna(row["lat"]):
                dist = _haversine(row["lat"], row["lng"], clat, clng)
            matched = 0
            if facs:
                have = row["facility_ids"]
                have = set(have) if isinstance(
                    have, (list, np.ndarray, set)) else set()
                matched = len([f for f in facs if f in have])
            comps.append((
                comp_budget(float(row["price_from"]), bmin, bmax),
                comp_campus(dist, max_dist),
                comp_facility(matched, facs),
                comp_rating(float(row["rating_avg"]), int(row["rating_count"])),
                comp_trending(int(pop_count.get(pid, 0))),
                int(pop_count.get(pid, 0)),  # tie-break popularity
            ))
        cases.append((uid, rel, cands, comps))
    return cases, n_filtered


def eval_params(params: dict, cases: list, n_filtered: int, n_items: int,
                split_pos: str) -> dict:
    w = tuple(params[k] for k in W_KEYS)
    per_k = {k: [] for k in KS}
    all_recs: set = set()
    for uid, rel, cands, comps in cases:
        scored = [(sql_score(c[:5], w), c[5], pid)
                  for c, pid in zip(comps, cands)]
        scored.sort(key=lambda t: (-t[0], -t[1], str(t[2])))
        recs = [pid for _, _, pid in scored]
        all_recs |= set(recs)
        for k in KS:
            per_k[k].append(metrics_at_k(recs, rel, k))

    def agg(rows):
        if not rows:
            return None
        return {m: float(np.mean([r[m] for r in rows]))
                for m in ("p", "r", "ndcg", "hr")}

    return {f"@{k}": agg(per_k[k]) for k in KS} | {
        "coverage_catalog": len(all_recs) / n_items if n_items else 0.0,
        "n_eval_users": len(cases),
        "n_positives_filtered": int(n_filtered),
        "split": split_pos,
    }


# ---------------------------------------------------------------- tuning

def grid_params() -> list[dict[str, float]]:
    vals = [round(i * GRID_STEP, 1) for i in range(7)]  # 0.0..0.6
    out = [dict(zip(W_KEYS, combo))
           for combo in itertools.product(vals, repeat=5)
           if sum(combo) > 0]
    out.append({k: HAND[k] for k in W_KEYS})  # anchor hand
    return out


def tune_val(val_cases, n_filtered, n_items) -> dict:
    """Pilih bobot terbaik di val: NDCG@10 → HR@10 → L1 terkecil ke hand
    (tetap dekat prior bila tak ada bukti membaik) → leksikografis."""
    best_key, best_params = None, None
    for params in grid_params():
        m = eval_params(params, val_cases, n_filtered, n_items, "val")
        a = m["@10"]
        if not a:
            continue
        l1 = sum(abs(params[k] - HAND[k]) for k in W_KEYS)
        key = (round(a["ndcg"], 12), round(a["hr"], 12), -l1,
               tuple(-params[k] for k in W_KEYS))
        if best_key is None or key > best_key:
            best_key, best_params = key, params
    return best_params


def pick_feed(test_metrics: dict) -> str:
    """Test NDCG@10 tertinggi → HR; tie → kandidat personalisasi menang
    (urutan tuned > hand > popularity, selaras pick() FR-ML-03)."""
    best_name, best_key = None, None
    for cand in ("sql_tuned", "sql_hand", "sql_popularity"):
        m = test_metrics[cand]["@10"]
        if not m:
            continue
        key = (m["ndcg"], m["hr"])
        if best_key is None or key > best_key:
            best_name, best_key = cand, key
    return best_name or "sql_hand"


def run_once() -> dict:
    np.random.seed(SEED)
    events, item, prefs, camp_pts, fac_idx = load()
    ev = temporal_split(events)
    rooms = pd.read_parquet(RAW / "rooms.parquet")
    avail_ids = set(rooms.loc[rooms["status"] == "available", "property_id"])
    n_items = len(item)

    val_cases, val_filt = build_cases(ev, "val", item, prefs, camp_pts,
                                      fac_idx, avail_ids)
    test_cases, test_filt = build_cases(ev, "test", item, prefs, camp_pts,
                                        fac_idx, avail_ids)
    tuned = tune_val(val_cases, val_filt, n_items)
    hand = {k: HAND[k] for k in W_KEYS}
    cand_params = {"sql_popularity": dict(POPULARITY_PARAMS),
                   "sql_hand": hand, "sql_tuned": tuned}

    return {
        "evaluator": "sql_feed_parity",
        "params": cand_params,
        "val": {n: eval_params(p, val_cases, val_filt, n_items, "val")
                for n, p in cand_params.items()},
        "test": {n: eval_params(p, test_cases, test_filt, n_items, "test")
                 for n, p in cand_params.items()},
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        selftest()
        print("selftest PASS")
        return

    m1 = run_once()
    m2 = run_once()
    if json.dumps(m1, sort_keys=True) != json.dumps(m2, sort_keys=True):
        raise SystemExit("DETERMINISM FAIL: dua run identik berbeda")

    chosen = pick_feed(m1["test"])
    version = (RAW / "DATASET_VERSION.txt").read_text().strip()
    try:
        commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                capture_output=True, text=True,
                                check=True).stdout.strip()
        dirty = bool(subprocess.run(
            ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True,
            text=True, check=True).stdout.strip())
    except Exception:
        commit, dirty = "unknown", None

    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = FEED_RUNS / ts
    run_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "evaluator": "sql_feed_parity",
        "dataset_version": version,
        "git_commit": commit,
        "git_dirty": dirty,
        "seed": SEED,
        "split": "temporal 70/10/20 (val=tuning, test=disevaluasi 1x)",
        "grid": {"step": GRID_STEP, "n_configs": len(grid_params())},
        "chosen_candidate": chosen,
        "feed_params": m1["params"][chosen],
        "candidates_params": m1["params"],
        "deterministic_rerun": True,
        "parity_notes": [
            "komponen/skor/tie-break SQL 1:1 (incl. filter available>0)",
            "jarak haversine vs PostGIS geography (delta kecil, comp_campus)",
            "popularity = hitungan train-only as-of (anti-leakage); "
            "serving SQL = all-time count (limitasi serving dicatat)",
            "skor ranking 0-100 — BUKAN probabilitas (FR-REC-04)",
            "evaluasi unit: dev seed sintetis — BUKAN production data",
        ],
        "data_note": "dataset dev sintetis seed — BUKAN production data",
        "timestamp_utc": ts,
    }
    (run_dir / "metrics.json").write_text(json.dumps(
        {"evaluator": m1["evaluator"], "params": m1["params"],
         "val": m1["val"], "test": m1["test"]}, indent=2, sort_keys=True))
    (run_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))

    print(json.dumps({
        "chosen": chosen,
        "feed_params": manifest["feed_params"],
        "test_ndcg10": {k: (v["@10"] or {}).get("ndcg")
                        for k, v in m1["test"].items()},
        "val_ndcg10": {k: (v["@10"] or {}).get("ndcg")
                       for k, v in m1["val"].items()},
        "run_dir": str(run_dir.relative_to(ROOT)),
    }, indent=2))
    print("\nSELANJUTNYA: python3 experiments/recommendation/activate_model.py")


def selftest() -> None:
    """Assert math formula + ordering terhadap ekspektasi SQL."""
    assert comp_budget(1_000_000, None, None) == 0.5
    assert comp_budget(1_000_000, None, 0) == 0.5
    b = comp_budget(1_000_000, 800_000, 1_200_000)
    assert abs(b - 1.0) < 1e-9  # tepat di tengah band
    b_out = comp_budget(2_000_000, 800_000, 1_200_000)
    assert abs(b_out - (1 - 800_000 / 1_200_000)) < 1e-9  # 1/3
    assert comp_campus(None, 3000) == 0.5
    assert abs(comp_campus(1500, 3000) - 0.5) < 1e-9
    assert comp_facility(2, None) == 0.5
    assert comp_facility(2, ["a", "b", "c"]) == 2 / 3
    assert comp_rating(4.0, 0) == 0.5
    assert comp_rating(4.0, 3) == 0.8
    assert comp_trending(0) == 0.0
    assert abs(comp_trending(100) - 1.0) < 1e-12

    ones = (1.0, 1.0, 1.0, 1.0, 1.0)
    assert sql_score(ones, (1, 1, 1, 1, 1)) == 100
    assert sql_score(ones, (0, 0, 0, 0, 1)) == 100
    assert sql_score((0, 0, 0, 0, 1.0), (1, 1, 1, 1, 1)) == 20  # round(20)
    assert sql_score((0, 0, 0, 0, 0), (1, 1, 1, 1, 1)) == 0

    rows = [(50, 1, "b"), (100, 0, "z"), (100, 5, "a"), (50, 9, "c")]
    rows.sort(key=lambda t: (-t[0], -t[1], str(t[2])))
    assert rows == [(100, 5, "a"), (100, 0, "z"), (50, 9, "c"), (50, 1, "b")]

    grid = grid_params()
    assert len(grid) == 7 ** 5
    assert {k: HAND[k] for k in W_KEYS} in grid
    assert {k: POPULARITY_PARAMS[k] for k in W_KEYS} != \
        {k: HAND[k] for k in W_KEYS}

    # pick_feed: tie → personalisasi (tuned) menang atas popularity
    tie = {n: {"@10": {"ndcg": 1.0, "hr": 1.0}}
           for n in ("sql_tuned", "sql_hand", "sql_popularity")}
    assert pick_feed(tie) == "sql_tuned"
    win_pop = {"sql_tuned": {"@10": {"ndcg": 0.5, "hr": 0.5}},
               "sql_hand": {"@10": {"ndcg": 0.5, "hr": 0.5}},
               "sql_popularity": {"@10": {"ndcg": 0.9, "hr": 0.9}}}
    assert pick_feed(win_pop) == "sql_popularity"


if __name__ == "__main__":
    main()
