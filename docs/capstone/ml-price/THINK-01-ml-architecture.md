# THINK-01 — ML Architecture: Rental Price Intelligence (KOSTARA)

Gate §7 `PROMPT_PRICE_ESTIMATOR.md` · 2026-09-26 · HEAD `de4defa`
Status: **PASS (coherent)** — Training Phase E boleh dimulai.

## Problem / use case

Estimasi **rentang harga sewa bulanan yang sebanding** (comparable monthly rent range) untuk satu kamar kos Padang, dipakai saat owner menyimpan/mengedit listing. Posisi harga terhadap rentang komparabel:
`BELOW_COMPARABLE_RANGE | WITHIN_COMPARABLE_RANGE | ABOVE_COMPARABLE_RANGE | INSUFFICIENT_DATA`.
Bukan klaim harga "adil/objektif benar" (ML_PRICE_INTELLIGENCE §4).

## Inference moment in product

Simpan/edit kamar: `owner_property_manage_screen.dart:66–142` → `owner_repository.dart:159–187`
→ (async) trigger/Edge Function → FastAPI → tulis `price_estimates` (server-only)
→ Flutter membaca `price_insight_public` (view label-only, grant anon) → tampil sebagai insight,
**tidak pernah menimpa harga milik owner secara otomatis**.

## Unit of analysis

Satu baris = `room_type × observation_time` (§8).
- Training lokal: 40 observasi kamar (12 property, 12 group).
- Benchmark dev AirROI: 1 baris = listing (target nightly USD) — pipeline/matern saja, **tidak pernah digabung** ke target KOSTARA.

## Target variable

- Utama: `monthly_price` (IDR, kolom `rooms.price` → `room_price_observations.monthly_price`, trigger backfill 40).
- Varian wajib diuji (§9): `log1p(monthly_price)` — pilih formulasi dengan CV MAE (IDR setelah `expm1`) terbaik.
- AirROI: `ttm_avg_rate` (USD) di pipeline terpisah `benchmark_airroi_apac`.

## Feature availability at inference time

Tersedia **tepat saat save listing** (semua dari form/DB, tanpa pekerjaan server tambahan):

| Fitur | Sumber |
|---|---|
| `district` | trigger `properties_district_fn` (11 kode 13.71.*) |
| `latitude`, `longitude` | `properties.location` (EWKB) |
| `size_sqm` | `rooms.size_sqm` (40/40 terisi) |
| `room_type` | `rooms.room_type` (single/shared/studio) |
| `gender_policy` | `properties.gender_policy` |
| `deposit` | `rooms.deposit` |
| `amenities_count` + biner fasilitas (wifi, ac, kamar-mandi-dalam, parkir-motor, …) | `property_facilities` (10 slug) |
| `nearest_campus_km` | haversine `properties.location` ↔ `campuses.location` (5 kampus) — sudah ada di `run_candidates.py::local_features` |

**Tidak tersedia di schema V1** (didokumentasikan, tidak diarang): `subdistrict` (NULL V1), `max_occupants`, `electricity_included`, `water_included`, `minimum_stay_months` (kolom tidak ada), `travel_time_to_nearest_campus_min` (butuh routing engine; **tanpa API key ORS → fitur dilewati**, tidak ada ETA palsu, ADR-003/AGENTS §4.5). OSM Sumatra extract tidak diperlukan V1 (koordinat kampus sudah di DB).

## Potential leakage

- Daftar larangan AirROI (DATASET_CARD): `ttm_*`, `l90d_*`, `rating_*`, `num_reviews`, `superhost`, `professional_management`, `number_of_transactions` — **fitur dilarang**.
- Lokal: snapshot fitur hanya atribut listing kini (trigger), tanpa agregat review/interaksi masa depan; split per-group mencegah kamar berbeda di property sama bocor antar fold.
- Benchmark: grouping `city` (deviasi dari group=property_id — terdokumentasi, karena AirROI tak punya property group KOSTARA).

## Data volume

- Lokal: **n=40, 12 group** — kecil, jujur: model kandidat bisa overfit; baseline R² sudah negatif (Phase D).
- Benchmark: **n=29.057 clean, 113 kota** — cukup untuk mematangkan pipeline & framework eksperimen.
- Realita: model final domain Padang **hanya kuat saat data real KOSTARA bertambah**; gate akhir boleh berakhir `REVIEW FAILED — INSUFFICIENT DOMAIN DATA` (diperbolehkan §29). Dilarang mengklaim sebaliknya.

## Data quality

- Lokal: DQ-01..11 **QUALITY PASS** (`runs/20260925T192909Z/dq_report.json`).
- AirROI: C-01..12 **QUALITY PASS** (383 baris korup dibersihkan terdokumentasi; 29.057 = jumlah past_rates persis).

## Group structure

- Lokal: `group = property_id` (12 group; 40 observasi).
- Benchmark: `group = city` (113 → pasca-cleaning; deviasi terdokumentasi).

## Split strategy

- CV: **GroupKFold(n_splits=5)** (§12) — sudah diimplementasi `run_baselines.py::cv` (seed 42).
- Holdout final: **GroupShuffleSplit 20%** group tak tersentuh (fase §16; lokal ≈ 2–3 property / 8 baris — dinyatakan kecil di laporan).
- Tidak ada row-level random split.

## Baseline models

- **B0 GeoMedian**: median target per group geo (distrik lokal / kota benchmark) — fallback aman.
- **B1 LinearRegression**: fitur linear + one-hot. Keduanya **sudah PASS** (Phase D, `runs/20260926T000046Z`).

## Candidate models

