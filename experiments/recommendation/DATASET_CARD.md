# Dataset Card — KOSTARA Recommendation (v0)

Status: **dev / synthetic** — CP-03B.
Dataset version: lihat `data/raw/DATASET_VERSION.txt` (content-hash ekspor).
Ekspor: `experiments/recommendation/export_dataset.py` (service key dari
Aman.md, tidak pernah di repo).

## Sumber & legalitas

- Baris berasal dari **seed dev sintetis** (`supabase/seed/seed_data.sql`),
  dibuat untuk pengujian RLS/spatial/ML di environment development.
- **Bukan data produksi, bukan data pengguna nyata.** Semua angka/evaluasi
  dari dataset ini adalah hasil eksperimen pada data karangan dan TIDAK boleh
  dipresentasikan sebagai performa produk (AGENTS §4.4).
- Data produksi (CP-04+) berasal dari penggunaan app sendiri; interaksi
  hanya dikumpulkan dengan consent (FR-PRIV-02) dan review berlisensi UGC
  di ToS v1.0.

## Ruang lingkup

| File | Baris (v0) | Isi |
|---|---|---|
| events.parquet | 1200 | interaksi 3 seeker konsen × 10 properti × 45 hari |
| properties.parquet | 12 | 10 verified+active, 2 draft |
| rooms.parquet | 40 | harga/tipe/status kamar |
| property_facilities.parquet | 37 | relasi properti–fasilitas |
| facilities.parquet | 10 | master fasilitas |
| campuses.parquet | 5 | kampus Padang (koordinat ≈ titik publik, dev fixture) |
| reviews.parquet | 4 | 3 approved + 1 pending |
| owner_profiles.parquet | 2 | owner terverifikasi (fixture) |
| user_preferences.parquet | 4 | preferensi onboarding; seeker4 tanpa consent |

## Skema & definisi

- `event_type`: taxonomy tertutup (app_open … review_submit) — lihat
  cp02-analytics-events.
- `event_weight`: bobot desain **hipotesis** (AGENTS §11.3):
  impression 0 · view 1 · save 3 · compare 2 · request 5 · tenancy 8.
  Parameter desain, bukan truth — diuji di eksperimen.
- Split: **temporal 70/10/20** pada `occurred_at` (urutan deterministik
  `(occurred_at, user_id, property_id, event_type, session_id)`).

## Keterbatasan (wajib dibaca sebelum klaim metrik)

1. **Sintetis & sangat kecil** (3 user, 10 item, 1 run) — metrik
   popularitas NDCG@10 = 1.0 adalah artefak data kecil, bukan bukti model
   bagus.
2. `n_test_positives_filtered = 21`: hard filter preferensi memangkas
   sebagian besar positif test — mencerminkan perilaku filter produk;
   dicatat agar tidak disembunyikan.
3. Subgroup cold-start kosong (`n_cold_users = 0`) pada seed ini —
   cold-start evaluation menunggu data dengan user baru (CP-04+).
4. Representativeness: hanya 1 kota (Padang), preferensi seed sederhana.
   Bias listing/owner tidak terukur pada data ini.

## Reproducibility

- Ekspor ulang data sama → `dataset_version` identik (content-hash).
- `run_baselines.py` menjalankan pipeline 2× dan membandingkan metrik
  (gagal = DETERMINISM FAIL). Manifest per run:
  `experiments/recommendation/runs/<ts>/manifest.json`
  (commit, seed, params, dependencies via requirements.txt).
- Pendaftaran registry: baris `model_versions` status `draft`
  (aktifkan hanya setelah keputusan CP-04B, VALIDATION_PROTOCOL §18).

## Perubahan ke data produksi (CP-04+)

Wajib memperbarui kartu ini: sumber, rentang tanggal, jumlah baris,
distribusi event, kebijakan consent, representativeness pilot.
