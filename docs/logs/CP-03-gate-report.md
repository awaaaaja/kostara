# CP-03 — Midterm Design Review — GATE REPORT

Date: 2026-09-25
Sprint 4 (weeks 7-8) · Prompt: `PROMPTS.md` §9 · Status: **PASS**
(CP-03A laporan terpisah: `CP-03A-gate-report.md`; laporan ini = CP-03B build
+ checklist REVIEW CP-03.)

---

## 1. Context acquisition (dijalankan sebelum THINK)

- Source of truth: AGENTS, VALIDATION_PROTOCOL, PRD (LOCKED V1), DESIGN
  (dibaca penuh), SPRINTS CP-03B, PROMPTS §9, README.
- Codebase awal: foundation-only (`main.dart` placeholder + `app_config.dart`);
  **belum ada** router/state/fitur. `supabase/migrations/` belum ada di repo.
- `Aman.md` sekarang terisi (sudah git-ignored sejak CP-03A) → blocker CP-03B
  terbuka. Postgres 17 + PostGIS 3.3 (public), PostgREST, Storage aktif.
- Masukan terkunci: `cp03a-api-contracts.md` (§2–3), `cp02-ml-data-plan.md`
  (A1–A10, B1–B4), `cp02-rls-storage.md`, `cp02-test-plan.md`.

## 2. BUILD — apa yang dihasilkan

### 2.1 Backend (migration-first, schema v1 live)

| Artefak | Isi |
|---|---|
| `supabase/migrations/20260925010000..0007_*.sql` | extensions, 23 tabel, guard trigger + helper, RLS 6 aktor + storage (3 bucket/10 policy), RPC discovery (`search_properties`, `nearby_properties`, `campus_suggestions`, `feed_recommendations`) |
| `supabase/seed/seed_data.sql` + `seed_dev.py` | seed dev sintetis idempoten (5 kampus, 10 fasilitas, 12 properti, 40 kamar, 1200 interaksi, 4 tenancy, 4 review, 7 profil) — diberi label dev, bukan data produksi |
| `scripts/run_sql.py` (+`test_run_sql_split.py`) | runner Management API; splitter komentar/string/dollar-quote aware + regression test |
| `scripts/run_db_tests.py` | harness DB: constraint/guard/uniqueness/FK + spatial (haversine vs st_distance, bbox, radius, GIST EXPLAIN, paginasi deterministik) + privasi + RLS coverage |
| `scripts/test_rls_matrix.py` | matriks REST: 6 aktor × operasi (profiles, properties, reviews, rooms, preferences, storage path/mime) + feed fallback + log |

### 2.2 ML baseline (reproducible, tanpa angka karangan)

| Artefak | Isi |
|---|---|
| `experiments/recommendation/requirements.txt` | pin numpy 2.5.3 · pandas 3.0.6 · scikit-learn 1.9.1 · pyarrow 25.0.1 |
| `export_dataset.py` | REST (service key dari Aman.md) → `data/raw/*.parquet` (row-level git-ignored) + `dataset_version` = content-hash |
| `run_baselines.py` | split temporal 70/10/20; hard-filter kandidat dari preferensi (positif terbuang **dicatat**, tidak disembunyikan); popularity + content-based (cosine 0.8 + geo-closeness 0.2, blend preferensi α=n/10); metrik P/R/NDCG/HR@{5,10}, coverage katalog/user, subgroup cold-start; seed 42; **run 2× → determinism assert**; manifest per run (commit, seed, params, dataset_version) |
| `DATASET_CARD.md` | sumber, ruang lingkup, definisi bobot, 4 keterbatasan (sintetis kecil, filter memangkas 21 positif test, cold-start subgroup kosong, bias), reproduksibility, syarat update saat data produksi |
| `model_versions` | 2 baris `draft` (`baseline-popularity`, `baseline-content_based`) + fallback `baseline-fallback` — status `active` = keputusan CP-04B |
| `experiments/review_nlp/LABELING_GUIDELINE.md` | taxonomy 8 aspek terkunci + aturan anotasi + strategi kappa + pernyataan jujur: **belum ada label → metrik N/A** |

### 2.3 Flutter prototype (feature-first + Riverpod + go_router)

