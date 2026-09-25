#!/usr/bin/env python3
"""Aktivasi model rekomendasi terpilih — idempoten.

Sumber keputusan UTAMA (pasca parity opsi C): manifest terakhir
`feed_runs/*` dari tune_feed_weights.py — evaluasi dengan formula SQL
serving yang sama (val=tuning, test=pemilihan; gate CP-02 A8:
kandidat hanya menang bila NDCG test ≥ baseline, coverage tak turun).
model_versions.metrics = metrik test evaluator SQL-parity;
model_params.params = bobot feed terpilih (ADR-005).

Fallback (bila feed_runs kosong): run_baselines terakhir + PARAMS legacy
CP-04B, dengan peringatan.

Usage: python3 experiments/recommendation/activate_model.py [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import run_sql  # noqa: E402

SERVICE = run_sql.field("SERVICE_ROLE")
SUPA = f"https://{run_sql.REF}.supabase.co"

# Fallback legacy CP-04B (hanya dipakai bila belum ada run SQL-parity).
PARAMS = {
    "w_budget": 0.245,
    "w_campus": 0.21,
    "w_facility": 0.105,
    "w_rating": 0.14,
    "w_trending": 0.3,
    "hybrid_alpha": 0.7,
}
# Nama model_versions per kandidat evaluator SQL-parity.
FEED_NAME = {"sql_popularity": "popularity", "sql_hand": "hybrid",
             "sql_tuned": "hybrid"}


def req(method: str, path: str, body=None) -> list | dict:
    r = urllib.request.Request(
        f"{SUPA}/{path}",
        data=json.dumps(body).encode() if body is not None else None,
        headers={"apikey": SERVICE, "Authorization": f"Bearer {SERVICE}",
                 "Content-Type": "application/json",
                 "Prefer": "return=representation"},
        method=method)
    with urllib.request.urlopen(r, timeout=60) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else []


def latest_run() -> tuple[str, dict]:
    runs = sorted(p for p in (ROOT / "experiments/recommendation/runs").iterdir()
                  if (p / "metrics.json").exists())
    if not runs:
        raise SystemExit("tidak ada run — jalankan run_baselines.py dulu")
    run = runs[-1]
    metrics = json.loads((run / "metrics.json").read_text())
    manifest = json.loads((run / "manifest.json").read_text())
    if not manifest.get("deterministic_rerun"):
        raise SystemExit("run terakhir belum lulus determinism — jangan aktifkan")
    return f"experiments/recommendation/runs/{run.name}", metrics


def pick(metrics: dict) -> str:
    """[fallback] NDCG@10 tertinggi; tie → personalisasi > popularity."""
    best, name = -1.0, None
    for cand in ("hybrid", "content_based", "popularity"):
        n = metrics[cand]["@10"]["ndcg"]
        if n > best + 1e-12:
            best, name = n, cand
    return name or "popularity"


def feed_selection() -> dict | None:
    """Pemilihan utama: manifest feed_runs terakhir (evaluator SQL-parity)."""
    d = ROOT / "experiments/recommendation/feed_runs"
    runs = sorted(p for p in d.iterdir()
                  if (p / "manifest.json").exists()) if d.exists() else []
    if not runs:
        return None
    run = runs[-1]
    man = json.loads((run / "manifest.json").read_text())
    if not man.get("deterministic_rerun"):
        raise SystemExit("feed run terakhir belum lulus determinism")
    met = json.loads((run / "metrics.json").read_text())
    chosen = man["chosen_candidate"]
    return {
        "name": FEED_NAME[chosen],
        "chosen_candidate": chosen,
        "params": man["feed_params"],
        "metrics": met["test"][chosen],
        "artifact": f"experiments/recommendation/feed_runs/{run.name}",
        "dataset_version": man["dataset_version"],
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    sel = feed_selection()
    if sel:
        chosen, params = sel["name"], sel["params"]
        row = {"kind": "recommender", "name": chosen,
               "artifact_uri": sel["artifact"], "metrics": sel["metrics"],
               "dataset_version": sel["dataset_version"], "seed": 42,
               "status": "active"}
        source = f"sql-parity ({sel['chosen_candidate']})"
        if chosen == "popularity":
            print("catatan: menang = popularity terfilter (CP-02 A8; "
                  "kandidat berbobot tidak mengalahkan baseline di test)")
    else:
        print("PERINGATAN: feed_runs kosong — fallback run_baselines + "
              "PARAMS legacy CP-04B")
        artifact, metrics = latest_run()
        chosen, params = pick(metrics), PARAMS
        row = {"kind": "recommender", "name": chosen, "artifact_uri": artifact,
               "metrics": metrics[chosen],
               "dataset_version": manifest_dataset(artifact), "seed": 42,
               "status": "active"}
        source = "legacy run_baselines"

    if args.dry_run:
        print(json.dumps({"source": source, "chosen": chosen, "row": row,
                          "params": params}, indent=2))
        return

    # archive aktif lama (unique partial index hanya mengizinkan 1 active)
    for old in req("GET", "rest/v1/model_versions?kind=eq.recommender"
                          "&status=eq.active&select=id,name"):
        req("PATCH", f"rest/v1/model_versions?id=eq.{old['id']}",
            {"status": "archived"})
        print(f"archived aktif lama: {old['name']}")

    existing = req("GET", f"rest/v1/model_versions?kind=eq.recommender"
                          f"&name=eq.{chosen}&select=id")
    if existing:
        mid = existing[0]["id"]
        req("PATCH", f"rest/v1/model_versions?id=eq.{mid}",
            {k: row[k] for k in ("artifact_uri", "metrics", "dataset_version",
                                 "seed", "status")})
    else:
        mid = req("POST", "rest/v1/model_versions", row)[0]["id"]

    # upsert params (hanya komponen yang dibaca SQL feed)
    feed_keys = {k: params[k] for k in
                 ("w_budget", "w_campus", "w_facility", "w_rating",
                  "w_trending") if k in params}
    have = req("GET", f"rest/v1/model_params?model_version_id=eq.{mid}"
                      "&select=model_version_id")
    if have:
        req("PATCH", f"rest/v1/model_params?model_version_id=eq.{mid}",
            {"params": feed_keys})
    else:
        req("POST", "rest/v1/model_params",
            {"model_version_id": mid, "params": feed_keys})

    check = req("GET", "rest/v1/model_versions?kind=eq.recommender"
                       "&status=eq.active&select=name,dataset_version")
    print(json.dumps({"source": source, "activated": chosen,
                      "model_version_id": mid, "active_now": check,
                      "params": feed_keys}, indent=2))


def manifest_dataset(artifact: str) -> str:
    man = ROOT / artifact / "manifest.json"
    return json.loads(man.read_text())["dataset_version"]


if __name__ == "__main__":
    main()
