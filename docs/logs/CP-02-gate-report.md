# GATE REPORT — CP-02 Requirement Review (Sprint 2)

Date: 2026-09-25
Reviewer: implementation agent (opencode / mimo-v2.6-flash-free)
Commit: `docs(cp-02): …` (lihat git log)

## Status: PASS

---

## 1. Context acquisition

Dokumen kontrak dibaca penuh (PRD, SPRINTS, VALIDATION_PROTOCOL, PROMPTS §1.4/§2/§7,
README, DESIGN §36–39, CP-01 artefak, AGENTS); codebase diinspeksi:
Flutter bootstrap saja (`lib/main.dart`, `app_config.dart`), **migrations kosong**,
tanpa RLS/GIS/ML — nol konflik implementasi. Laporan lengkap di sesi THINK
sebelum BUILD.

## 2. Implemented (artifacts — 12 file baru + 4 edit)

| Deliverable | File | Status |
|---|---|---|
| PRD locked V1 + §31 lock note | `PRD.md` (header, §9.5, §12.2, §15, §31) | updated |
| Scope lock V1/P1/P2 + rekonsiliasi konflik | `docs/capstone/cp02-scope-lock.md` | new |
| FR + user stories + AC + traceability (**56 FR · 72 AC**) | `docs/capstone/cp02-requirements.md` | new |
| NFR terukur (PERF/REL/SEC/ACC/LAY/PRIV/ML/OPS) | `docs/capstone/cp02-nfr.md` | new |
| Data dictionary v0 (23 entitas + retensi/PII) | `docs/capstone/cp02-data-dictionary.md` | new |
| Logical schema draft (22 tabel V1 + constraint + index + RPC contract) | `docs/capstone/cp02-schema-draft.md` | new |
| RLS matrix (6 aktor × 22 tabel × S/I/U/D) + storage plan (4 bucket) | `docs/capstone/cp02-rls-storage.md` | new |
| Geospatial plan (distance-only, JIT consent, tanpa persist GPS) | `docs/capstone/cp02-geospatial-plan.md` | new |
| ML dataset plan (ML-1 target/baseline/split/weights/cold-start; ML-2 taxonomy + labeling strategy) | `docs/capstone/cp02-ml-data-plan.md` | new |
| Analytics event taxonomy (14 event + payload + consent gate) | `docs/capstone/cp02-analytics-events.md` | new |
| Privacy & data retention (**menutup A-07**) | `docs/capstone/cp02-privacy.md` | new |
| Test plan (14 bagian, TP eksplisit) | `docs/capstone/cp02-test-plan.md` | new |
| Low-fi user flows (navigasi 3 role + 5 alur) | `docs/capstone/cp02-flows.md` | new |
| Risk register: R-015 → Mitigated; +R-017..R-020 | `RISK_REGISTER.md` | updated |
| Logbook + AI usage log | `LOGBOOK.md`, `AI_USAGE_LOG.md` | updated |

Tidak ada fitur produksi diimplementasikan (sesuai batasan sprint).

## 3. Key decisions (mengikat untuk CP-03+)

1. **V1 = P0 SPRINTS**; P1 = pulse feedback, server push, upload bukti bayar,
   travel time, isochrone, advanced analytics, monitoring, notification_outbox.
2. **A-09 ditutup:** V1 distance-only; ETA hanya dengan routing provider valid.
3. **A-07 ditutup:** consent UX (default aktif + tarik), retensi event 24 bulan,
   hak hapus akun; **lisensi UGC review di ToS v1.0** = dasar legal training ML-2
   (implementasi ToS UI = task CP-04A → R-017).
4. Super admin tidak self-register; review pending → moderasi (tanpa auto-approve);
   accept request atomik via RPC; 1 tenancy aktif/kamar (partial unique);
   composite FK review↔tenancy; reminder local + regenerasi (Asia/Jakarta).
5. Interaction weights tetap **hipotesis** (bukan ground truth); skor rec =
   normalized match, bukan probabilitas.

## 4. REVIEW results (PROMPTS §7)

