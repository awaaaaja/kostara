# ADR-005 — ML: training offline → parameter serving via SQL RPC; NLP batch

Status: Accepted (dgn decision gate CP-04B)
Date: 2026-09-25

## Context
FR-REC-01..04 + FR-ML-01..03: feed personal, explanation, fallback tak-pernah-
kosong, skor = normalized match. AGENTS §11: baseline dulu, jangan lompat ke
deep learning; reproducibility; jangan mengarang metrik. App harus decoupled
dari training dan tetap berfungsi bila ML gagal (§11.7).

## Options — serving
1. **Scoring deterministik di SQL RPC; bobot/konfigurasi dari `model_params`
   yang ditulis training offline; fallback chain di tempat yang sama.**
2. Scoring di klien Dart — logika bocor, update = rilis app.
3. FastAPI inference service — hosting + cold start; V1 baseline tak butuh.
4. Prakomputasi user×property — sparse, stale utk listing baru.

Model ladder (dihormati): popularity → content-based → hybrid (gate cp02-A8).
NLP: (a) batch offline lexicon → TF-IDF+linear; (b) transformer bila data; NLP
realtime ditolak.

## Decision
1. Training & eksperimen = Python offline (export data dgn service key di ENV;
   split temporal, seed, lock dependencies; tulis `model_versions` +
   `model_params`).
2. Serving V1 = `feed_recommendations` RPC: hard filter → skor 0–100
   (bobot terparameterisasi) → reason_codes → `recommendation_logs`.
3. Fallback: params hilang/error → `search_properties(sort='popularity')` +
   log `baseline-fallback`; UI boleh menampilkan "rekomendasi personal tidak
   tersedia" (DESIGN §35); feed tak pernah kosong.
4. Hybrid menang/gagal = gate cp02-A8 di CP-04B; bila model terpilih TIDAK bisa
   diekspresikan sbg parameter SQL → barulah evaluasi Edge Function/FastAPI
   (ADR baru) tanpa mengubah interface feed di app.
5. NLP = batch offline → `review_aspect_scores` (source=nlp, threshold →
   insufficient_evidence); gagal → ringkasan structured rating saja.
   Transformer ber-gate dataset (R-002) + ToS lisensi UGC (R-017).

## Consequences
- (+) app tidak tahu model (decoupled); tanpa hosting inferensi; fallback &
  logging built-in; reproducibility tercatat di DB.
- (−) expressive ceiling model = bentuk parameter SQL (dicatat: upgrade path
  di atas); ranking dihitung per-request → wajib uji EXPLAIN/pagination
  (R-019 free tier).
- Dilarang: menyebut skor sbg probabilitas; menampilkan metrik tanpa run.

## Validation
- TP-REC-01..05 (feed, reason, fallback, skor label, cold-start), TP-ML-01 (log).
- CP-04B: run ulang seed sama → metrik identik (NFR-ML-01); model card.
