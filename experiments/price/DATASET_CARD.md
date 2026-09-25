# Dataset Card — AirROI Asia-Pacific public benchmark (v1)

Status: **PUBLIC BENCHMARK / dev-only** — ML_PRICE_INTELLIGENCE §3.1.
Namespace pemakaian: `benchmark_airroi_apac`. **Tidak pernah masuk training
KOSTARA** (train final = observasi KOSTARA, §3.2) dan tidak didistribusikan
— lihat `docs/DATA_PROVENANCE.md`.
Unduh: `experiments/price/download_airroi.py` (Kaggle resmi, checksum
terpinned). Raw tidak dimodifikasi in-place.

## Sumber & legalitas

- Kaggle `jasonairroi/airbnb-market-data-asia-pacific` — AirROI
  (airroi.com), static snapshot, update bulanan.
- Lisensi: **CC BY-NC 4.0** (NonCommercial + atribusi). Dipakai untuk
  pengembangan metode/benchmark internal capstone; komersialisasi data
  tidak dilakukan (produk tidak memakainya).
- Privasi: nama host dihapus oleh penerbit; `host_id` sudah SHA-256.
  Data yang sama (kami buang `host_id`, `cover_photo_url`, dan seluruh
  kolom `ttm_*`/`l90d_*`/`rating_*` dari fitur — lihat Leakage).
- Retrieved: 2026-09-26 UTC; sha256 per file: lihat
  `data/raw/price/public/airroi_apac/source_metadata.json` (raw,
  git-ignored) — nilai sama dengan `PINNED_SHA256` di download script.

## Ruang lingkup (dihitung dari file unduhan)

| File | Baris | Isi |
|---|---|---|
| listings.parquet | 29.440 | listing snapshot + metrik performa |
| listings.csv | 29.440 | format sama (CSV) |
| past_rates.parquet | 341.367 | tarif/occupancy bulanan per listing |
| past_rates.csv | 341.367 | format sama (CSV) |

- 14 negara, 113 kota APAC; Indonesia 2.747 listing — **0 baris Padang**
  (dataset ini memang bukan data domain KOSTARA).
- `past_rates`: 29.057 listing unik, 2025-02-01 … 2026-01-01 (bulanan).

## Skema & definisi (temuan inspeksi, bukan klaim penerbit)

- Semua kolom `listings` bertipe **string** di parquet → wajib casting
  numerik eksplisit di olahan.
- `ttm_avg_rate` = **USD** (verifikasi: rasio `ttm_avg_rate_native`
  per mata uang stabil — AUD 1,565 · KRW 1.406 · IDR 16.435 · JPY 146 ·
  SGD 1,305). `ttm_avg_rate_native` = mata uang lokal (campuran).
- `room_type` kanonik: `entire_home` 21.487 · `private_room` 6.626 ·
  `hotel_room` 409 · `shared_room` 252 · null 383; sisanya (~620) label
  jarang / data corrupt.
- Target kandidat benchmark: **`ttm_avg_rate` (USD/malam)** — tren
  perilaku model, bukan harga sewa bulanan KOSTARA.

## Data quality (dihitung, jujur)

1. **272 baris row-shift/corrupt** (kolom `room_type` berisi URL foto /
   fragmen kolom lain; contoh: `'110.3708'`, `' 3 bathrooms]"'`) →
   buang saat olah, jangan dipakai.
2. **11 duplikat `listing_id`** (29.440 baris → 29.429 unik).
3. `latitude` null 394 (1,3%); `bedrooms` null 22,8% dan maksimum 127,6
   (junk hasil row-shift); `instant_book` null 87,6%.
4. Skor `ttm_avg_rate_native`: min 0,027 · median 2.133,4 ·
   maks 48.748.763,6 — campuran mata uang, **tidak boleh dibaca
   sebagai satu skala harga**.
5. Sebaran kuota kota: ≤300 listing/kota (sampel, bukan populasi) —
   seleksi bias kota perlu dicatat di laporan benchmark.

## Leakage (wajib — §7 dilarang sebagai fitur core)

`ttm_*`, `l90d_*` (revenue/occupancy/revpar/avg_rate …), `num_reviews`,
`rating_*`, `superhost`, `professional_management` = metrik **masa
depan/berjalan setelah listing** → hanya untuk target/analisis, bukan
fitur prediktif listing baru. Fitur benchmark yang diizinkan: atribut
struktural (room_type, bedrooms, beds, baths, guests, amenities count,
min_nights, lat/lng, kota/negara).

## Keterbatasan (sebelum klaim metrik benchmark)

1. Bukan domain Padang — metrik di sini mengukur **pipeline/urutan
   eksperimen**, bukan kualitas rekomendasi harga KOSTARA.
2. Data corrupt 272 baris + duplikat 11 → cleaning wajib (Phase C),
   dokumentasikan jumlah baris terbuang per tahap.
3. Lisensi NC: artefak model yang dilatih **hanya** dari AirROI tidak
   boleh dikomersialkan — pastikan model produksi dilatih ulang dari
   data KOSTARA (tetap rencana §3.2).
4. Snapshot statis (bukan panel waktu per listing selain `past_rates`)
   → split temporal penuh hanya mungkin di `past_rates`.

## Reproducibility

```bash
.venv-ml/bin/python experiments/price/download_airroi.py --verify
```

- Checksum cocok = dataset sama dengan versi saat kartu ditulis;
  beda = upstream berubah → perbarui `PINNED_SHA256` + kartu secara
  eksplisit (jangan diam-diam).
- Kartu ini berisi angka hasil hitung dari file unduhan; tidak ada
  angka yang dikarang (AGENTS §4.4).
