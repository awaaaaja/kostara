# Project Logbook — KOSTARA

Log kronologis keputusan, sprint, dan bukti. Ringkas; detail di commit/gate report.

## Template

```markdown
## <YYYY-MM-DD> — <Sprint/aktivitas>
- Status:
- Bukti:
- Catatan/risiko:
```

---

## Entries

## 2026-09-25 — Context Acquisition + Sprint 0 (CP-00)
- Status: **PASS** — gate report: `docs/logs/CP-00-gate-report.md`
- Bukti: commits `6453eb1` (docs) + `d47b15c` (foundation); format/analyze/test PASS;
  fresh clone PASS (Aman.md absent, analyze clean, 1/1 test); secret scan clean;
  Supabase project ada (ref kmlaajbmjarsyjccnvna) — kredensial hanya di Aman.md
- Catatan: stakeholder/data access BELUM divalidasi (menunggu CP-01);
  jangan klaim sebaliknya

## 2026-09-25 — Sprint 1 / CP-01 Problem & Stakeholder Validation
- Status: **NOT PASS awal (evidence 0) → evidence masuk (sekunder/proxy E-001/E-002, diverifikasi agent) → PASS** — gate report: `docs/logs/CP-01-gate-report.md`
- Bukti: H-01..H-05 terdukung; A-01..A-06 validated / A-07..A-09 unknown;
  verifikasi sumber: Mamikos Help Center resmi (iklan stale), OpenKOS/KostEZ/SuperKos/kospay (pain owner);
  risk +R-015/R-016; R-011 mitigasi parsial
- Catatan: evidence = **secondary/proxy, BUKAN wawancara primer** — dilarang
  diklaim lain di laporan. Primer Padang disarankan sebelum CP-03 (R-011/R-016).
  Sprint 2 (CP-02) AUTHORIZED.

## 2026-09-25 — Sprint 2 / CP-02 Requirements, Data, Acceptance Criteria
- Status: **PASS** — gate report: `docs/logs/CP-02-gate-report.md`
- Bukti: 12 artefak `docs/capstone/cp02-*` (scope lock, requirements 56 FR ·
  72 AC · traceability, NFR, data dictionary, schema draft 22 tabel + constraint,
  RLS matrix 6 aktor + 4 storage bucket, geospatial distance-only, ML data plan
  (baseline/split/taxonomy/labeling), events taxonomy, privacy (tutup A-07),
  test plan, lo-fi flows); PRD status → **LOCKED V1** + §31; risk +R-017..R-020,
  R-015 → Mitigated
- Catatan: V1 = P0; pulse/push/bukti-bayar/travel-time/isochrone = P1
  (`cp02-scope-lock.md`). A-09 ditutup dengan keputusan distance-only.
  Review ML-2 bergantung ToS v1.0 lisensi UGC (R-017, task CP-04A).
  Sprint 3 (CP-03A) AUTHORIZED.

## 2026-09-25 — Sprint 3 / CP-03A Alternative Design & Architecture
- Status: **PASS** — gate report: `docs/logs/CP-03A-gate-report.md`
- Bukti: 8 artefak `docs/capstone/cp03a-*` (alternatives dgn kriteria, architecture
  + data-flow + mapping 16 minggu, ERD 23 tabel (+delta `model_params`), backend
  design (pola RLS P1–P7 + helper anti-recursion + storage/PostGIS template),
  API/inference contract, screen flow + route guards, 10 wireframe hi-fi sesuai
  DESIGN, backlog+DoD) + ADR-002..006; audit referensi TP/FR/AC/NFR = 0 missing;
  flutter analyze/test PASS
- Catatan: arsitektur kunci = feature-first + Riverpod + go_router; RLS-first +
  SECURITY DEFINER RPC (Edge reserved, V1 nol); flutter_map + PostGIS
  distance-only; ML training offline → serving via `model_params`/RPC dgn
  fallback chain; reminder lokal-first. `Aman.md` masih kosong → blocker
  praktis utk eksekusi migration CP-03B. Sprint 4 (CP-03B) AUTHORIZED.

