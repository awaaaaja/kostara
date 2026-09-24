# CP-01 — Interview Evidence Log

Date: 2026-09-25
Status: **TERISI — evidence sekunder/proxy (bukan wawancara primer).**

> Provenance jujur: entri di bawah adalah **sintesis proxy respondent +
> diskusi/dokumen publik** yang disusun project owner, diverifikasi ulang
> oleh agent terhadap sumber publik (2026-09-25). Ini evidence nyata untuk
> keberadaan masalah, tetapi **bukan** sesi 1:1 dengan stakeholder Padang.
> Wawancara primer tetap disarankan (lihat R-011).

---

## Ringkasan

| Metrik | Nilai |
|---|---|
| Entri evidence sekunder (proxy/desk research) | 2 (E-001, E-002) |
| Sesi primer tatap muka | 0 (disarankan menyusul) |
| Hipotesis terdukung | H-01, H-02, H-03, H-04, H-05 |
| Hipotesis tertolak | 0 |
| Asumsi validated / rejected / unknown | 6 / 0 / 3 |

## Verifikasi sumber oleh agent (2026-09-25)

| Klaim dalam sintesis | Hasil verifikasi |
|---|---|
| Iklan/listing kos tidak update vs kondisi nyata | **TERKONFIRMASI** — Mamikos Help Center resmi: "Mengapa masih terdapat iklan kos yang tidak update"; "Mengapa kos yang saya survey berbeda dengan iklan" (help.mamikos.com) |
| Pemilik masih pakai buku/Excel/WA untuk kamar & pembayaran | **TERKONFIRMASI** — kopy positioning kospay.id ("Masih Pakai Buku atau Excel…?"), SIKOSSANKU ("tidak perlu lagi… buku ataupun Spreadsheet"), KostEZ ("5+ jam/minggu tagihan manual"), SuperKos, iKOS 365 |
| Platform manajemen kos = kategori produk nyata (billing, reminder WA, maintenance) | **TERKONFIRMASI** — OpenKOS (github.com/senatroxx/OpenKos: units/leases/invoices/payments/rent reminders/maintenance, WhatsApp driver), KostEZ (komplain via QR → WA), SuperKos (tagihan & reminder otomatis) |
| Keluhan penghuni tenggelam di chat WA | **TERKONFIRMASI** — KostEZ membangun sistem komplain QR eksplisit sebagai solusi |
| Keluhan Reddit spesifik (angka "90% penuh", dsb.) | Tidak diverifikasi per-thread (tanpa URL) — **dipakai sebagai anekdot directional, bukan angka baseline** |

## Entri

| ID | Kode | Tanggal | Metode | Kutipan/sintesis kunci (anonim) | Hipotesis/asetumsi | Dukung / Tolak | Catatan |
|---|---|---|---|---|---|---|---|
| E-001 | P1-P7 (seeker proxy) | 2026-09-25 | Sintesis diskusi publik (secondary) oleh owner; verifikasi sumber oleh agent | P1: mulai dari Mamikos/Maps → cek WA → survei langsung; online tidak selalu aktual. P2: budget → jarak/kampus → KM dalam/WiFi wajib; gugur kalau info online ≠ nyata. P3: capek chat 1:1, banyak yang penuh/tidak relevan (search cost tinggi). P4: yang penting waktu tempuh, bukan jarak lurus. P5: review tidak dipercaya penuh; masalah inti = trustworthiness listing. P6: bayar transfer + bukti di chat, tanpa reminder sistemik. P7: banyak pilihan ≠ cocok; filter mengurangi tapi tidak menranking sesuai prioritas | H-01, H-02, H-03 (sisi pencari), H-04, H-05; A-01, A-03, A-04, A-05, A-06 | Dukung | Sekunder; primer masih disarankan |
| E-002 | S2 (owner proxy) | 2026-09-25 | Sintesis dokumen produk + diskusi publik oleh owner; verifikasi sumber oleh agent | S2.1: kamar di buku/Excel/ingatan, tidak ada single source of truth. S2.2: leads masuk multi-channel → status kamar telat update → risiko double-booking/stale availability. S2.3: pembayaran dicek 1:1, riwayat sulit dibuktikan, reminder manual WA. S2.4: komplain tenggelam di chat campur tagihan. S2.5: waktu habis cek pembayaran + tagih + cek kamar kosong | H-02, H-03, H-04 (sisi owner); A-02, A-04 | Dukung | Diperkuat verifikasi produk pasar (OpenKOS/KostEZ/SuperKos/kospay) |

## Pemakaai selanjutnya

- Primer (opsional tapi disarankan): 3-5 seeker + 2-3 owner sesi nyata di Padang → tambah E-003.. untuk memperdalam + mengisi A-08 (spesifik Padang).
- Validator eksternal tetap direncanakan di CP-03 (PRD §4.2).
