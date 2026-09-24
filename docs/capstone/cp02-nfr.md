# CP-02 — Non-Functional Requirements (NFR)

Date: 2026-09-25
Status: LOCKED V1.
Aturan penulisan: setiap NFR punya **definisi operasional terukur** —
kata "cepat/bagus/akurat" dilarang tanpa ambang/ukuran.

---

## NFR-PERF — Performa

| ID | Requirement | Ukuran / ambang | Verifikasi |
|---|---|---|---|
| NFR-PERF-01 | Halaman list menampilkan ≤20 row per halaman (pagination) | ≤20 row/halaman; total query per load ≤1 (data)+≤2 (count/related) | review query + test |
| NFR-PERF-02 | First content list tampil dalam ≤2,5 detik pada perangkat menengah + throttle Fast 3G (p50) | diukur integrasi test / DevTools trace, 3 run | TP-PERF-01 (CP-05A) |
| NFR-PERF-03 | Query pencarian dijalankan di server (Postgres), bukan memuat semua row ke device | tidak ada SELECT * full-table pada jalur search (audit query code) | code review |
| NFR-PERF-04 | Marker clustering otomatis bila >100 marker dalam viewport | threshold 100; interaksi pan tidak men-drop frame >16 ms rata-rata (DevTools) | TP-MAP-06 |
| NFR-PERF-05 | Foto diunggah dikompres sebelum upload | ukuran terkirim ≤1 MB/foto; thumbnail ≤200 KB | upload pipeline test |
| NFR-PERF-06 | Gambar memakai cache + placeholder + error fallback | 100% widget gambar punya placeholder & errorBuilder (audit widget) | code review |
| NFR-PERF-07 | Debounce input pencarian & viewport | search input ≥300 ms; viewport ≥300 ms | TP-MAP-02 |
| NFR-PERF-08 | Spatial query memakai index (GIST) | `EXPLAIN` menunjukkan index scan pada bbox/nearby fixture | TP-GIS-03 |

## NFR-REL — Reliability

| ID | Requirement | Ukuran | Verifikasi |
|---|---|---|---|
| NFR-REL-01 | Semua layar punya state loading/empty/error | 100% layar data-driven punya 3 state (checklist DESIGN §33–35) | widget test per screen |
| NFR-REL-02 | Operasi penting idempotent (accept request, mark paid) | double-submit tidak menggandakan row (AC-TEN-02) | TP-TEN-02 |
| NFR-REL-03 | Input user tidak hilang saat submit gagal | form mempertahankan nilai setelah error jaringan (uji manual + widget test) | TP-OFF-01 |
| NFR-REL-04 | Mode offline/putus jaringan menampilkan banner + cache bila ada | banner tampil dalam ≤2 detik setelah request gagal; last-good data dipakai | TP-OFF-01 |
| NFR-REL-05 | Tidak ada status pembayaran yang berubah gara-gara retry ganda | status hanya berubah via aksi owner (FR-OWN-06) | TP-PAY-04 |

## NFR-SEC — Security

| ID | Requirement | Ukuran | Verifikasi |
|---|---|---|---|
| NFR-SEC-01 | RLS aktif di SEMUA tabel ber-data user/operasional | 100% tabel dalam `cp02-schema-draft.md` punya RLS enable + policy | TP-RLS-* (matrix) |
| NFR-SEC-02 | Tidak ada secret/service-role di bundel | scan string APK/source = 0 match `service_role`/private key | TP-SEC-01 (CI) |
| NFR-SEC-03 | Aksi admin tercatat audit_logs | 100% aksi FR-ADM-02..04 menghasilkan ≥1 audit row | TP-ADM-06 |
| NFR-SEC-04 | Bucket privat (dokumen verifikasi/bukti bayar) tidak dapat diakses tanpa signed URL | 403/400 untuk anon (AC-STOR-01) | TP-STOR-01 |
| NFR-SEC-05 | Password minimum 8 karakter; tidak ada password yang di-log | validasi client+server; log scan 0 match password | TP-AUTH-01 |
| NFR-SEC-06 | Migrasi selalu versioned, tidak ada edit skema manual di produksi | file `supabase/migrations/<ts>_*.sql` per perubahan | process check |

## NFR-ACC — Accessibility & UX layout

| ID | Requirement | Ukuran | Verifikasi |
|---|---|---|---|
| NFR-ACC-01 | Touch target minimum | ≥44×48 dp semua tombol interaktif | accessibility audit / ukur widget |
| NFR-ACC-02 | Kontras teks | rasio ≥4,5:1 (teks normal) terhadap latar | contrast checker token DESIGN |
| NFR-ACC-03 | State tidak hanya warna | ikon/label ikut menyertai status (paid/overdue/verified) | design QA checklist |
| NFR-ACC-04 | Semantic label | ikon-only button punya Semantics label | widget test semantics |
| NFR-ACC-05 | Font scaling | 200% text scale pada 360dp tanpa pemotongan teks kritis (judul, harga, tombol utama) | TP-LAY-01 |
| NFR-ACC-06 | Aksi map punya alternatif list | seluruh akses listing tersedia di mode list | design review |

## NFR-LAY — Layout matrix

| ID | Requirement | Ukuran |
|---|---|---|
| NFR-LAY-01 | Validasi lebar layar | 360×800, 390×844, 430×932 lolos tanpa overflow (DESIGN §39) |
| NFR-LAY-02 | Keyboard terbuka | field terakhir tidak tertutup keyboard saat submit form |
| NFR-LAY-03 | Teks panjang | nama property 60 karakter + alamat 150 karakter tidak overflow |

## NFR-PRIV — Privacy (ringkas; detail di `cp02-privacy.md`)

| ID | Requirement | Ukuran |
|---|---|---|
| NFR-PRIV-01 | Lokasi on-demand, tanpa background, tanpa riwayat | 0 permission saat alur tanpa "Near me"; 0 kolom lokasi user di skema |
| NFR-PRIV-02 | Data minimum | event analytics tidak berisi nama/phone/koordinat presisi |
| NFR-PRIV-03 | Dokumen privat | bucket private + signed URL (NFR-SEC-04) |
| NFR-PRIV-04 | Consent dapat ditarik & akun dapat dihapus | AC-PRIV-02/03 terverifikasi |

## NFR-ML — Kualitas model (lintas CP-03..CP-05)

| ID | Requirement | Ukuran |
|---|---|---|
| NFR-ML-01 | Baseline dapat direproduksi | run ulang dengan seed & dataset version sama → metrik identik (selisih 0) |
| NFR-ML-02 | Tidak ada klaim tanpa artifact | setiap angka metrik punya run log + dataset card + model card |
| NFR-ML-03 | Fallback rekomendasi selalu tersedia | feed tidak kosong bila ada ≥1 listing (AC-REC-03) |
| NFR-ML-04 | Inference tersedia pada feed | p95 latency inference ≤2000 ms atau fallback ranking dipakai (keputusan akhir CP-04B) |
| NFR-ML-05 | Skor tidak dipresentasikan sebagai probabilitas | AC-REC-04 |

## NFR-OPS — Operasional

| ID | Requirement | Ukuran |
|---|---|---|
| NFR-OPS-01 | Seed data demo terdokumentasi & bukan hasil scraping pihak ketiga | `supabase/seed/` + keterangan sumber |
| NFR-OPS-02 | Build Android rilis lolos tanpa error signing debug | `flutter build apk --release` sukses |
| NFR-OPS-03 | Batas kuota Supabase free tier dipantau | cek storage/MAU bulanan; kompresi gambar (NFR-PERF-05) sebagai mitigasi |