## 2026-09-25 — Sprint 4 / CP-03B Prototype & ML Baselines
- Status: **PASS** — gate report: `docs/logs/CP-03-gate-report.md`
- Bukti: schema v1 live (8 migration, 23 tabel RLS, 4 RPC discovery, 3 bucket
  storage), seed dev sintetis (1200 interaksi deterministik), harness DB 22/22 +
  matriks REST 53/53 + splitter test PASS, ML baseline reproducible
  (popularity/content-based, determinism 2× run, `model_versions` draft +
  DATASET_CARD + labeling guideline tanpa metrik karangan), prototype Flutter
  feature-first (auth, onboarding, list, map, campus query, detail, owner add)
  — `flutter analyze` 0 · `flutter test` 7/7 termasuk 4 contract RPC anon nyata
- Catatan: 7 bug ditemukan & diperbaiki saat REVIEW (4 RPC+1 seed+1 export+
  1 flutter_test HttpOverrides) — semuanya diverifikasi ulang; deviasi kontrak
  (cover_path/lat-lng, B11→CP-04A, GPS/font/email E2E tertunda) tercatat §6.
  Metrics baseline = data dev sintetis kecil → bukan klaim performa (R-008).
  Sprint 5 (CP-04A) AUTHORIZED.

## 2026-09-25 — Sprint 5 / CP-04A Core Product Implementation
- Status: **PASS** — gate report: `docs/logs/CP-04A-gate-report.md`
- Bukti: 2 migration tenancy (submit/activate/end RPC + policy split
  anti-TOCTOU; fix `rooms_guard` via `generate_subscripts`), Flutter Batch
  A–E (feed rekomendasi, saved/compare ≤3, ajukan sewa → accept owner →
  sewa aktif + jadwal bayar, owner lifecycle 6 layar + verifikasi upload,
  router/shell role-based, filter sheet, peta debounce-300ms+bbox+near-me
  JIT+marker kampus, offline cache+banner, foto listing), ToS v1.0 +
  ringkasan in-app + tarik consent, font Plus Jakarta Sans dibundel (OFL)
  — `flutter analyze` 0 · `flutter test` 12/12 (4 contract RPC nyata) ·
  `run_db_tests` 22/22 · `test_rls_matrix` 53/53 ·
  `test_tenancy_flow` 30/30 (baru) · secret+emoji scan bersih
- Catatan: 5 masalah ditemukan & diperbaiki saat REVIEW (P0 rooms_guard
  unnest/containment, P1 needle false-PASS, P1 manifest izin lokasi, 2 P1
  analyzer). On-device build **deferred atas instruksi owner** ("build
  nanti saja") → R-024; ToS draft final menunggu ok owner (R-017 mitigated
  parsial); A5/A7/A8/A9-sisa → CP-04B. Sprint 6 (CP-04B) AUTHORIZED.

## 2026-09-25 — Sprint 6 / CP-04B ML + Tenancy + Payment + Feedback + Admin
- Status: **PASS** — gate report: `docs/logs/CP-04B-gate-report.md`
- Bukti: 7 migration aditif (`…010010`–`…010016`; termasuk 2 supersede:
  rooms_select +app_is_admin, facilities_deactivate security definer), model
  hybrid α=0.7 aktif (`model_versions c626ac15…`, run bersih `…T170952Z`
  git_dirty=false, determinism lintas run identik, MODEL_CARD limitation
  jujur n_eval=3), Flutter: payment schedule + notifikasi lokal (tanpa exact
  alarm, boot reschedule) + riwayat + setup offset 7/3/1/0, review submit
  8 aspek + report + insight owner, feed fallback jujur + copy tanpa
  probabilitas, konsol admin (verifikasi/moderasi/master/model ringkasan),
  hapus akun (storage prefixes + anonimisasi) — `flutter analyze` 0 ·
  `flutter test` 33/33 (review validation + copy scan + payment unit) ·
  `run_db_tests` 27/27 · `test_rls_matrix` 57/57 · `test_tenancy_flow`
  30/30 · **`test_cp04b_flow` 35/35** (baru, REST end-to-end 5 role) ·
  latency feed p95 478 ms · secret+emoji scan bersih
