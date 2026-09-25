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
