# AI Usage Log — KOSTARA

Catat setiap penggunaan AI yang berdampak pada artefak project (lihat AGENTS.md §5).
Jangan masukkan data pribadi tenant, dokumen verifikasi, credentials, atau kode mitra rahasia.

## Template

```markdown
### Entry — <YYYY-MM-DD>
- Tool/model:
- Tujuan:
- Bagian yang dibantu:
- File/artefak terdampak:
- Cara verifikasi:
- Perubahan manual setelah output AI:
- Risiko/keterbatasan:
```

---

## Entries

### Entry — 2026-09-25
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: Context acquisition + Sprint 0 / CP-00 project foundation
- Bagian yang dibantu: repo bootstrap, docs scaffolding, guarded Supabase config, test/CI baseline
- File/artefak terdampak: .gitignore, pubspec.yaml, lib/, test/, docs/, supabase/, README.md, .github/workflows/
- Cara verifikasi: flutter analyze (No issues) + flutter test (1/1) + secret scan + fresh clone — CP-00 GATE REPORT: docs/logs/CP-00-gate-report.md (PASS)
- Perubahan manual setelah output AI: deprecated `anonKey` → `publishableKey`, import/annotation dibersihkan saat REVIEW
- Risiko/keterbatasan: foundation only — belum ada fitur produk, schema, atau RLS; stakeholder belum divalidasi (CP-01)

### Entry — 2026-09-25 (Sprint 1 / CP-01)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: CP-01 problem & stakeholder validation (dokumen & instrumen; NOL data fabrikasi)
- Bagian yang dibantu: charter, problem statement hipotesis, stakeholder map, interview script, evidence log template, journey/pain hypothesis, benefit indicators, assumptions register, risk update, gate report
- File/artefak terdampak: docs/capstone/cp01-*.md, RISK_REGISTER.md, LOGBOOK.md, docs/logs/CP-01-gate-report.md
- Cara verifikasi: evidence log = 0 entri (sengaja); semua H-xx/A-xx berstatus hipotesis/unknown; gate NOT PASS
- Perubahan manual setelah output AI: REVIEW checklist PROMPTS §6 dijalankan; tidak ada PRD diubah (belum ada findings)
- Risiko/keterbatasan: gate terblokir sampai wawancara nyata dijalankan pemilik project (R-011)

### Entry — 2026-09-25 (CP-01 evaluasi ulang setelah evidence)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: memproses evidence proxy/sekunder dari owner + verifikasi sumber + evaluasi ulang gate CP-01
- Bagian yang dibantu: evidence log (E-001/E-002 dengan provenance), assumptions 6/0/3, problem statement diperkuat, journey/pains terdukung, benefit indicators directional, gate report PASS dgn limitasi, risk register update
- File/artefak terdampak: docs/capstone/cp01-*.md, RISK_REGISTER.md, LOGBOOK.md, docs/logs/CP-01-gate-report.md
- Cara verifikasi: 3 websearch agent (Mamikos help center resmi; OpenKOS GitHub; KostEZ/SuperKos/kospay) mengonfirmasi klaim inti; angka anekdit Reddit ditandai tak-terverifikasi; flutter analyze/test PASS
- Perubahan manual setelah output AI: label sekunder konsisten di semua artefak; larangan klaim "hasil wawancara primer" ditulis di gate report & logbook
- Risiko/keterbatasan: A-07/A-08/A-09 unknown; evidence primer Padang belum ada (R-011/R-016)

### Entry — 2026-09-25 (Sprint 2 / CP-02)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: CP-02 requirements/data/acceptance — mengunci V1 yang terlacak dari bukti CP-01
- Bagian yang dibantu: scope lock V1/P1/P2, 56 FR + 72 AC + traceability matrix, NFR terukur, data dictionary & schema draft (constraint), RLS matrix + storage policy, rencana geospatial (distance-only), rencana dataset/evaluasi ML-1 & ML-2 (termasuk taxonomy & strategi labeling), taxonomy event + bobot interaksi, privacy/consent (tutup A-07), test plan, lo-fi flow, lock header PRD + §31, risk update, gate report
- File/artefak terdampak: docs/capstone/cp02-*.md (12), PRD.md, RISK_REGISTER.md, LOGBOOK.md, docs/logs/CP-02-gate-report.md
- Cara verifikasi: audit otomatis REVIEW (traceability FR→AC→TP, kata vague di AC, kepatuhan data path ML, keterbacaan lokasi-bounded, matrix coverage) + flutter analyze/test regression + secret scan — hasil di gate report
- Perubahan manual setelah output AI: keputusan scope (P1: pulse/push/bukti bayar/travel time) direkonsiliasi ke PRD §31; bobot interaction tetap ditandai hipotesis
- Risiko/keterbatasan: draft schema/RLS belum dieksekusi (migration = CP-03B/04A); ToS v1.0 lisensi UGC masih task (R-017); jumlah data train/label NLP belum diketahui (R-001/R-002)

