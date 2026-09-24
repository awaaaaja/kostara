# CP-03A — Implementation Backlog & Definition of Done

Date: 2026-09-25
Status: **implementation-ready** — tiap task punya FR/AC/TP + dependensi.
Sumber requirement = `cp02-requirements.md` (56 FR · 72 AC); test =
`cp02-test-plan.md`; schema = `cp02-schema-draft.md` (+`model_params`).

---

## 1. Definition of Done (global)

Sebuah task dianggap DONE hanya jika **semua**:

1. `dart format .` bersih; `flutter analyze` 0 issue; `flutter test` lulus.
2. State UI lengkap: loading/success/empty/error (offline bila relevan).
3. AC terkait terpenuhi dan TP-nya tertulis/dijalankan (atau masuk run gate).
4. Jika menyentuh data: migration versioned + constraint + policy RLS ada di
   migration yang sama; matrix aktor diuji.
5. Tidak ada secret/PII baru masuk repo; tidak ada service_role di app code.
6. Desain cocok DESIGN.md (token, ikon bukan emoji, ukuran 360/390/430).
7. Logbook/catatan gate diperbarui bila keputusan berubah (ADR bila arsitektur).

## 2. CP-03B — Prototype & ML baselines (Sprint 4, w5-6)

| # | Task | FR/AC | TP | Keluaran bukti |
|---|---|---|---|---|
| B1 | Migrasi v1: postgis + 23 tabel + constraint + index (part 1: identity/listing) | schema | TP-OWN-02/03 | migration ter-apply di project staging |
| B2 | Migrasi v1 part 2: tenancy/payment/review/ML + helper `app_current_role()` | schema | TP-OWN-04 | — |
| B3 | Trigger: profiles (signup), rooms_transitions, last_availability_update_at | AC-OWN-04/05 | TP-OWN-04/05 | log uji transisi |
| B4 | RLS enable + policy (katalog P1–P7) utk semua tabel + view profiles_public | semua AC-RLS/PRIV | TP-RLS-01..06 | matrix 6 aktor lulus |
| B5 | Storage: bucket avatars/property-images/verification-docs + policy | FR-PRIV-03 | TP-STOR-01..03 | hasil uji 403/sukses |
| B6 | RPC discovery: search_properties (filter+sort+pagination+bbox) + campus_suggestions | FR-SEARCH-01..03 | TP-SEARCH-01..04 | EXPLAIN GIST (TP-GIS-03) |
| B7 | Auth+role+onboarding slice di Flutter (router, guards, W1/W2) | FR-AUTH/ONB | TP-AUTH/ONB | screenshot alur register→onboarding |
| B8 | Explore Map slice: flutter_map, marker, debounce, search-this-area, near me JIT | FR-MAP-01..05, FR-PRIV-01 | TP-MAP-01..05, TP-LOC-01/02 | demo viewport query 1x |
| B9 | Property list + detail + favorite (W3/W6 sebagian) | FR-SEARCH, FR-SAVED | TP-SAVED, TP-SEARCH | — |
| B10 | Owner: add property + pin + room CRUD (W9 partial) | FR-OWN-02..04 | TP-OWN-01..05 | — |
| B11 | RPC tenancy: submit/activate/end (atomik+idempotent) | FR-TEN/OWN-05 | TP-TEN-01..04 | uji 2× accept = 1 tenancy |
| B12 | Event capture foundation (interactions + taxonomy + consent gate) | FR-ML-01, PRIV | TP-PRIV-01 | — |
| B13 | **ML-1** export script (ENV key) + dataset version + card v0 | ml plan A2/A3 | — | `data/README` + dataset card |
| B14 | **ML-1** baseline A popularity + baseline B content-based, script train/eval seed-fixed | ml plan A5 | repro run | metrik NYATA dari run; `model_versions` |
| B15 | Feed RPC `feed_recommendations` (params baseline) + fallback chain + logs | FR-REC-01..04, FR-ML-01/03 | TP-REC-01..05, TP-ML-01 | feed tak-pernah-kosong teruji |
| B16 | **ML-2** taxonomy + labeling guideline + dataset card (belum tentu model) | ml plan B | — | guideline + anotasi awal bila data ada |

