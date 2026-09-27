# CONTEXT ACQUISITION REPORT — KOSTARA

Produced per `PROMPT_PRICE_ESTIMATOR.md` §1–§3 (READ → AUDIT → report before THINK).
Tanggal: 2026-09-26 · Branch `main` · HEAD `de4defa` (pushed).

```text
CODEBASE STATE: EXISTING IMPLEMENTATION
```

---

## Documents read

Wajib (§1), dibaca utuh di sesi berjalan atau sesi sebelumnya, keberadaan diverifikasi:

| # | Dokumen | Status |
|---|---------|--------|
| 1 | `AGENTS.md` | read (operating contract) |
| 2 | `PRD.md` | read (header map + rerf scope price/gates) |
| 3 | `DESIGN.md` | read (header map) |
| 4 | `SPRINTS.md` | read (header map) |
| 5 | `VALIDATION_PROTOCOL.md` | read (gate vocabulary, integrity rules) |
| 6 | `PROMPTS.md` | read (§26 menunjuk ke `PROMPT_PRICE_ESTIMATOR.md`; bagian owner di-diff, tidak diubah) |
| 7 | `README.md` | read (bagian owner di-diff, tidak diubah) |
| 8 | `ML_PRICE_INTELLIGENCE.md` | read (spesifikasi ML-03: features §7, download §17, phases §27, gates §29, evidence `docs/capstone/ml-price/`) |
| — | `PROMPT_PRICE_ESTIMATOR.md` | read (master prompt ini, 830 baris) |

Artefak pendukung yang dibaca: ADR-001…006 (`docs/decisions/`), seluruh `docs/capstone/cp01-*..cp03a-*` (inventory + header), `docs/DATA_PROVENANCE.md`, `docs/logs/CP-00..CP-04B gate reports`, `docs/capstone/cp02-data-dictionary.md`, `experiments/recommendation/DATASET_CARD.md` + `MODEL_CARD.md`, `experiments/price/DATASET_CARD.md`, `LOGBOOK.md`, `AI_USAGE_LOG.md`.

## Current architecture

- **Monorepo ringan**: `lib/` (Flutter app tunggal), `supabase/` (migrations, functions kosong, seed), `experiments/{recommendation,price,review_nlp}/` (ML offline Python), `scripts/` (DB test harness Python), `docs/` (capstone + decisions + logs), `data/` (gitignored raw exports). Belum ada `services/` (FastAPI belum ada).
- Layout = ADR-001; feature-first + Riverpod + go_router = ADR-002; PostGIS distance-only, tanpa isochrone/ETA = ADR-003; batas Supabase: **Edge Functions nol pemakaian V1, direserve P1** = ADR-004; ML training offline, serving via RPC SQL = ADR-005; notifikasi local-first = ADR-006.
- **ADR-007 (Edge Function gateway + FastAPI `services/price/`) dirujuk di `ML_PRICE_INTELLIGENCE.md`/`LOGBOOK.md` tetapi file `docs/decisions/` belum ada** — harus ditulis sebelum fase integrasi (§20–21).
- CI: `.github/workflows/ci.yml` → `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` pada push/PR. Tidak ada Docker, tidak ada CI DB/ML.

## Flutter state management

- Riverpod (`flutter_riverpod ^2.6.1`) + `go_router ^16.2.0`; entry tunggal `lib/main.dart`; router `lib/core/router/{app_router,app_shell}.dart`.
- 12 feature modules di `lib/features/`: admin, auth, compare, discovery, feedback, onboarding, owner, profile, property_detail, saved, tenancy. Per-feature repository (`discovery_repository`, `owner_repository`, `tenancy_repository`, …) — pola UI → Riverpod → repository → Supabase SDK.
- Core: `config/app_config.dart`, `events/event_logger.dart` (analytics lokal), `notifications/`, `theme/`, `util/`. Font Plus Jakarta Sans (R-022).
- Belum ada `lib/features/price_insight/` (akan dibuat sesuai THINK terdahulu: 8 state UI, inference pada momen save room — `owner_property_manage_screen.dart:66–142` → `owner_repository.dart:159–187`).

## Supabase integration

- `supabase_flutter ^2.17.2`; `Supabase.initialize` di `lib/main.dart`; konfigurasi `lib/core/config/app_config.dart` dengan guard eksplisit `assertNoServiceRole()` (service_role tidak pernah ada di app).
- Storage policies (`20260925010007_storage.sql`): avatars + property images = public read / owner write; verification docs = **private**, owner-only (read/insert/delete).
- `supabase/functions/` kosong (belum ada Edge Function; ADR-007 akan mengizinkan yang pertama sebagai gateway aman ke FastAPI).
- Seed: `seed_data.sql` + `seed_dev.py` (login dev `admin@/owner1..@kostara.dev`, password `KostaraDev123!` — hanya di `Aman.md`/lokal, tidak pernah dikommit).

