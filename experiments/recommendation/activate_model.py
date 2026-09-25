#!/usr/bin/env python3
"""Aktivasi model rekomendasi terpilih (CP-04B) — idempoten.

Pemilihan berbasis evidence run terakhir (runs/*/metrics.json):
kandidat dengan NDCG terbaik (tie-break: personalization > pure popularity)
di-activate sebagai satu-satunya baris `status=active` per kind
(unique index di DB menegakkan), model_params = mapping bobot SQL
(ADR-005: skor feed = parameter SQL, bukan model terpisah).

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

# Mapping hybrid (α=0.7 content / 0.3 popularity) → bobot feed SQL.
# Signal family yang sama (budget/kampus/fasilitas/rating vs trending);
# formula tidak identik — didokumentasikan di MODEL_CARD.md.
PARAMS = {
    "w_budget": 0.245,
    "w_campus": 0.21,
    "w_facility": 0.105,
    "w_rating": 0.14,
    "w_trending": 0.3,
    "hybrid_alpha": 0.7,
}


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
    """NDCG@10 tertinggi; tie → kandidat dengan sinyal personalisasi
    (hybrid > content > popularity) sesuai FR-ML-03 (popularity = fallback)."""
    best, name = -1.0, None
    for cand in ("hybrid", "content_based", "popularity"):
        n = metrics[cand]["@10"]["ndcg"]
        if n > best + 1e-12:
            best, name = n, cand
    return name or "popularity"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    artifact, metrics = latest_run()
    chosen = pick(metrics)
    if chosen == "popularity":
        print("catatan: kandidat menang = popularity (tanpa personalisasi)")
    row = {
        "kind": "recommender",
        "name": chosen,
        "artifact_uri": artifact,
        "metrics": metrics[chosen],
        "dataset_version": manifest_dataset(artifact),
        "seed": 42,
        "status": "active",
    }
    if args.dry_run:
        print(json.dumps({"chosen": chosen, "row": row, "params": PARAMS},
                         indent=2))
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

    # upsert params
    have = req("GET", f"rest/v1/model_params?model_version_id=eq.{mid}"
                      "&select=model_version_id")
    if have:
        req("PATCH", f"rest/v1/model_params?model_version_id=eq.{mid}",
            {"params": PARAMS})
    else:
        req("POST", "rest/v1/model_params",
            {"model_version_id": mid, "params": PARAMS})

    check = req("GET", "rest/v1/model_versions?kind=eq.recommender"
                       "&status=eq.active&select=name,dataset_version")
    print(json.dumps({"activated": chosen, "model_version_id": mid,
                      "active_now": check, "params": PARAMS}, indent=2))


def manifest_dataset(artifact: str) -> str:
    man = ROOT / artifact / "manifest.json"
    return json.loads(man.read_text())["dataset_version"]


if __name__ == "__main__":
    main()
