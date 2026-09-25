# Model Card — KOSTARA Recommender (CP-04B + parity opsi C)

Status: **active di produksi dev** · Nama model: `popularity` (terfilter)
Model version: `23cf8b9f-1c72-4d77-8d1c-5d473eddaa7b` (lihat `model_versions`)
Dataset: `ebc8e8e3cadecd7d` · Seed: 42
Run evaluasi serving (formula SQL): `experiments/recommendation/feed_runs/20260925T182134Z`
Run evaluasi konten (cosine, CP-04B): `experiments/recommendation/runs/20260925T170952Z`

## 1. Sumber data & legalitas

- Ekspor `experiments/recommendation/export_dataset.py` (service key via env,
  tidak pernah di repo) dari tabel dev Supabase.
- Komposisi: 1200 baris interaksi · 3 seeker · 10 listing verified+active ·
  4 review · 4 preferensi — **semua seed sintetis** (lihat `DATASET_CARD.md`).
- **Bukan data produksi.** Semua metrik di bawah adalah hasil eksperimen pada
  data karangan dan dilarang dipresentasikan sebagai performa produk
  (AGENTS §4.4). Consent: 6/7 profil dev punya `data_consent_at`; interaksi
  hanya dikumpulkan app dengan consent (FR-PRIV-02).
- Delta dataset_version vs CP-03B (`2acc04df317e5b4c` → `ebc8e8e3cadecd7d`):
  content-hash berubah karena satu baris review disentuh uji moderasi
  CP-04A (`updated_at`) — hash memang melacak isi nyata, bukan kegagalan
  reproduksi. Ekspor ulang data identik → hash identik (diverifikasi).

## 2. Eksperimen (kandidat vs baseline)

- Split **temporal 70/10/20** pada `occurred_at`; populasi dihitung dari
  train saja (TP-ML-REC-03: tanpa leakage masa depan untuk popularitas;
  catatan jujur: fitur rating memakai agregat review terkini = sama dengan
  tampilan serving, potensi leakage ringan pada data historis — dicatat,
  bukan disembunyikan).
- Kandidat: `popularity`, `content_based`, `hybrid` (α=0.7 content +
  0.3 popularity — α design parameter, diuji bukan diklaim).
- Determinism: pipeline dijalankan 2× per run → assert identik
  (NFR-ML-01) · `deterministic_rerun: true`.
- Metrik (test split, K=5/10):

| Kandidat | P@5 | R@5 | NDCG@5 | NDCG@10 | HR@10 | coverage_catalog | n_eval | cold-start |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| popularity | 0.267 | 1.0 | 1.0 | 1.0 | 1.0 | 0.417 | 3 | n=0 (kosong) |
| content_based | 0.267 | 1.0 | 0.877 | 0.877 | 1.0 | 0.417 | 3 | n=0 (kosong) |
| **hybrid (terpilih)** | 0.267 | 1.0 | **1.0** | **1.0** | 1.0 | 0.417 | 3 | n=0 (kosong) |

## 3. Pemilihan — berdasarkan evidence, bukan novelty

1. `hybrid` terikat NDCG tertinggi (1.0) dan **tidak lebih buruk** dari
   popularity di semua metrik pada data ini.
2. Tie-break ke arah personalisasi: FR-ML-03/PRD menetapkan popularity
   **hanya fallback/tie-breaker**, bukan ranking utama — pure popularity
   sebagai model aktif akan melanggar itu walau metriknya sama.
3. Content murni lebih buruk (NDCG 0.877) → hybrid menyimpan sinyal
   personalisasi sekaligus tren.
4. Hybrid **dapat diekspresikan sebagai parameter SQL** (ADR-005 §4) →
   tidak perlu Edge Function/FastAPI baru.

**Keterbatasan pemilihan (jujur):** n_eval=3 user sintetis, subgroup
cold-start kosong, gap NDCG hybrid-vs-popularity 0.0 — pemenang pada data
sekecil ini rapuh; seleksi ulang wajib saat data produksi cukup (CP-05+).

### 3b. Parity training-serving (opsi C, 2026-09-25) — MENINDAKLANJUTI §2–§4

Evaluator baru `tune_feed_weights.py` men-port formula SQL
`feed_recommendations` (migrasi 010010) 1:1 — termasuk filter
`available>0`, tie-break `score, popularity, uuid` — lalu:

- **val dipakai tuning** (sebelumnya mati): grid 16.807 konfigurasi bobot,
  step 0.1, anchor = bobot hand CP-04B;
- **test dievaluasi 1×** dengan formula yang sama untuk 3 kandidat.

| Kandidat (formula SQL) | val NDCG@10 | test NDCG@10 | test HR@10 | coverage test |
|---|---:|---:|---:|---:|
| popularity `(0,0,0,0,1)` | 1.0 | **1.0** | 1.0 | 0.417 |
| hand CP-04B | 1.0 | 0.877 | 1.0 | 0.417 |
| tuned (grid val) | 1.0 | 0.877 | 1.0 | 0.417 |

Temuan (jujur, tanpa poles):
1. **val saturated** (semua 1.0) → tuning tidak menemukan perbaikan;
   `sql_tuned == sql_hand` (anchor menang saat seri);