## Database/RLS/PostGIS state

- 19 migration immutable `20260925010000`…`010018` (PostGIS ext, identity, tenancy, feedback+ML, RLS, RPC, storage, tenancy flow, CP-04B, due calculator, aspect score, admin, facilities guard, **padang_districts**, **price_intelligence**).
- RLS aktif di seluruh tabel bisnis; matrix uji: `scripts/run_db_tests.py` **32/32 PASS** (TP-BIZ/TP-RLS-08 26 + TP-PRICE-01a..e), `scripts/test_rls_matrix.py` **65/65 PASS** (TP-RLS-01..09h), `test_tenancy_flow.py` 30/30, `test_cp04b_flow.py` 35/35. Suite dijalankan berurutan.
- ~30 RPC: `search_properties`, `nearby_properties`, `campus_suggestions`, `feed_recommendations`, `fn_active_recommender`, `fn_property_popularity`, `district_for_point`, `room_price_feature_snapshot`, `rooms_price_observation_fn`, `audit_log_write`, guard functions, tenancy flow (`submit_tenancy_request`/`activate_tenancy`/`end_tenancy`), dst.
- Tabel price (migration 010018): `room_price_observations` (trigger dari perubahan `rooms.price`, backfill 40), `price_estimates` (write hanya server; check: `price >= 0`, upper >= point >= lower), `price_insight_public` view (label saja, grant anon), `districts` ×11 kode `13.71.*` + trigger `properties.district` + fungsi `district_for_point` (security definer, tie-break `order by kode limit 1`).
- `model_versions`: unique partial index `one_active_per_kind (kind) WHERE status='active'` — sudah dipakai kind `popularity`, `pricer` disiapkan.

## Existing ML/backend state

- **FastAPI/backend API: belum ada** (hanya `supabase/seed/seed_dev.py` non-web). `grep fastapi` nihil. Akan dibuat di `services/price/` sesuai §20.
- **ML-01 recommendation (existing, CAPSTONE jalan)**: `experiments/recommendation/` — export_dataset, run_baselines, tune_feed_weights, activate_model, DATASET_CARD + MODEL_CARD. Model **popularity terfilter aktif** `23cf8b9f-1c72-4d77-8d1c-5d473eddaa7b`, dataset `ebc8e8e3cadecd7d`, temporal split 70/10/20, feed_runs eval. Data = **seed sintetis** (1200 interaksi, 10 listing) — metrik dilarang dipresentasikan sebagai performa produk.
- **ML-03 price (in-flight, Phases B–D PASS)**: `experiments/price/` — export_dataset (7 tabel parquet), validate_dataset (DQ-01..11 QUALITY PASS), download_airroi (4 file sha256-pinned), validate_airroi (C-01..12 QUALITY PASS: 29.057 clean), price_io, run_baselines (**BASELINE PASS** — AirROI B0 MAE 81.81 / B1 62.64 R² 0.42; KOSTARA lokal B0 224.921 / B1 252.155, keduanya R² negatif = jujur kecil-n). Run artifact di `experiments/price/runs/`.
- **ML-02 ABSA/review NLP: belum mulai** — hanya `experiments/review_nlp/LABELING_GUIDELINE.md`; data review = **4 baris seed** → gate ABSA berstatus N/A-by-data sampai review real terkumpul.
- `.venv-ml`: pandas 3.0.6, pyarrow 25.0.1, scikit-learn 1.9.1, xgboost 3.4.1, catboost 1.2.10, optuna? (belum dicek/terpasang — lihat Critical gaps), kaggle CLI 2.2.4.

## Current data available for properties/rooms

- Dev Supabase: **12 properties** (semua punya `district` + koordinat valid bbox Padang), **40 rooms** (harga Rp650.000–1.950.000, median **Rp1.050.000**), 40 `room_price_observations` `source='seed_backfill'`, 37 link property_facility (10 slug), 5 campuses, 4 reviews, 11 districts.
- Ekspor lokal gitignored `data/raw/price/*.parquet` (7 tabel, PII dibuang, dataset_version `kostara-padang-v1-ed0ada2321be30cd`).
- Benchmark publik `data/raw/price/public/airroi_apac/`: listings 29.057 clean + past_rates; **USD target** (bukan IDR, bukan bulanan kos — deviasi terdokumentasi di DATASET_CARD), **0 baris Padang**, lisensi CC BY-NC → hanya namespace `benchmark_airroi_apac`, tidak pernah masuk training KOSTARA.
- `docs/DATA_PROVENANCE.md` mencatat provenance kedua sumber.