- Catatan: 6 masalah ditemukan & diperbaiki saat REVIEW (P0 manifest
  `</activity>` kembar, P1 rooms count 36/40, P1 trigger 0-row, P1 test
  body-array storage, P1 emoji, batch bug authoring suite). NLP = N/A by
  gate (4 review rows, tanpa metrik karangan); copy fallback ≠ literal
  DESIGN §35 (app lebih jujur — rekomendasi perbarui DESIGN); `fire_at`
  seed 00:00 WIB vs app 09:00 WIB P2 (R-025); build on-device deferred
  (R-024). Sprint 7 (CP-05A) AUTHORIZED.

## 2026-09-25 — Phase 0-C: Parity Training-Serving Rekomendasi (pre-gate ML Price Intelligence)
- Status: **PASS** — jalur ML parity opsi C (disetujui owner di THINK gate
  feature "KOSTARA Rental Price Intelligence")
- Yang dikerjakan: `experiments/recommendation/tune_feed_weights.py` —
  port 1:1 formula SQL `feed_recommendations` (migrasi 010010: hard filter
  available+budget+gender+radius kampus, 5 komponen, tie-break
  score→popularity→uuid) + `--selftest` (haversine, filter, tie-break);
  grid 16.807 konfigurasi bobot di **val** (sebelumnya mati), 3 kandidat
  dievaluasi di **test** dengan formula identik; determinism double-run;
  output `feed_runs/<ts>/{metrics,manifest}.json`. `activate_model.py`
  kini membaca `feed_params` + metrik test dari manifest feed_runs
  (fallback run_baselines + PARAMS legacy bila feed_runs kosong)
- Hasil (jujur, tanpa poles): val saturated (semua kandidat NDCG@10 = 1.0);
  tuned == hand (anchor menang saat seri); test: **popularity 1.0 > hand/
  tuned 0.877**; coverage 0.417 identik semua kandidat; n_eval=3;
  n_positives_filtered=21 → gate **CP-02 A8** → model aktif diaktifkan
  ulang sbg `popularity` terfilter (`w_trending=1.0`, model_version
  `23cf8b9f-1c72-4d77-8d1c-5d473eddaa7b`, `hybrid` diarchive); personalisasi
  bertahan di hard filter preferensi + reason_codes (bukan bobot ranking)
- Bukti: feed RPC live → `popularity`, 5 item · `test_cp04b_flow` 35/35 ·
  `run_db_tests` 27/27 · `test_rls_matrix` 57/57 · `test_tenancy_flow` 30/30
  (catatan: run paralel rls_matrix×tenancy_flow = race harness DB — jalur
  sekuensial hijau, bukan bug aplikasi) · `dart format` 0 · `flutter analyze`
  0 · `flutter test` 33/33 · secret+emoji scan bersih · MODEL_CARD §3b/§4/§6/§7
  + ADR-005 Validation diperbarui
- Catatan: kesimpulan "popularity menang" rapuh (val saturated, n=3) —
  dicatat eksplisit; reseleksi + re-tune wajib saat dataset berubah material
  (MODEL_CARD §7, R-026); parity tersisa: haversine vs PostGIS, popularity
  serving all-time. Lanjut: Phase B (pipeline data harga — Kaggle AirROI
  creds = stop-and-ask)

