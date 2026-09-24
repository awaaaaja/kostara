# CP-02 — ML Dataset & Experiment Plan (ML-1 Rekomendasi, ML-2 Review NLP)

Date: 2026-09-25
Status: LOCKED — baseline & pipeline dikerjakan di CP-03B (SPRINTS §Sprint 4).
Prinsip: dataset-before-model (AGENTS §11.1); tidak ada metrik tanpa run
(AGENTS §4.4/§11.5).

---

# Part A — ML-1 Hybrid Recommendation

## A1. Target keputusan & tugas

- **Tugas:** ranking Top-N property per user SETELAH hard filter
  (budget/gender/availability/campus radius) — bukan mengganti filter (A-05/H-05).
- **Unit:** (user, candidate property) → score urut.
- **Output aplikasi:** feed Home + explanation reason codes (FR-REC-02),
  fallback bila gagal (FR-REC-03).
- **Bukan:** probabilitas keberhasilan sewa (FR-REC-04).

## A2. Sumber data (semua dari platform, tanpa scraping eksternal)

| Sumber | Tabel | Kontribusi |
|---|---|---|
| Preferensi onboarding | `user_preferences` | budget, kampus, gender, fasilitas prioritas, transport, jarak |
| Properti | `properties`, `rooms`, `property_facilities`, `campuses` | fitur konten, harga, geo |
| Perilaku | `interactions` (+ `event_weight`) | preferensi implicit |
| Kualitas | `reviews` approved + `review_aspect_scores` | rating & aspek |
| Feed terlayani | `recommendation_logs` | logging evaluasi/counterfactual-light |
| Eligibility | tenancy (untuk positive signal `tenancy`) | label kuat |

**Izin/legalitas:** data berasal dari penggunaan app sendiri; consent
interaksi (FR-AUTH-06/FR-PRIV-02) + lisensi UGC review di ToS v1.0.
Dataset diekspor oleh **script server-side (service key di environment,
tidak di repo)** → `data/` (git-ignored untuk row mentah; artefak terpilih
masuk versi dataset card).

## A3. Skema dataset (dataset card v0 di CP-03B)

```text
events.parquet:
  user_id, property_id, event_type, event_weight, occurred_at,
  session_id, source, split (train|val|test)          # split = temporal

items.parquet:
  property_id, price, gender_policy, room_types[], facility_ids[],
  lat, lng, campus_distances{}, verified_rating, aspect_means{},
  owner_verified, listing_age_days

users.parquet:
  user_id, budget_min/max, primary_campus, facility_priority[],
  transport_mode, max_distance_m, move_in_date, tenure_days
```

## A4. Interaction weights (design parameter — HYPOTHESIS, bukan truth)

```text
impression = 0 · view = 1 · save = 3 · compare = 2 · request = 5 · tenancy = 8
```

Sumber: AGENTS §11.3. Dicatat di model card; diuji ulang (sweep sederhana)
di eksperimen; setiap perubahan = run experiment terpisah.

## A5. Baseline & kandidat (urutan wajib AGENTS §11.2)

| Level | Model | Definisi |
|---|---|---|
| Baseline A | Popularity (filtered) | ranking by `sum(event_weight)` / views dalam window, difilter hard-filter user |
| Baseline B | Content-based | cosine TF-IDF/encoding pada fitur item vs profil user (preferensi + historical) |
| Kandidat | Hybrid | **dipilih berdasarkan hasil**: (1) score fusion CB+popularity, (2) LightFM bila matriks interaksi cukup, (3) LTR bila data memadai — lihat decision gate di bawah |

Keputusan model final = CP-04B berdasarkan metrik, bukan kompleksitas
(VALIDATION_PROTOCOL §18).

## A6. Split & anti-leakage

- Split **temporal**: 70/10/20 berdasarkan `occurred_at` (train/val/test),
  kandidat & ground-truth test hanya interaksi setelah cutoff.
- Fitur historis user di hitung **as-of** waktu event (tanpa masa depan).
- Listing/fasilitas yang belum ada saat cutoff tidak ikut fitur train.
- Cold-start eval: subset user dengan <5 event; subset property baru
  (<30 hari tanpa interaksi) → dilaporkan terpisah.

## A7. Metrik (evaluasi offline)

Precision@K, Recall@K, NDCG@K, Hit Rate@K (K = 5 dan 10), **coverage**
(catalog & user), cold-start subgroup metrics.
Evaluasi kualitatif: stakeholder/validator (CP-05A) — bukan angka palsu.

## A8. Gate keputusan (kapan hybrid "menang")

Kandidat hanya dipilih bila pada test set:
- NDCG@10 ≥ baseline terbaik **dan** coverage tidak turun >10 poin persentase
  relatif terhadap baseline; ATAU trade-off lain didokumentasikan di model card
  dengan alasan bisnis (mis. coverage dinaikkan, NDCG sedikit turun).
Jika tidak → rilis memakai baseline terbaik (tetap model terpilih, tetap jujur).

## A9. Cold-start strategy (diurutkan, PRD §13.1)

