#!/usr/bin/env python3
"""Baseline rekomendasi (CP-03B): popularity + content-based.

- Split temporal 70/10/20 (CP-02 A6) — tanpa leakage masa depan.
- Kandidat = hard filter preferensi user (CP-02 A1); jika menyaring test
  positif, jumlahnya dicatat sebagai n_test_positives_filtered (jujur).
- Metrik (CP-02 A7): P@K, R@K, NDCG@K, HitRate@K (K=5,10), coverage katalog
  & user, subgroup cold-start (<5 event train).
- Skor = ranking, BUKAN probabilitas (FR-REC-04).
- Deterministik: dua run seed sama → metrik identik (NFR-ML-01).

Usage:
  python3 experiments/recommendation/run_baselines.py
  python3 experiments/recommendation/run_baselines.py --register  # + model_versions (draft)
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import subprocess
import sys

import numpy as np
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw"
RUNS = pathlib.Path(__file__).resolve().parent / "runs"
SEED = 42
KS = (5, 10)
# Design parameter hipotesis (AGENTS §11.3) — diuji di eksperimen lanjutan.
WEIGHTS = {"impression": 0, "view": 1, "save": 3, "compare": 2,
           "tenancy_request": 5, "tenancy_accepted": 8}


def _point(v) -> tuple[float, float] | None:
    """PostGIS geography keluaran PostgREST: dict GeoJSON / hex EWKB / WKT."""
    if v is None:
        return None
    if isinstance(v, dict) and v.get("type") == "Point":
        lng, lat = v["coordinates"][:2]
        return float(lat), float(lng)
    if isinstance(v, (bytes, bytearray)) or (
        isinstance(v, str) and v.startswith(("\\x", "0101", "0001"))
    ):
        b = bytes.fromhex(v[2:] if isinstance(v, str) and v.startswith("\\x")
                          else (v if isinstance(v, str) else v.hex()))
        endian = "<" if b[0] == 1 else ">"
        gtype = int.from_bytes(b[1:5], "little" if b[0] == 1 else "big")
        srid = int.from_bytes(b[5:9], "little" if b[0] == 1 else "big")
        off = 9 if gtype & 0x20000000 else 5
        lat, lng = np.frombuffer(b[off:off + 16], dtype=endian + "f8")
        return float(lat), float(lng)
    if isinstance(v, str) and v.upper().startswith("POINT"):
        lng, lat = v[v.index("(") + 1:v.index(")")].split()[:2]
        return float(lat), float(lng)
    return None


def _haversine(lat1, lon1, lat2, lon2):
    r = 6371000.0
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dp = p2 - p1
    dl = np.radians(lon2 - lon1)
    a = np.sin(dp / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(dl / 2) ** 2
    return 2 * r * np.arcsin(np.sqrt(a))


def load():
    def rd(name: str) -> pd.DataFrame:
        return pd.read_parquet(RAW / f"{name}.parquet")

    events, props, rooms = rd("events"), rd("properties"), rd("rooms")
    pf, facs, camps = rd("property_facilities"), rd("facilities"), rd("campuses")
    revs, owners, prefs = rd("reviews"), rd("owner_profiles"), rd("user_preferences")

    rooms_avail = rooms[rooms["status"] == "available"]
    price_from = rooms.groupby("property_id")["price"].min().rename("price_any")
    price_avail = rooms_avail.groupby("property_id")["price"].min().rename("price_from")
    item = props.set_index("id").join([price_from, price_avail])
    item["price_from"] = item["price_from"].fillna(item["price_any"])

    item["facility_ids"] = (
        pf.groupby("property_id")["facility_id"]
        .apply(lambda s: sorted(set(s))).to_dict()
    )
    approved = revs[revs["status"] == "approved"]
    item["rating_avg"] = approved.groupby("property_id")["rating_overall"].mean()
    item["rating_count"] = approved.groupby("property_id")["rating_overall"].count()
    item["rating_avg"] = item["rating_avg"].fillna(0.0)
    item["rating_count"] = item["rating_count"].fillna(0).astype(int)
    ver = owners.set_index("user_id")["verification_status"].to_dict()
    item["owner_verified"] = item["owner_id"].map(
        lambda o: ver.get(o) == "verified")
    pts = item["location"].map(_point)
    item["lat"] = [p[0] if p else None for p in pts]
    item["lng"] = [p[1] if p else None for p in pts]

    ref_date = pd.to_datetime(events["occurred_at"], utc=True).max()
    item["listing_age_days"] = (
        (ref_date - pd.to_datetime(item["created_at"], utc=True)).dt.days)

    camp_pts = {r["id"]: _point(r["location"]) for _, r in camps.iterrows()}
    facility_ids = sorted(facs["id"].tolist())
    fac_idx = {f: i for i, f in enumerate(facility_ids)}

    events = events.copy()
    events["occurred_at"] = pd.to_datetime(events["occurred_at"], utc=True)
    events["event_weight"] = events["event_weight"].fillna(0).astype(float)
    events = events.sort_values(
        ["occurred_at", "user_id", "property_id", "event_type", "session_id"]
    ).reset_index(drop=True)
    prefs = prefs.set_index("user_id")
    return events, item, prefs, camp_pts, fac_idx


def temporal_split(events: pd.DataFrame) -> pd.DataFrame:
    n = len(events)
    n_train, n_val = int(0.7 * n), int(0.9 * n)
    ev = events.copy()
    ev["split"] = "test"
    ev.iloc[:n_train, ev.columns.get_loc("split")] = "train"
    ev.iloc[n_train:n_val, ev.columns.get_loc("split")] = "val"
    return ev


def build_item_matrix(item: pd.DataFrame, fac_idx: dict) -> np.ndarray:
    price = item["price_from"].astype(float).fillna(item["price_from"].median())
    pmin, pmax = float(price.min()), float(price.max())
    mat = []
    for pid, row in item.iterrows():
        vec = np.zeros(len(fac_idx) + 2, dtype=float)
        flist = row["facility_ids"]
        for f in (flist if isinstance(flist, (list, np.ndarray)) else []):
            if f in fac_idx:
                vec[fac_idx[f]] = 1.0
        vec[-2] = (row["price_from"] - pmin) / max(pmax - pmin, 1.0)
        vec[-1] = float(row["rating_avg"]) / 5.0
        mat.append(vec)
    return np.vstack(mat)


def eligible_users(ev: pd.DataFrame, item, prefs, camp_pts) -> dict:
    """Eval user = punya minimal 1 positif test (weight>0)."""
    pos_test = ev[(ev["split"] == "test") & (ev["event_weight"] > 0)]
    return sorted(pos_test["user_id"].unique())


def candidates_for(uid, item, prefs, camp_pts, fac_idx) -> list:
    cands = item[(item["listing_status"] == "active")
                 & (item["verification_status"] == "verified")]
    p = prefs.loc[uid] if uid in prefs.index else None
    if p is not None:
        lo, hi = p.get("budget_min"), p.get("budget_max")
        if pd.notna(lo) and pd.notna(hi):
            cands = cands[(cands["price_from"] >= lo) & (cands["price_from"] <= hi)]
        gp = p.get("gender_preference")
        if pd.notna(gp):
            cands = cands[(cands["gender_policy"] == "any")
                          | (cands["gender_policy"] == gp)]
        cid, maxd = p.get("primary_campus_id"), p.get("max_distance_m")
        if pd.notna(cid) and cid in camp_pts and pd.notna(maxd):
            clat, clng = camp_pts[cid]
            mask = cands.apply(
                lambda r: pd.isna(r["lat"])
                or _haversine(r["lat"], r["lng"], clat, clng) <= maxd, axis=1)
            cands = cands[mask]
    if cands.empty:
        cands = item[(item["listing_status"] == "active")
                     & (item["verification_status"] == "verified")]
    return list(cands.index)


def user_vector(uid, ev_train, item_vec, item, prefs, fac_idx) -> np.ndarray:
    hist = ev_train[ev_train["user_id"] == uid]
    dim = item_vec.shape[1]
    prefs_vec = np.zeros(dim)
    p = prefs.loc[uid] if uid in prefs.index else None
    if p is not None:
        fp = p.get("facility_priority")
        if isinstance(fp, (list, np.ndarray)):
            for f in fp:
                if f in fac_idx:
                    prefs_vec[fac_idx[f]] = 1.0
        lo, hi = p.get("budget_min"), p.get("budget_max")
        if pd.notna(lo) and pd.notna(hi):
            price = item["price_from"].astype(float)
            pmin, pmax = float(price.min()), float(price.max())
            prefs_vec[-2] = (((lo + hi) / 2) - pmin) / max(pmax - pmin, 1.0)
    if hist.empty:
        return prefs_vec
    w = hist["event_weight"].astype(float).clip(lower=0)
    w = w.replace(0, 0.0)
    idx = item.index.get_indexer(hist["property_id"])
    hv = (item_vec[idx] * w.to_numpy()[:, None]).sum(axis=0) / max(w.sum(), 1e-9)
    alpha = min(1.0, len(hist) / 10.0)
    return alpha * hv + (1 - alpha) * prefs_vec


def geo_score(uid, cand_ids, item, prefs, camp_pts) -> np.ndarray:
    p = prefs.loc[uid] if uid in prefs.index else None
    if p is None or pd.isna(p.get("primary_campus_id")):
        return np.full(len(cand_ids), 0.5)
    cid = p["primary_campus_id"]
    if cid not in camp_pts:
        return np.full(len(cand_ids), 0.5)
    clat, clng = camp_pts[cid]
    sub = item.loc[cand_ids]
    d = sub.apply(
        lambda r: _haversine(r["lat"], r["lng"], clat, clng)
        if pd.notna(r["lat"]) else np.nan, axis=1).to_numpy(dtype=float)
    maxd = float(p.get("max_distance_m") or 3000)
    closeness = 1.0 - np.nan_to_num(d / maxd, nan=0.5, posinf=1.0)
    return np.clip(closeness, 0.0, 1.0)


def rank_popularity(cand_ids, pop: pd.Series) -> list:
    sc = pd.Series({c: float(pop.get(c, 0.0)) for c in cand_ids})
    return list(sc.sort_values(ascending=False, kind="stable").index)


def rank_content(uid, cand_ids, item_vec, item, ev_train, prefs, camp_pts, fac_idx) -> list:
    u = user_vector(uid, ev_train, item_vec, item, prefs, fac_idx)
    x = item_vec[item.index.get_indexer(cand_ids)]
    denom = np.linalg.norm(u) * np.linalg.norm(x, axis=1)
    cos = np.divide(x @ u, denom, out=np.zeros(len(cand_ids)), where=denom > 0)
    score = 0.8 * cos + 0.2 * geo_score(uid, cand_ids, item, prefs, camp_pts)
    order = np.argsort(-score, kind="stable")
    return [cand_ids[i] for i in order]


def metrics_at_k(recs: list, relevant: set, k: int) -> dict:
    top = recs[:k]
    hits = [1 if r in relevant else 0 for r in top]
    p = sum(hits) / k
    r = sum(hits) / len(relevant) if relevant else 0.0
    dcg = sum(h / np.log2(i + 2) for i, h in enumerate(hits))
    ideal = [1] * min(len(relevant), k)
    idcg = sum(1 / np.log2(i + 2) for i in range(len(ideal)))
    ndcg = dcg / idcg if idcg > 0 else 0.0
    hr = 1.0 if any(hits) else 0.0
    return {"p": p, "r": r, "ndcg": ndcg, "hr": hr}


def evaluate(ranked_fn, ev, item, prefs, camp_pts, fac_idx, item_vec) -> dict:
    train = ev[ev["split"] == "train"]
    pop = train.groupby("property_id")["event_weight"].sum()
    pos_test = ev[(ev["split"] == "test") & (ev["event_weight"] > 0)]
    eval_users = sorted(pos_test["user_id"].unique())
    n_filtered = 0
    per_k = {k: [] for k in KS}
    cold_k = {k: [] for k in KS}
    all_recs: set = set()
    users_with_rec = 0
    train_counts = train.groupby("user_id").size().to_dict()

    for uid in eval_users:
        cands = candidates_for(uid, item, prefs, camp_pts, fac_idx)
        rel = set(pos_test[pos_test["user_id"] == uid]["property_id"]) & set(cands)
        n_filtered += len(
            set(pos_test[pos_test["user_id"] == uid]["property_id"]) - set(cands))
        if not rel:
            continue
        recs = ranked_fn(uid, cands, pop, train, item_vec)
        if recs:
            users_with_rec += 1
        all_recs |= set(recs)
        cold = train_counts.get(uid, 0) < 5
        for k in KS:
            per_k[k].append(metrics_at_k(recs, rel, k))
            if cold:
                cold_k[k].append(metrics_at_k(recs, rel, k))

    def agg(rows):
        if not rows:
            return None
        return {m: float(np.mean([r[m] for r in rows]))
                for m in ("p", "r", "ndcg", "hr")}

    out = {f"@{k}": agg(per_k[k]) for k in KS}
    out["coverage_catalog"] = len(all_recs) / len(item) if len(item) else 0.0
    out["coverage_user"] = (users_with_rec / len(eval_users)) if eval_users else 0.0
    out["n_eval_users"] = len(eval_users)
    out["n_test_positives_filtered"] = int(n_filtered)
    out["cold_start"] = {f"@{k}": agg(cold_k[k]) for k in KS}
    out["n_cold_users"] = sum(
        1 for uid in eval_users if train_counts.get(uid, 0) < 5)
    return out


def run_once() -> dict:
    np.random.seed(SEED)
    events, item, prefs, camp_pts, fac_idx = load()
    ev = temporal_split(events)
    item_vec = build_item_matrix(item, fac_idx)

    def pop_fn(uid, cands, pop, train, _):
        return rank_popularity(cands, pop)

    def cb_fn(uid, cands, pop, train, ivec):
        return rank_content(uid, cands, ivec, item, train, prefs, camp_pts, fac_idx)

    return {
        "popularity": evaluate(pop_fn, ev, item, prefs, camp_pts, fac_idx, item_vec),
        "content_based": evaluate(cb_fn, ev, item, prefs, camp_pts, fac_idx, item_vec),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--register", action="store_true",
                    help="tulis baris model_versions (status=draft)")
    args = ap.parse_args()

    version = (RAW / "DATASET_VERSION.txt").read_text().strip()
    m1 = run_once()
    m2 = run_once()
    same = json.dumps(m1, sort_keys=True) == json.dumps(m2, sort_keys=True)
    if not same:
        raise SystemExit("DETERMINISM FAIL: dua run seed sama berbeda")

    try:
        commit = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
            text=True, check=True).stdout.strip()
        dirty = bool(subprocess.run(
            ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True,
            text=True, check=True).stdout.strip())
    except Exception:
        commit, dirty = "unknown", None

    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = RUNS / ts
    run_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "dataset_version": version,
        "git_commit": commit,
        "git_dirty": dirty,
        "seed": SEED,
        "split": "temporal 70/10/20",
        "ks": list(KS),
        "interaction_weights": WEIGHTS,
        "params": {"cb_geo_weight": 0.2, "cb_cos_weight": 0.8,
                   "cb_history_alpha_events": 10},
        "deterministic_rerun": same,
        "timestamp_utc": ts,
        "data_note": "dataset dev sintetis seed — BUKAN production data",
    }
    (run_dir / "metrics.json").write_text(json.dumps(m1, indent=2, sort_keys=True))
    (run_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(json.dumps({"manifest": manifest, "metrics": m1}, indent=2, sort_keys=True))

    if args.register:
        sys.path.insert(0, str(ROOT / "scripts"))
        for name, metrics in m1.items():
            body = {
                "kind": "recommender",
                "name": f"baseline-{name}",
                "artifact_uri": f"experiments/recommendation/runs/{ts}",
                "metrics": metrics,
                "dataset_version": version,
                "seed": SEED,
                "status": "draft",
            }
            print(f"register baseline-{name}: HTTP {_post(body)}")

    print(f"\nrun dir: {run_dir.relative_to(ROOT)}  determinism=PASS")


def _post(body: dict) -> str:
    import urllib.request
    sys.path.insert(0, str(ROOT / "scripts"))
    import run_sql as rs
    req = urllib.request.Request(
        f"https://{rs.REF}.supabase.co/rest/v1/model_versions",
        data=json.dumps(body).encode(),
        headers={"apikey": rs.field("SERVICE_ROLE"),
                 "Authorization": f"Bearer {rs.field('SERVICE_ROLE')}",
                 "Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return f"{resp.status}"


if __name__ == "__main__":
    main()