## 2026-09-25 — Price Intelligence: skema (migrasi 010017+010018) + uji RLS/TRIGGER
- Status: **PASS** — schema layer untuk "KOSTARA Rental Price Intelligence"
  (THINK gate terdahulu) di dev; Fitur §7 contract butuh `district` →
  keputusan: sumber batas kecamatan = cahyadsn/wilayah_boundaries (MIT,
  Kepmendagri 300.2.2-2430/2025, sha256 `94ef0987…54bf`), filter
  `13.71.*` = 11 Kota Padang kecamatan; geoservices.big.go.id timeout;
  kelurahan/subdistrict = NULL di V1 (data gap terdokumentasi); overlap
  batas hingga ~1,1 km² → tie-break `order by kode limit 1`
- Deviasi numbering: THINK menyebut 010017 utk tabel harga, tapi prasyarat
  district dibuat 010017 lalu tabel harga 010018 (dicatat di sini)
- `20260925010017_padang_districts.sql`: tabel `districts` (11 poligon
  ~11,6 kB, GiST), fn `district_for_point` (security definer, revoke
  public/grant service_role), kolom `properties.district` + trigger
  district dari `location` (klien tak bisa set manual), backfill 12/12,
  RLS enable + policy select master
- `20260925010018_price_intelligence.sql`: `model_versions` +kind
  `pricer`; FK `rooms(id,property_id)`; `room_price_observations`
  (unique room×waktu, trigger price-change dari `rooms`, backfill 40
  `seed_backfill`); `room_price_feature_snapshot` helper (facility slugs,
  nearest campus+km, district, koordinat); `price_estimates` (server-only
  write, check status/interval/quality); view `price_insight_public`
  (label posisi saja, verified+active, grant anon)
- Bukti: run_db_tests **32/32** (TP-RLS-08 26/26, TP-PRICE-01a..e) ·
  rls_matrix **65/65** (TP-RLS-09a..h) · tenancy_flow 30/30 ·
  cp04b_flow 35/35 (1x ConnectionReset transient, rerun hijau) ·
  dart format 0 · flutter analyze 0 · flutter test 33/33 · scan bersih
- Catatan: run `dart format --line-length=100` sempat mengubah 49 file
  Dart → di-revert (repo pakai default), jalur format resmi `dart format .`;
  UPDATE tanpa policy = Postgres 0 baris (bukan error) → assertion uji
  wajib cek nilai tak berubah via service
- Lanjut: Phase B extraction dataset harga (lokal, DQ) lalu stop-and-ask
  Kaggle AirROI creds

## 2026-09-25 — Price Intelligence: Phase B lokal (audit ketersediaan + ingest/DQ)
- Status: **QUALITY PASS (lokal)** — bagian Phase B yang tak butuh Kaggle
- Audit ketersediaan data dev nyata: 12 properti (12 lokasi+district, 10
  verified+active), 40 kamar (harga 650k–1,95M, median 1,05M; size_sqm
  40/40; 3 tipe), 37 link fasilitas (10 slug), 5 kampus, 40 observasi
  (2 baris artefak uji ad-hoc dihapus — bukan data historis asli)
- `experiments/price/export_dataset.py` (pola export_dataset.py rekomendasi):
  7 tabel → `data/raw/price/*.parquet` (gitignored), PII `owner_id/
  description/rules` dibuang, metadata.json (dataset_version
  `kostara-padang-v1-ed0ada2321be30cd`, sha256 per file, git commit)
- `experiments/price/validate_dataset.py`: DQ-01..11 per §8 (unique id,
  referensi, harga>0, bbox pilot lat[-1.10,-0.55] lng[100.20,100.75],
  area>0, ekstrem, duplikat, timestamp, tanpa PII, kategori kanonik,
  missing terdokumentasi) → **QUALITY PASS**, 40 baris training view,
  report `experiments/price/runs/20260925T192909Z/dq_report.json`