### Entry — 2026-09-25 (Sprint 3 / CP-03A)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: CP-03A alternative design & architecture — bandingkan alternatif, kekunci
  keputusan, tetapkan arsitektur buildable (tanpa mengarang data/metric)
- Bagian yang dibantu: perbandingan alternatif 7 topik dgn kriteria; diagram
  arsitektur + module boundary + data-flow; ERD 23 tabel; desain RLS (pola + helper
  anti-recursion) + storage + PostGIS query; kontrak API/inference/NLP; route table
  + guards; 10 wireframe hi-fi (token DESIGN); backlog+DoD; ADR-002..006; gate report
- File/artefak terdampak: docs/capstone/cp03a-*.md (8), docs/decisions/ADR-002..006,
  docs/logs/CP-03A-gate-report.md, LOGBOOK.md, AI_USAGE_LOG.md, .gitignore,
  pubspec.yaml (deskripsi)
- Cara verifikasi: audit silang otomatis referensi TP/FR/AC/NFR (0 missing),
  flutter analyze (No issues) + flutter test (1/1), secret scan + emoji scan bersih
- Perubahan manual setelah output AI: delta skema `model_params` (22→23) dicatat
  eksplisit di ERD/gate; rujukan `FR-PERF` dikoreksi ke `NFR-PERF`; count FR/AC
  di entry CP-02 dikoreksi 48/66 → 56/72
- Risiko/keterbatasan: desain belum dieksekusi (migration = CP-03B); kredensial
  Supabase (Aman.md) masih kosong; metrik ML belum ada (wajar, eksperimen CP-04B)

### Entry — 2026-09-25 (Sprint 4 / CP-03B)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: CP-03B — eksekusi schema+RLS+RPC (migration-first), seed dev, harness
  DB & matriks RLS, pipeline baseline ML yang reproducible, prototype Flutter
  slice, dan gate report CP-03 tanpa mengarang data/metric
- Bagian yang dibantu: 8 file migration + seed; scripts run_sql/harness/RLS
  matrix (dengan regression test splitter); export_dataset + run_baselines +
  DATASET_CARD + LABELING_GUIDELINE; slice Flutter (router/shell, auth,
  onboarding, list/map/detail, owner add) + unit EWKB + 4 contract test anon;
  LOGBOOK, RISK_REGISTER, gate report CP-03