- **C1 RandomForestRegressor** (200 tree, impute+onehot)
- **C2 XGBRegressor** (200 tree, scale+onehot)
- **C3 CatBoostRegressor** (500 iter, native `cat_features`)
Semua lewat `cv()` yang sama → `experiments/price/run_candidates.py` (sudah ditulis, run pertama dibatalkan user → ulang).

## Hyperparameter budget

Optuna ≤ **50 trial**, hanya **2 model teratas** CV; stop lebih awal bila perbaikan MAE < **0,5% dalam 10 trial** (§15); seed 42; `n_jobs` dibatasi (hindari kegagalan loky seperti run Phase E sebelumnya).

## Metrics

- Utama: **MAE (IDR)**; pendamping: RMSE, R², MedianAE — per-fold mean±std, hitung dari fold predictions (bukan rerata MAE fold yang berbobot salah).
- Kedua target (`monthly_price` & `log1p`) dibandingkan pada metrik IDR yang sama.
- Benchmark AirROI dilaporkan terpisah, tidak pernah dicampur metrik lokal.

## Prediction interval strategy

**Split conformal 80%** (§17): kalibrasi group-aware di train, evaluasi **coverage empiris real** di holdout. Data tidak cukup (lokal < threshold wajar) → `INSUFFICIENT_DATA` / interval null, tanpa klaim coverage.

## Explainability

Feature importance bawaan tree (gain) → `feature_importance.csv`; ringkasan lokal per fitur untuk laporan.
SHAP **tidak dipasang** → dilewati (catat sebagai keterbatasan), tidak menambah dependensi hanya untuk report.
Bahasa produk: posisi + rentang saja, tanpa klaim kausal per fitur.

## Inference architecture (ADR-007)

```text
Flutter (owner save room)
  → Supabase Edge Function `price-estimate`  ← satu-satunya pemegang service_role + ML_SERVICE_URL/ML_SERVICE_KEY
      → FastAPI `services/price/`  (load artifact + feature compute dari DB via service role)
          → tulis price_estimates (server-only) + model_versions active
  ← price_insight_public (label saja) / RPC
```
- Flutter **tidak pernah** memanggil FastAPI langsung, **tidak pernah** memegang secret (guard `AppConfig.assertNoServiceRole`).
- FastAPI tak punya endpoint publik tanpa otorisasi; kontrak validasi di `docs/ml/FASTAPI_VALIDATION.md` (fase §20).

## Flutter contract

Request: `{property_id, room_id}` (server ambil/derive fitur dari DB — satu sumber kebenaran).
Response `price_estimates`-shaped:
`{lower_bound, point, upper_bound, position, model_version, quality_status, interval_coverage, created_at}`.
UI `lib/features/price_insight/`: `idle | loading | success | insufficientData | offline | serviceUnavailable | invalidListing` (8 state; tanpa auto-overwrite harga owner).

## Supabase / RLS impact

- Tabel/view sudah ada (migrasi `010018`): `room_price_observations` (trigger+backfill 40), `price_estimates` (check constraint + FK), `price_insight_public`, `room_price_feature_snapshot`, `model_versions` + kind `pricer`.
- Matrix hijau: TP-PRICE-01a..e + TP-RLS-09a..h (run_db_tests 32/32, rls_matrix 65/65).
- Perubahan RLS/schema **tidak diperlukan** untuk fase training; Edge Function = pertama (izin ADR-007 → file ADR harus ditulis sebelum §20).

## Rollback / fallback

- Serving: `model_versions` partial unique `one_active_per_kind` → swap aktif = nonaktifkan lama, aktifkan baru (atomik); rollback = aktifkan versi sebelumnya.
- Runtime: FastAPI/Edge Function gagal → Flutter `serviceUnavailable`/`offline`; estimasi terakhir tetap tampil sebagai stale + kualitas statusnya; **B0 district median** (SQL) = baseline aman terakhir.
- Migrasi seluruhnya additive (tidak ada destructive migration yang direncanakan).

## Privacy / security

- Fitur tanpa PII (`owner_id`, `description`, `rules` dibuang saat export).
- Tidak ada data finansial/kartu; tidak ada lokasi background (hanya koordinat listing).
- Secret (Kaggle, service_role, ML_SERVICE_KEY) hanya env/lokal/Edge Function — **tidak pernah di repo/Flutter** (audit scan tiap REVIEW).

## Tests

- Sudah hijau: DQ validators, determinisme baseline (double-run), run_db_tests 32, rls_matrix 65, tenancy 30, cp04b 35, dart format/analyze/test.
- Akan ditambah per fase: unit FastAPI (`/health`, `/v1/model-info`, `/v1/price/estimate` valid/invalid/insufficient), Edge Function auth (tanpa JWT = tolak; JWT non-owner = tolak), widget/unit state price_insight, E2E TC-ML-E2E (§23–25).

## Urutan eksekusi setelah gate ini

1. Phase E ulang: `run_candidates.py` (C1–C3, dua dataset, dua target) → commit + gate candidates.
2. §15 Optuna (pasang `optuna` dulu) → §16 seleksi final → §17 conformal → §18 error analysis → §19 artefak replikabilitas (figur 300 DPI + CSV sumber).
3. §20 tulis `docs/decisions/ADR-007` + FastAPI `services/price/` + contract tests.
4. §21 Edge Function gateway → §22 Flutter `price_insight` → §23 tests → §24 review loop → §25 E2E gate.

## Risiko utama

- n=40 lokal → metrik final kemungkinan lemah; **jujur > hijau palsu** (P0 fabricated metric).
- Loky/parallelism pada environment dev → batasi `n_jobs`.
- AirROI USD vs KOSTARA IDR → pipeline terpisah, tidak boleh pernah digabung (§5).