| Fitur (SPRINTS CP-03B) | File | Status |
|---|---|---|
| auth (login/register + guard ToS v1.0 + consent opsional, state konfirmasi email) | `features/auth/*` | prototype ✓ |
| seeker onboarding (budget, gender, kampus, jarak, transportasi, fasilitas; gate di shell) | `features/onboarding/*` + `core/router/app_shell.dart` | prototype ✓ |
| property list (q, chip kampus, sort, paging, loading/empty/error) | `features/discovery/property_list_screen.dart` | ✓ |
| map (flutter_map + OSM, marker dari RPC yang sama, bottom sheet preview, state kamera terpisah) | `features/discovery/explore_map_screen.dart` | ✓ |
| campus query (chip kampus + `campus_suggestions`) | `discovery_providers.dart`, list screen | ✓ |
| property detail (REST: detail+kamar+ulasan, cover URL publik) | `features/property_detail/*` | ✓ |
| owner add property (validasi, EWKB point, guard role, status pending) | `features/owner/add_property_screen.dart` | ✓ |
| router + role/auth guard | `core/router/app_router.dart` | ✓ (guard role via shell visibility + screen-level check; redirect auth penuh) |

Kontrak klien disesuaikan ke implementasi RPC yang sudah terkunci:
`cover_path` (client bangun URL public bucket), key `lat`/`lng` — **dicatat di §5**
bukan perubahan sepihak.

## 3. REVIEW — checklist gate CP-03 (SPRINTS)

| Pertanyaan gate | Jawaban | Bukti |
|---|---|---|
| Prototype berjalan? | **Ya (executable)** — `flutter analyze` 0 issue, `flutter test` 7/7 termasuk 4 contract test RPC nyata (anon) + boot tanpa konfigurasi. *Device-run belum* (lingkungan tanpa JDK/Chrome — lihat §7) | test output §4 |
| Baseline ada & reproducible? | **Ya** — dua run seed identik (assert otomatis), manifest menyimpan dataset_version/commit/params; terdaftar di `model_versions` (draft) | `runs/20260924T195959Z/`, `…200019Z/` |
| Architecture matches PRD? | **Ya** — feature-first, Riverpod, go_router, RLS-first SECURITY INVOKER, 0 Edge Function, distance-only (tanpa ETA), fallback feed tak-pernah-kosong, ML offline→registry | code `lib/**`, migration `…0005/0006` |
| No RLS bypass? | **Ya** — tidak ada service_role di Flutter (guard + scan); klien hanya RPC invoker/REST anon-or-authenticated; harness DB 22/22 + matrix REST 53/53 lulus termasuk kasus anon tanpa barikade | §4 |
| Test evidence? | **Ya** — semua hasil perintah di §4; splitter regression test; unit EWKB cocok dengan titik yang sama dipakai harness DB | §4 |
| Backlog locked untuk CP-04? | **Ya** — `cp03a-backlog.md` tetap berlaku; delta: B11 (tenancy RPC mutate) + aktivasi model + device smoke → CP-04A/04B (lihat §6) | §6 |
| Major risk reduced? | **Ya** — R-005 (RLS) → mitigasi tereksekusi; R-018 (seed) → seed sintetis terlabel; R-008 (metric) → guard determinism + dataset card jujur | RISK_REGISTER |

## 4. Validation — hasil perintah (evidence)

```text
flutter analyze                      → No issues found
dart format --set-exit-if-changed    → OK (lib, test)
flutter test                         → 7/7 PASS
  - widget boot tanpa konfigurasi
  - unit EWKB (2) — cocok dgn titik verifikasi harness
  - contract anon (4): search paged, sort invalid 22023,
    campus_suggestions, feed fallback + p_limit (jaringan nyata)
python3 scripts/test_run_sql_split.py → PASS
python3 scripts/run_db_tests.py      → 22/22 PASS
  (TP-DB 14, TP-GIS 5, TP-PRIV 2, TP-RLS-08)
python3 scripts/test_rls_matrix.py   → 53/53 PASS
python3 experiments/.../run_baselines.py → determinism PASS (2 run identik)
secret scan (sbp_/sb_publishable/JWT/service_role) → hanya guard/docs/grant
emoji scan lib/                      → 0
Aman.md ignored                      → .gitignore:2 ✓
```

## 5. Masalah yang ditemukan REVIEW & diperbaiki (FIX)

| # | Masalah | Bukti awal | Perbaikan | Verifikasi ulang |
|---|---|---|---|---|
| 1 | `feed_recommendations` referensi `st.distance_m` (tidak ada di FROM) | error saat smoke SQL | `c.distance_m` | matrix 53/53 |
| 2 | `search_properties` tidak ada OFFSET → `p_page` diabaikan | baca kode + smoke | `offset (p-1)*size` | TP-GIS pagination PASS |
| 3 | Order outer `jsonb_agg` ASC bawaan → merusak ranking relevansi | urutan hasil salah | explicit `asc/desc nulls last` per kunci | urutan P5(5.0)→P3(4.0)→P7(3.0) sesuai rating |
| 4 | `feed_recommendations` `p_limit` tervalidasi tapi tidak dipakai | kontrak vs kode | wrapper `t.rn <= p_limit` | contract test `≤3` PASS |
| 5 | Seed interaksi: subquery LATERAL berisi `random()` dievaluasi sekali (planner) → 1200 baris identik | distribusi 10 properti merata 0 | regenerasi deterministik `md5(...)` per baris | 10 properti × 105–137 event, 3 user |
| 6 | PostgREST membatasi `limit` ke `max-rows` (1000) → export dataset kepotong 1000/1200 | `events: 1000 rows` | paginasi offset di `export_dataset.py` | `events: 1200 rows` |
| 7 | flutter_test memasang HttpClient mock → kontrak test kena 400 | `PostgrestException code:400` | `HttpOverrides.global = null` khusus test kontrak | 4/4 PASS |