- File/artefak terdampak: supabase/**, scripts/**, experiments/**, lib/** (baru
  selain foundation), test/**, pubspec.yaml, .gitignore, docs/logs/CP-03-gate-report.md
- Cara verifikasi: flutter analyze (0) · flutter test 7/7 · run_db_tests 22/22 ·
  test_rls_matrix 53/53 · split test PASS · run_baselines determinism PASS ·
  secret+emoji scan bersih — semua angka dieksekusi di sesi ini
- Perubahan manual setelah output AI: deviasi kontrak RPC dicatat apa adanya di
  gate §5–6; 4 bug RPC diperbaiki pada migration pre-release (disyaratkan
  diverifikasi ulang oleh harness/matrix); seed interaksi ditulis ulang
  deterministik setelah bug evaluasi LATERAL ditemukan
- Risiko/keterbatasan: demo on-device belum jalan (env tanpa JDK/Chrome);
  GPS JIT, font asset, email E2E ditunda ke CP-04A (R-021..R-023); dataset
  baseline sintetis kecil — angka bukan klaim performa (R-008/R-001/R-002)

## 2026-09-25 — CP-04A Core Product Implementation (Sprint 5)
- Tujuan: CP-04A — alur kritis register→onboarding→discover→map→detail→
  save/compare→request→owner accept→sewa aktif; owner lifecycle; filter/map/
  offline/foto; ToS+font; gate report tanpa mengarang bukti
- Bagian yang dibantu: migration tenancy `…0008/0009` + `test_tenancy_flow.py`;
  Flutter Batch A–E (event logger, feed, saved, compare, tenancy, 6 layar
  owner, verifikasi upload, router/shell role-based, filter sheet, map
  debounce/bbox/near-me/kampus, offline cache, foto listing); `docs/tos-v1.0.md`
  + `tos_summary.dart`; bundling font; manifest izin lokasi; LOGBOOK,
  RISK_REGISTER, gate report CP-04A
- File/artefak terdampak: supabase/migrations/** (2 baru), scripts/**,
  lib/** (hampir semua fitur baru/ubah), test/** (3 baru), pubspec.yaml,
  android manifest, assets/fonts/**, docs/tos-v1.0.md,
  docs/logs/CP-04A-gate-report.md, LOGBOOK.md, RISK_REGISTER.md
- Cara verifikasi: flutter analyze (0) · flutter test 12/12 (termasuk 4
  contract RPC anon nyata) · run_db_tests 22/22 · test_rls_matrix 53/53 ·
  test_tenancy_flow 30/30 · probe REST (campuses EWKB, bbox dalam/luar,
  guard tos_required, mailer_autoconfirm=false) · secret+emoji scan bersih —
  semua angka dieksekusi di sesi ini
- Perubahan manual setelah output AI: fix rooms_guard migration dibaca ulang
  dari pola FSM asli (bukan tebakan); akurasi `hasGesture`/`visibleBounds`
  diverifikasi dari sumber package flutter_map 8.3.2 lokal; penentuan scope
  A5/A7/A8/A9/A12 parsial mengikuti backlog, bukan preferensi model
- Risiko/keterbatasan: build/run on-device deferred (instruksi owner) → R-024;
  teks ToS menunggu ok owner (R-017); mailbox E2E belum ada (R-023 parsial);
  sweep breakpoint/text-scale butuh device (CP-05A)

## 2026-09-25 — CP-04B ML + Tenancy + Payment + Feedback + Admin (Sprint 6)
- Tujuan: CP-04B — seleksi hybrid berbasis metrik (tanpa klaim novelty),
  pengingat jadwal bayar, review verified 8 aspek + moderasi admin, hapus
  akun, gate report dengan evidence yang dieksekusi di sesi
- Bagian yang dibantu: 7 migration `…010010`–`…010016` (feed rpc, audit rpc,
  due calculator, aspect, admin policy, 2 supersede fix); `run_baselines.py`
  hybrid α + `MODEL_CARD.md` + `activate_model.py`; Flutter payment/reminder
  (`core/notifications`, `payment_schedule`, layar riwayat/setup/sync),
  `features/feedback/**`, `features/admin/**`, router/shell, delete-account,
  home feed fallback/copy; `scripts/test_cp04b_flow.py` (35 kasus) +
  `test/{copy_scan,review_validation,payment_schedule}_test.dart`; LOGBOOK,
  RISK_REGISTER, gate report CP-04B
- File/artefak terdampak: supabase/migrations/** (7 baru), experiments/**,
  lib/** (fitur payment/feedback/admin/auth/router/discovery), scripts/**,
  test/** (3 baru), android manifest, docs/logs/CP-04B-gate-report.md,
  LOGBOOK.md, RISK_REGISTER.md
- Cara verifikasi: flutter analyze (0) · flutter test 33/33 ·
  run_db_tests 27/27 · test_rls_matrix 57/57 · test_tenancy_flow 30/30 ·
  test_cp04b_flow 35/35 (2×, termasuk setelah activate model) ·
  determinism run lintas-run identik + git_dirty=false · latency feed
  p50 169/p95 478 ms (15 panggilan) · XML manifest parse · secret+emoji
  scan bersih — semua angka dieksekusi di sesi ini
- Perubahan manual setelah output AI: P0 manifest `</activity>` kembar
  ditemukan lewat parse XML (bukan asumsi); kontrak delete storage dikoreksi
  ke `{"prefixes":[…]}` setelah membaca `storage_client` 2.8 lokal (app
  benar, test salah); copy fallback dikoreksi agar tidak mengklaim
  "berdasarkan preferensi" padahal fallback popularity; limitation seleksi
  hybrid (n_eval=3, gap 0.0) ditulis sendiri di MODEL_CARD §3
- Risiko/keterbatasan: build/run on-device deferred (instruksi owner) → R-024;
  seleksi model rapuh → reseleksi CP-05 (R-026); NLP gate tertutup (R-002,
  R-017); `fire_at` seed ≠ app (R-025, P2)

## 2026-09-25 — Phase 0-C parity ML rekomendasi (pre-gate ML Price Intelligence)
- Tujuan: memenuhi keputusan THINK gate (opsi C): evaluasi parity
  training-serving dengan formula SQL yang sama sebelum pipeline harga
  dibangun
- Bagian yang dibantu: `tune_feed_weights.py` baru (port formula SQL +
  selftest + grid tuning val + evaluasi test 3 kandidat + determinism);
  refactor `activate_model.py` (baca manifest feed_runs, fallback legacy);
  update MODEL_CARD §3b/§4/§6/§7, ADR-005 Validation, LOGBOOK entry
- File/artefak terdampak: experiments/recommendation/tune_feed_weights.py
  (baru), activate_model.py, MODEL_CARD.md, feed_runs/20260925T182134Z/,
  docs/decisions/ADR-005, LOGBOOK.md, AI_USAGE_LOG.md; DB dev:
  model_versions/model_params (aktivasi popularity)
- Cara verifikasi: `--selftest` PASS; double-run deterministik identik;
  activate --dry-run lalu real run; feed RPC live `popularity` 5 item;
  test_cp04b_flow 35/35 · run_db_tests 27/27 · rls_matrix 57/57 ·
  tenancy_flow 30/30 · flutter analyze 0 · flutter test 33/33
- Perubahan manual setelah output AI: interpretasi A8 (popularity menang di
  test → rilis baseline) diverifikasi ulang terhadap cp02-data-dictionary
  gate sebelum aktivasi; penulisan limitation (val saturated, n=3, haversine
  vs PostGIS) ditulis eksplisit agar tidak terbaca sebagai klaim kualitas
- Risiko/keterbatasan: kesimpulan rapuh pada data sintetis kecil;
  evaluator = parity praktis, bukan eksekusi SQL asli di Postgres
  (formula diport, diassert lewat selftest) — dicatat di MODEL_CARD §3b

## 2026-09-25 — Skema Price Intelligence (migrasi 010017/010018) + uji
- Tujuan: implementasi schema layer fitur harga sesuai THINK gate yang
  telah disetujui (district prasyarat + tabel observasi/estimasi + RLS)
- Bagian yang dibantu: penulisan 2 file migrasi (seed SQL dari ekstraksi
  poligon sumber terverifikasi + checksum), penambahan kasus uji
  TP-PRICE-01a..e (run_db_tests) dan TP-RLS-09a..h (test_rls_matrix),
  perbaikan assertion 0-baris-UPDATE, LOGBOOK entry
- File/artefak terdampak: supabase/migrations/20260925010017_padang_districts.sql
  (baru), 20260925010018_price_intelligence.sql (baru),
  scripts/run_db_tests.py, scripts/test_rls_matrix.py, LOGBOOK.md,
  AI_USAGE_LOG.md; DB dev: districts (11), properties.district (12),
  room_price_observations (40+uji→bersih via cascade), price_estimates
- Cara verifikasi: run_db_tests 32/32 · rls_matrix 65/65 · tenancy_flow
  30/30 · cp04b_flow 35/35 · dart format 0 · analyze 0 · test 33/33 ·
  scan secret+emoji bersih; cross-check ray-cast vs PostGIS ST_Covers
  identik pada 12 titik properti
- Perubahan manual setelah output AI: pemilihan sumber batas (GitHub
  wilayah_boundaries vs big.go.id yang mati) + tie-break poligon overlap
  ditetapkan & didokumentasikan manual; penamaan nomor migrasi
  010017/010018 direvisi dari rencana THINK
- Risiko/keterbatasan: seed properti sintetis → hasil district mengikuti
  poligon, bukan teks alamat; subdistrict NULL V1; observasi dev kini 40
  baris (bukan data latih — export dataset = tahap berikutnya)

## 2026-09-25 — Phase B lokal Price Intelligence (export + DQ pipeline)
- Tujuan: ekstraksi dataset harga lokal dari Supabase tanpa mengarang data
  (ML_PRICE_INTELLIGENCE §18) + automated DQ (§8) sebelum training
- Bagian yang dibantu: menulis `experiments/price/export_dataset.py`
  (adaptasi pola export_dataset.py rekomendasi, drop kolom PII) dan
  `validate_dataset.py` (11 check DQ + dq_report.json), audit SQL
  ketersediaan kolom vs feature contract §7
- File/artefak terdampak: experiments/price/{export_dataset,validate_dataset}.py
  (baru), experiments/price/runs/20260925T192909Z/dq_report.json (baru),
  LOGBOOK.md, AI_USAGE_LOG.md; data/raw/price/ (gitignored)
- Cara verifikasi: export 7 tabel + metadata checksum; validate exit 0 =
  QUALITY PASS; 2 baris observasi artefak uji dihapus terverifikasi
  (sisa 40 = backfill seed)
- Perubahan manual setelah output AI: konvensi lokasi `experiments/price/`
  (bukan §16 `ml/price_intelligence/`) sesuai struktur repo aktual; nilai
  bbox pilot & rentang harga ekstrem ditetapkan manual utk Padang
- Risiko/keterbatasan: hanya 2 district terpakai di seed; 40 baris = dev
  seed, bukan data operasional; feature §7 tanpa subdistrict/travel_time
  (gap V1 terdokumentasi di DQ-11)