1. preferensi onboarding; 2. content-based; 3. relevansi kampus/geo;
4. sinyal verified (rating, owner terverifikasi);
5. popularity **hanya** tie-breaker/fallback.
Listing baru: metadata + geo + harga/fasilitas + verified status —
tanpa penalti nol-interaksi (dievaluasi via cold-start subset).

## A10. Fallback produksi

Model/endpoint gagal atau >timeout → ranking fallback content-based →
popularity; feed tidak pernah kosong (AC-REC-03); `recommendation_logs`
menandai `model_version` fallback (`baseline-*`).

---

# Part B — ML-2 Aspect-Based Review Analysis

## B1. Tugas & output

Input: teks review **approved** dari verified tenancy.
Output per aspek (8): `positive | negative | neutral | insufficient_evidence`
+ confidence; disimpan ke `review_aspect_scores` (source=nlp).
Teks asli TIDAK pernah diubah (AC-NLP-03).

## B2. Taxonomy (label v0 — dikunci)

| Aspect key | Definisi operasional (untuk anotator) | Contoh cue |
|---|---|---|
| cleanliness | kebersihan kamar/area/lifetime kebersihan | "bersih", "debu", "kumuh" |
| security | keamanan fisik & akses, penghuni, jaminan barang | "aman", "gerbang", "curian" |
| internet | WiFi/kuota/stabilitas koneksi | "wifi lambat", "sinyal" |
| water | air bersih, tekanan, mati air, panas | "air mati", "panas" |
| comfort | kenyamanan ruang, suhu, ukuran, kebisingan | "sejuk", "sempit", "berisik" |
| access | jarak/aksesibilitas ke jalan/kampus, parkir | "dekat kampus", "gang sempit" |
| owner | respons/responsivitas/pemilik manajemen | "ramah", "lambat respon" |
| value | kesesuaian harga dengan mutu | "worth it", "mahal" |

Label per baris-aspek: `positive / negative / neutral / insufficient_evidence`
(contoh: teks menyebut aspek tapi tanpa penilaian → insufficient_evidence).

## B3. Sumber data & strategi labeling (legal & realistis)

1. **Sumber primer:** teks review platform (UGC) — dasar legal = lisensi UGC
   dalam ToS v1.0 yang diterima saat registrasi (FR-AUTH-06); review adalah
   konten yang memang dibuat untuk konsumsi publik/produk.
2. **Volume realistis:** pilot Padang → review awal diprediksi sedikit.
   Strategi:
   - **Label manual** subset anotasi oleh tim (≥2 anotator, panduan di bawah),
     hitung agreement (Cohen's kappa) pada ≥20% sampel; jika ≤0.6 → diskusi &
     revisi guideline sebelum lanjut.
   - **Rule/lexicon baseline** dapat berjalan tanpa label besar (eksplorasi).
   - Kandidat transformer hanya bila jumlah label terstruktur memadai
     (diputuskan di CP-03B setelah menghitung data aktual — **tanpa
     mengarang angka**).
3. Dataset card mencantumkan: sumber, rentang tanggal, jumlah dokumen,
   distribusi label, kebijakan missing/insufficient, pembatasan PII
   (panduan penulis review tanpa nama/nomor).

## B4. Labeling guideline v0 (ringkas; versi penuh di CP-03B)

- Baca satu review → ekstrak kalimat per aspek → beri label per aspek yang
  disebut; aspek tidak disebut = TIDAK dibuat barisnya (bukan neutral).
- Satu aspek dua opini bertentangan → `neutral` + catatan; yakin salah satu →
  label dominan.
- Sindiran negatif tanpa kata eksplisit → boleh dipahami dari konteks;
  meragukan → `insufficient_evidence`.
- Jangan menyimpulkan fakta objektif dari opini (PRD guardrails).
- Inter-annotator check ≥20% sampel.

## B5. Baseline & kandidat, evaluasi

| | Model |
|---|---|
| Baseline | lexicon/keyword + aturan (kata kunci Indonesia per aspek) |
| Alternatif | TF-IDF + linear classifier (logreg/SGD) bila label ≥ tersedia |
| Kandidat | transformer Bahasa Indonesia bila dataset legal + label memadai + biaya feasible (AGENTS §11) |

Metrik: **Macro F1**, per-class precision/recall, confusion matrix,
error analysis (wajib kutip contoh kegagalan nyata).
Low-confidence → `insufficient_evidence` (guardrail PRD).

## A11. Reproducibility (kedua model)

Setiap run menyimpan: dataset_version, code commit, seed, dependencies
(`requirements.txt`/lock), parameters, artifact URI, metrics, timestamp →
tabel `model_versions` + `experiments/` log (AGENTS §11.5).
Run ulang dengan seed sama → metrik identik (NFR-ML-01).

## Fallback produksi (ML-2)

NLP gagal/tidak tersedia → fitur ringkasan aspek menampilkan ringkasan
**structured rating** saja; aplikasi tetap utuh (AGENTS §11.7).