Catatan integritas: **fix #1–#4 mengedit file migration yang sudah ter-apply**
(live DB disinkronkan via `scripts/run_sql.py`). Dilakukan karena fase pre-release
(migration belum masuk repo/tag); kejadian ini didokumentasikan di sini sebagai
bagian evidence — sebelum production, migration harus immutable.

## 6. Deviasi, defer, dan keputusan kecil

1. **Kontrak vs implementasi** (dikutip apa adanya ke klien):
   search item memakai key `id` (feed memakai `property_id`); item search
   membawa `cover_path` (bukan URL) + `lat`/`lng` — tidak ada fitur yang
   bergantung pada bentuk lain.
2. **B11** (RPC tenancy mutate: `activate_tenancy`, `submit_tenancy_request`,
   moderasi/admin) → **CP-04A**, sesuai backlog; tidak ada API contract baru di CP-03B.
3. **GPS on-demand (geolocator) belum di slice prototype** → jarak dihitung
   server via `campus_id`/`max_distance_m` (jujur: tanpa tombol "lokasi saya");
   risiko R-021, implementasi CP-04A. Tidak ada ETA/pseudo-lokasi yang dikarang.
4. **Font asset Plus Jakarta Sans belum dibundel** (R-022) — tema memakai
   ColorScheme M3 seed DESIGN; bundling font = CP-04A.
5. **Alur konfirmasi email** ditangani UI (state "cek email") tetapi belum
   diuji end-to-end (R-023; tergantung setting konfirmasi project).
6. **Demo on-device belum berjalan** di lingkungan gate ini (Android SDK ada
   tapi tanpa JDK; tanpa Chrome/Linux toolchain) → evidence = analyze + test
   termasuk contract RPC nyata. Prasyarat CP-04A: pasang JDK / device smoke.
7. Metrics baseline berasal dari **dataset dev sintetis kecil**; angka NDCG@10
   popularity = 1.0 adalah artefak data kecil — dilarang dipresentasikan sebagai
   performa produk (lihat DATASET_CARD §keterbatasan, AGENTS §4.4).
8. Interaksi seed = **hipotesis bobot** (AGENTS §11.3), diperlakukan sebagai
   design parameter, bukan ground truth perilaku pengguna.

## 7. Risiko (update)

- **R-005** (RLS leak) → **Mitigated**: matrix otomatis 75 kasus lulus
  (22 harness + 53 REST) + wajib ulang setiap perubahan policy.
- **R-018** (seed tidak realistis/bermasalah izin) → **Mitigated**: seed
  sintetis manual, terdokumentasi, diberi label dev; tanpa scraping.
- **R-021 (baru)**: prototype tanpa GPS on-demand → Mitigated parsial lewat
  kampus/jarak server-side; tombol lokasi = CP-04A.
- **R-022 (baru)**: font DESIGN belum dibundel → tampilan belum 100% token
  tipografi; CP-04A.
- **R-023 (baru)**: alur konfirmasi email belum E2E → ditest CP-04A pada
  environment dengan mailbox dev.
- R-001/R-002/R-008/R-017 tetap **Open** (butuh data produksi/ToS v1.0).

## 8. Gate decision

**PASS** — dengan syarat yang sudah dipenuhi:
prototype executable (analyze/test/contract lulus), baseline ada +
reproducible (determinism), arsitektur sesuai PRD, tanpa RLS bypass,
evidence test lengkap, backlog CP-04 terkunci (delta §6 dicatat),
risiko major bergerak turun; keterbatasan §6–7 diungkapkan apa adanya.

## 9. Next allowed step

**Sprint 5 / CP-04A (Core Product Implementation)** — AUTHORIZED, dengan urutan
awal: (1) device smoke + prasyarat JDK, (2) alur kritis register→onboarding→
discover→map→detail→save→request sesuai `cp03a-backlog.md`, (3) B11 RPC tenancy,
(4) bundling font + GPS JIT.