- Struktur: `experiments/price/` mengikuti konvensi repo (§16 ml/
  price_intelligence dimodifikasi — "sesuaikan codebase aktual"); FastAPI
  nanti di `services/price/` (ADR-007)
- Bukti: export+validate hijau · scan secret+emoji bersih
- Belum: unduh AirROI (butuh Kaggle creds — stop-and-ask), dataset card
  benchmark, inspeksi schema AirROI → gate DATA PASS penuh tertahan

## 2026-09-26 — Price Intelligence: Phase B penuh — gate DATA PASS
- Status: **DATA PASS** — unduhan benchmark resmi + kartu dataset +
  provenance selesai (lokal sudah PASS sejak 25 Sep)
- `experiments/price/download_airroi.py`: unduh resmi Kaggle
  `jasonairroi/airbnb-market-data-asia-pacific` (22,4 MB; listings 29.440
  + past_rates 341.367), **sha256 4 file terpinned** + `--verify`
  (end-to-end rerun identik); kredensial di `~/.kaggle/` saja —
  `kaggle.json` masuk `.gitignore` (file dari owner direstui lokal)
- Inspeksi schema (dihitung, bukan klaim): semua kolom listings `str`;
  `ttm_avg_rate` = USD (rasio native stabil per mata uang); 14 negara /
  113 kota / Indonesia 2.747 / **Padang 0**; lisensi **CC BY-NC 4.0**
- DQ nyata ditemukan & didokumentasi: **272 baris row-shift/corrupt**,
  11 duplikat listing_id, lat null 394, bedrooms null 22,8% + junk 127,6,
  `instant_book` null 87,6%, `room_type` campuran kanonik+jarang
- `experiments/price/DATASET_CARD.md` (kartu benchmark, termasuk daftar
  leakage `ttm_*`/`l90d_*`/`rating_*` dilarang jadi fitur) ·
  `docs/DATA_PROVENANCE.md` (AirROI NC + districts WilayahBoundaries)
- Bukti: `download_airroi.py --verify` OK 4/4 · scan secret+emoji bersih
- Lanjut: Phase C validasi AirROI (cleaning wajib utk 272 baris corrupt)
  → Phase D baseline (Geographic Median + Linear Regression)

## 2026-09-26 — Price Intelligence: Phase C validasi (QUALITY PASS ganda)
- Status: **QUALITY PASS** — lokal (DQ-01..11, 25 Sep) + benchmark AirROI
  (C-01..12, baru)
- `experiments/price/validate_airroi.py`: cleaning terdokumentatif
  (baris tidak dihapus dari raw) menemukan **383 baris korup** (272 URL
  di room_type + 100+ listing_id non-angka — 3 "duplikat" sebenarnya
  baris korup berjudul `# Sokcho Beach` dll), duplikat asli 11 →
  setelah cleaning **29.057 baris = tepat jumlah listing di past_rates,
  orphan 0** (sebelumnya 1.315)
- Temuan jujur: klaim penerbit "up to 300/kota" dilanggar 17 kota
  (301–311) **pada data mentah**; setelah cleaning korupsi → maks 300 ·
  1 baris koordinat non-null di luar bbox APAC · target USD median 62,9
  (p25–p75 35,7–132,2; ekstrem 7,5–3.832) · missing bedrooms 22,7% ·
  leakage audit: 38 kolom `ttm_/l90d_/rating_` ada di sumber, daftar
  fitur yang diizinkan bebas kontaminasi
- Bug assertion awal (dedup dihitung sebelum/ sesudah, null geo dihitung
  bad) diperbaiki sebelum PASS — bukan threshold yang dilonggarkan
  agar lolos; 3 iterasi laporan tersimpan di runs/ (jejak audit)
- Bukti: validate_airroi QUALITY PASS · validate_dataset QUALITY PASS ·
  4 laporan di experiments/price/runs/
- Lanjut: Phase D baseline (Geographic Median + Linear Regression)