2. **test: popularity menang** (1.0 vs 0.877) → per gate **CP-02 A8**
   ("kandidat hanya menang bila NDCG ≥ baseline; jika tidak → rilis
   baseline terbaik") model aktif diaktifkan ulang sebagai `popularity`
   terfilter dengan `w_trending=1.0`;
3. personalisasi tetap ada di **hard filter** preferensi (budget/gender/
   radius kampus) + `reason_codes` per item; hanya ranking-weight yang
   kembali murni popularitas;
4. parity notes: jarak haversine vs PostGIS geography (delta kecil);
   popularity komponen = hitungan train-only as-of (anti-leakage), serving
   SQL = all-time count (limitasi serving, dicatat).

**Implikasi FR-ML-03** (popularity = fallback, bukan ranking utama): pada
data dev sekecil ini, evaluator serving tidak memberi bukti personalisasi
ranking mengalahkan baseline → A8 menang atas preferensi arah. Keputusan
wajib dievaluasi ulang dengan data produksi; bobot hand tetap terekam di
manifest `feed_runs/*` sebagai kandidat siap-aktivasi.

## 4. Inference contract (serving)

- Endpoint: RPC PostgREST `feed_recommendations(p_limit 1..50)` —
  SECURITY INVOKER, RLS aktif; app tidak pernah memegang key lain.
- Output per item: `property_id`, `rank`, `score` (integer 0–100,
  **skor kecocokan normalisasi — BUKAN probabilitas**, FR-REC-04),
  `reason_codes` dari kamus 6 kode (FR-REC-02), `display_name`.
- Parameter aktif (`model_params`, pasca parity 2026-09-25): `w_budget 0.0,
  w_campus 0.0, w_facility 0.0, w_rating 0.0, w_trending 1.0` —
  **popularity terfilter** (CP-02 A8, lihat §3b); bobot hand CP-04B
  (`0.245/0.21/0.105/0.14/0.3`) tetap di manifest `feed_runs/*` sebagai
  kandidat. Evaluator kini **identik dengan formula SQL** (parity port);
  batas parity yang tersisa: haversine vs PostGIS + popularity serving
  all-time (§3b).
- Latency terukur (15 panggilan auth, 2026-09-25): p50 169 ms ·
  p95 478 ms · max 918 ms — di bawah ambang wajar free-tier (NFR).
- Failure/fallback:
  1. tidak ada row aktif → `fn_active_recommender()` jatuh ke
     `baseline-fallback` (nama tampil, tanpa klaim personalisasi);
  2. RPC error/timeout di app → fallback klien
     `search_properties(sort: popularity)` + label jujur
     (DESIGN §35) — feed tidak pernah kosong bila ada listing aktif
     (AC-REC-03);
   3. cold-start (tanpa interaksi) → skor tetap dari preferensi onboarding +
      geo + verified; hard filter + reason codes tetap (FR-ML-02); bobot
      ranking mengikuti `model_params` aktif (§3b).
- Logging: tiap item menulis `recommendation_logs` (TP-ML-01).

## 5. NLP review — TIDAK dibangun (N/A, bukan gagal senyap)

Dataset review = 4 baris (3 approved) — jauh di bawah syarat labeling
(R-0002, `experiments/review_nlp/LABELING_GUIDELINE.md`): tanpa label, tanpa
kappa, tanpa split → **Macro F1/P/R = N/A**, tidak ada model, tidak ada
angka karangan. Yang berjalan: skor aspek **manual** dari form review
(`review_aspect_scores.source='manual'`) → agregat insight owner/seeker.
Pipeline NLP (AC-NLP-*, TP-ML-NLP-01) ber-gate dataset + ToS lisensi UGC
(R-017) → dievaluasi ulang di CP-05 bila data produksi cukup.

## 6. Reproducibility

```bash
.venv-ml/bin/python experiments/recommendation/export_dataset.py   # → dataset_version
.venv-ml/bin/python experiments/recommendation/run_baselines.py    # 2× + assert identik
.venv-ml/bin/python experiments/recommendation/tune_feed_weights.py --selftest
.venv-ml/bin/python experiments/recommendation/tune_feed_weights.py   # → feed_runs/<ts>/
.venv-ml/bin/python experiments/recommendation/activate_model.py --dry-run
.venv-ml/bin/python experiments/recommendation/activate_model.py   # idempoten; baca manifest feed_runs
```

Manifest per run menyimpan: dataset_version, git commit (+dirty flag),
seed, split, params, timestamp. Dependencies terpinning:
`experiments/recommendation/requirements.txt`.

## 7. Batasan ringkas (wajib saat menyajikan hasil)

- Data dev sintetis kecil; angka = artefak data kecil, bukan kualitas produk.
- Coverage katalog 41,7% dipengaruhi hard filter preferensi (21 positif
  test terbuang — dicatat, tidak disembunyikan).
- Evaluator paritas baru (§3b): val saturated, n_eval=3 → kesimpulan
  "popularity menang" rapuh; wajib re-tune saat data berubah material.
- Skor = ranking 0–100; label UI dilarang "probabilitas/kemungkinan/akurasi".
- Aktivasi ulang seleksi wajib saat dataset produksi berbeda material.