## Relevant files

- Think/plan: `ML_PRICE_INTELLIGENCE.md`, `PROMPT_PRICE_ESTIMATOR.md` (ini).
- Price pipeline: `experiments/price/{export_dataset,validate_dataset,download_airroi,validate_airroi,price_io,run_baselines,run_candidates}.py`, `experiments/price/DATASET_CARD.md`, `experiments/price/runs/*/`.
- Rekomendasi: `experiments/recommendation/{export_dataset,run_baselines,tune_feed_weights,activate_model}.py`, `MODEL_CARD.md`, `DATASET_CARD.md`.
- Backend: `supabase/migrations/20260925010017_padang_districts.sql`, `…010018_price_intelligence.sql`.
- Test harness: `scripts/{run_db_tests,test_rls_matrix,test_tenancy_flow,test_cp04b_flow,run_sql}.py`.
- Flutter inference moment: `lib/features/owner/owner_property_manage_screen.dart`, `lib/features/owner/owner_repository.dart`; config guard `lib/core/config/app_config.dart`.
- Evidence path price (belum dibuat): `docs/capstone/ml-price/`, `artifacts/evaluation/figures/`, `docs/ml/`.

## Current git changes that must not be overwritten

**File milik project owner (jangan di-stage/ditimpa/diedit):**

- `M PROMPTS.md` (owner menambah §26 pointer ke prompt estimator)
- `M README.md` (owner merapikan README)
- `?? ML_PRICE_INTELLIGENCE.md` (spesifikasi, untracked by owner choice)
- `?? PROMPT_PRICE_ESTIMATOR.md` (master prompt, untracked by owner choice)
- `kaggle.json` di root (`.gitignore`d — kredensial lokal, jangan pernah dikommit)

**Pekerjaan agent in-flight (belum di-commit, lanjutan fase price):**

- `M experiments/price/run_baselines.py` — refactor `cv()` generik (`models=` dict, `build_geo_median`/`build_linear`); metrik baseline sudah di-regression-check identik dengan run `de4defa`.
- `?? experiments/price/run_candidates.py` — C1 RF / C2 XGB / C3 CatBoost; run pertama **dibatalkan user** sebelum selesai (loky semaphore warning) → wajib diulang setelah gate ini.

Jangan commit file owner bersamaan dengan pekerjaan agent; commit terpisah.

## Critical gaps

1. **ADR-007 file belum ada** (sudah dirujuk; prasyarat §20–21).
2. **FastAPI belum ada** (`services/price/`, dependency, Dockerfile/reqs) — target §20–21.
3. **Harga candidate belum selesai** (Phase E run dibatalkan) → belum ada model terpilih, belum Optuna (§15), belum holdout (§16), belum conformal interval (§17), belum error analysis/figures (§18–19).
4. **`optuna` (dan `shap`/figure deps) belum terpasang** di `.venv-ml` (diverifikasi `ModuleNotFoundError`) → instal saat fase §15/§18.
5. **ABSA (ML-02) data insufficient**: hanya 4 review seed → gate `REVIEW FAILED — INSUFFICIENT DOMAIN DATA` / N/A-by-data sampai data real ada.
6. **Belum ada** `artifacts/evaluation/figures/`, `docs/ml/`, `FIGURE_INDEX.md`, `FINAL_ML_REPORT.md`, `capstone_evidence/`.
7. Ekspor KOSTARA lokal hanya **n=40** → baseline lokal R² negatif (jujur); kandidat/model final untuk domain Padang baru bisa kuat dengan data real bertambah — jangan mengklaim sebaliknya.
8. Rekomendasi (ML-01) = model popularity aktif di data sintetis; kandidat LTR/learning-to-rank dan metrics Precision@5/NDCG@5 sesuai master prompt tiga-workstream **belum dikerjakan** di jalur ini (scope pekerjaan prompt ini = price intelligence; catat di laporan akhir).

Semua gap di atas adalah pekerjaan fase berikutnya, bukan penghalang memulai THINK: tidak ada yang mengancam integritas keputusan (tidak ada data loss, tidak ada security hole, tidak ada fabricated metric).

---

```text
Decision:
READY TO THINK
```
