# DATA_PROVENANCE.md — Sumber data pihak ketiga & keputusan legalitas

Catatan wajib untuk setiap data eksternal yang masuk pipeline (ML_PRICE_INTELLIGENCE §19).
Raw files TIDAK pernah di-commit (`data/raw/` di `.gitignore`).

## AirROI Asia-Pacific (public benchmark)

- Sumber: Kaggle `jasonairroi/airbnb-market-data-asia-pacific`
  (AirROI, airroi.com) — unduh resmi via `experiments/price/download_airroi.py`.
- Lisensi: **CC BY-NC 4.0** (NonCommercial) — atribusi: "Airbnb Market Data:
  Asia-Pacific, Jason from AirROI, via Kaggle".
- Keputusan: hanya untuk **pipeline development / benchmark method**
  (namespace `benchmark_airroi_apac`) — **tidak pernah masuk training
  KOSTARA**, tidak didistribusikan ulang, tidak untuk produk komersial.
  Produk KOSTARA tidak bergantung pada data ini (training final memakai
  observasi KOSTARA sendiri, §3.2).
- Checksum per file terpinned di `experiments/price/download_airroi.py`
  (PINNED_SHA256) — gagal cocok = upstream berubah → perbarui eksplisit.
- Tidak ada konten yang dimodifikasi in-place; olahan selalu tulis ke
  `data/interim|processed`.

## Batas administrasi kecamatan (districts)

- Sumber: github.com/cahyadsn/wilayah_boundaries — file
  `db/kec/wilayah_boundaries_kec_13.sql` (Sumbar), dasar hukum Kepmendagri
  300.2.2-2430/2025, lisensi MIT (kode repo); sha256 seed tercatat di
  header migrasi `20260925010017_padang_districts.sql`.
- Filter `13.71.*` = 11 kecamatan Kota Padang; disimpan sebagai referensi
  publik (read-only) di tabel `districts`.
- Keputusan: geoservices.big.go.id (sumber primer) tidak terjangkau dari
  environment dev (timeout) → memakai mirror GitHub di atas; subdistrict/
  kelurahan = NULL di V1 (data gap, bukan tebakan koordinat).
- Tie-break titik pada poligon tumpang tindih (Pauh × Koto Tangah, overlap
  ~1,1 km²): `order by kode limit 1` — didokumentasikan, bukan diam-diam.

## Larangan yang tetap berlaku

- Mamikos / listing pihak ketiga: tidak ada crawler, tidak ada data
  karangan (ML_PRICE_INTELLIGENCE §19, AGENTS §4.4).
- Kredensial (Supabase, Kaggle) hanya lokal: `Aman.md` / `~/.kaggle/` —
  tidak pernah di-repo.