| Pemeriksaan | Hasil |
|---|---|
| Setiap P0 feature punya user + acceptance criterion | **PASS** — 56 FR → 72 AC; 0 FR tanpa AC (audit skript) |
| Tidak ada role access ambigu | **PASS** — matrix 6 aktor × 22 tabel + aturan keras §3; super_admin via policy + audit, bukan blanket |
| Tidak ada lokasi koleksi tak-terbatas | **PASS** — 0 kolom lokasi user di skema (audit skript); JIT permission; no background (AC-LOC-01/02, TP-LOC-01/02) |
| Tidak ada requirement rekomendasi tanpa data path | **PASS** — FR-REC/ML → sumber tabel di `cp02-ml-data-plan.md` A2 (user_preferences, properties, interactions, reviews, recommendation_logs) |
| Tidak ada review ML tanpa strategi data/labeling | **PASS** — UGC berlisensi ToS + anotasi tim ≥2 annotator + kappa ≥20% sampel + lexicon baseline bila label minim (ML plan B3/B4) |
| AC tanpa kata vague tanpa definisi terukur | **PASS** — scan 72 baris AC: 0 match `fast/good/accurate/cepat/bagus/akurat/baik` |
| Traceability lengkap | **PASS** — H-01..H-05 → FR → AC → TP literal (semua TP terdapat di test plan; skript) |
| Schema ↔ dictionary ↔ RLS coverage konsisten | **PASS** — 22 tabel V1 di ketiga dokumen; `notification_outbox` ditandai P1 di dictionary |

## 5. Validation executed

```text
audit traceability FR→AC→TP (python) : PASS (56/72; missing TP = NONE)
vague-word scan pada baris AC        : PASS (0 match)
coverage skema/dictionary/RLS        : PASS (22/22 tabel; 0 kolom lokasi user)
ML data path + labeling strategy     : PASS
flutter analyze                      : PASS (No issues found)
flutter test                         : PASS (1/1)
secret scan (tracked files + docs)   : PASS (Aman.md/.env tidak ter-track; 0 key pattern)
```

## 6. Issues

| ID | Severity | Issue | Status |
|---|---|---|---|
| CP02-1 | P1 | Klaim jumlah FR/AC awal (48/66) tidak sesuai kenyataan (56/72) | **FIXED** — dikoreksi di requirements/PRD/logbook |
| CP02-2 | P1 | 49+ ID TP tertulis sebagai range sehingga tidak terdeteksi literal | **FIXED** — test plan rev 1 menulis semua TP eksplisit |
| CP02-3 | P2 | 4 baris AC mengandung "cepat/baik" | **FIXED** — diparafrase (≥300 ms, <500 ms); scan ulang 0 |
| CP02-4 | P2 | ToS v1.0 belum ada isinya (dasar legal ML-2) | OPEN → CP-04A (R-017) |
| CP02-5 | P2 | Harness SQL test (pgTAP vs skrip) belum dipastikan | OPEN → CP-03A |
| CP02-6 | P2 | Jumlah data train/label NLP belum diketahui (memengaruhi pilihan model) | OPEN → CP-03B (R-001/R-002) |

## 7. Known limitations

- Evidence primer Padang tetap belum ada (R-011/R-016) — CP-02 tidak mensyaratkan.
- Schema/RLS masih **draft**; kebenaran eksekusi diuji saat migration CP-03B/04A.
- Reminder lokal hanya tereksekusi saat app dibuka (R-020, push = P1).
- Retensi/hapus akun dijanjikan di privacy note — implementasi menyusul CP-04A.

## 8. PASS criteria (PROMPTS §7)

| Kriteria | Hasil |
|---|---|
| Requirement traceable ke problem | **PASS** — matrix §4 (H-01..H-05 → FR → AC → TP) |
| Data & permissions feasible | **PASS** — dictionary + schema + RLS/Storage plan |
| RLS matrix koheren | **PASS** — 22 tabel, 6 aktor, aturan keras tanpa policy `true` |
| ML target/baseline/evaluation plan terdefinisi | **PASS** — ML-1 (target, baseline A/B, split temporal, metrik, gate keputusan, cold-start) & ML-2 (taxonomy, labeling, baseline, Macro F1) |
| Acceptance criteria terukur | **PASS** — 72 AC berformat Given/When/Then + ambang angka |
| Test plan ada | **PASS** — 14 bagian, seluruh AC terpetakan |

## Decision

**PASS** — Sprint 3 (CP-03A: Alternative Design & Architecture) **AUTHORIZED**.

## Next allowed step

CP-03A: architecture diagram, ERD (dari schema draft), RLS policy design,
screen flow, ML experiment plan, ADR (map provider, state management,
routing), prototype API contract.