Gate: **CP-03 Midterm Design Review** (PROMPTS §9).

## 3. CP-04A — Build core V1 (w7-8)

| # | Task | FR/AC |
|---|---|---|
| A1 | Search/filter sheet lengkap + sort + pagination (W5) | FR-SEARCH-01/02 |
| A2 | Saved + compare ≤3 + events | FR-SAVED, FR-CMP |
| A3 | Recommendation section UI + explanation sheet + skor label | FR-REC-02/04, DESIGN §15/16 |
| A4 | Tenancy request flow + tenant home + status | FR-TEN-01/03/06 |
| A5 | Payment schedule UI + reminder lokal (tz) + regen | FR-PAY-01..05, FR-NOT-01 |
| A6 | Owner lifecycle lengkap: dashboard, requests, payments, availability | FR-OWN-01..07 |
| A7 | Admin: verifikasi owner/listing, moderasi, master, audit log | FR-ADM-01..06 |
| A8 | Review final form + moderasi + publik display | FR-REV-01..04 |
| A9 | Settings/privacy: consent view+withdraw, hapus akun, signed URL docs | FR-PRIV-02/03, FR-AUTH-06 |
| A10 | **ToS v1.0 + lisensi UGC** (draft owner-approved) → tutup R-017 | FR-AUTH-06 |
| A11 | Offline/error states + cache last-viewed | AC-OFF-01, DESIGN §35/36 |
| A12 | A11y + breakpoint pass (360/390/430, 200% text) | DESIGN §37/39 |

## 4. CP-04B — ML experiments & selection (w9-10)

| # | Task | Keluaran |
|---|---|---|
| C1 | Hybrid candidate (fusion / LightFM / LTR — pilih sesuai data) + sweep bobot | run nyata |
| C2 | Evaluasi test set temporal + cold-start subgroup + coverage | metrik P@K/NDCG/HR/coverage |
| C3 | Gate A8: menang vs baseline → set active `model_params`; kalau kalah → rilis baseline terbaik | keputusan terdokumentasi |
| C4 | NLP: label ≥20% sampel, κ≥0.6?, baseline lexicon → TF-IDF+linear; transformer hanya bila gate data | F1 makro nyata / atau "pending data" jujur |
| C5 | Integrasi explanation reason codes dari model terpilih + recommendation_logs audit | FR-REC-02 |
| C6 | Model card + dataset card final + experiment log | reproducibility |

## 5. CP-05A — Hardening (w11-12)
RLS matrix penuh ulang · TP-GIS · TP-SEC (scan APK) · performance (NFR-PERF) ·
permission UX audit · empty/error sweep semua layar · a11y · privacy review
(kolom lokasi user = 0) · bugfix P0/P1.

## 6. CP-05B — Capstone evidence & release (w13-16)
Demo recording · eksperimen & laporan ML · laporan validasi vs VALIDATION_PROTOCOL ·
AI usage log final · changelog · RISK_REGISTER update · build release APK ·
bukti sprint (commit, test result, screenshot, decision log) · final gate.

## 7. Di luar backlog (P1 — hanya setelah V1 PASS)

Pulse feedback · FCM push + notification_outbox · upload bukti bayar · travel
time/ETA (syarat ADR-003 §P1) · isochrone · advanced analytics · monitoring
dashboard · MapLibre upgrade (bila perf gagal) · FastAPI serving (bila gate
ADR-005 terpenuhi).

## 8. Risiko yang memengaruhi urutan

- R-001/R-002 (volume data/label) → C1-C4 boleh "pending data" dgn bukti hitung,
  tidak boleh metrik palsu.
- R-011/R-016 (evidence primer) → rekomendasi tetap di CP-05A.
- R-017 (ToS/UGC) → A10 blocking C4 (training ML-2 legal).
- R-019 (free tier) → B6/B15 wajib uji EXPLAIN + pagination; bila perlu naik plan.
- R-020 (reminder lokal) → A5 menyampaikan limitasi di UI.
