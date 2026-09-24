# CP-01 — Current Journey, Pain Synthesis, Opportunity Statements

Date: 2026-09-25
Status: **HIPOTESIS (belum divalidasi evidence).** Entri evidence = 0.
Setiap langkah di bawah wajib dikonfirmasi/ditolak lewat `cp01-interview-plan.md`.

---

# 1. Current journey — Seeker (diramalkan, PENDING validasi)

```text
[H1] Butuh kos (kuliah/pindahan)
  → [H2] Tanya kenalan / scroll IG / grup WA / buka aplikasi listing
  → [H3] Kumpulkan kandidat manual (screenshot, notes, chat)
  → [H4] Bandingkan budget, jarak, fasilitas — di kepala/spreadsheet
  → [H5] Kunjungi/cek langsung beberapa kandidat
  → [H6] Hubungi pemilik, deal, bayar deposit/awal
  → [H7] Tinggal: catat jatuh tempo sendiri, bayar manual
  → [H8] Ada masalah? Chat pemilik; pengalaman tidak dikumpulkan
  → [H9] Perpanjang atau pindah → siklus mulai lagi dari [H2]
```

Pertanyaan wajib saat interview: langkah mana yang benar? mana yang dilewati? di mana paling sakit?

# 2. Current journey — Owner (diramalkan, PENDING validasi)

```text
[O1] Pasarkan listing (mulut ke mulut / IG / situs)
  → [O2] Terima calon (WA/telpon), jelaskan manual
  → [O3] Catat penghuni & kamar (buku / notes / ingatan)
  → [O4] Tagih & catat pembayaran (manual, riwayat tercecer)
  → [O5] Tanggap keluhan/perbaikan (chat pribadi)
  → [O6] Penghuni pergi → kosongkan → kembali ke [O1]
  → Feedback tidak terstruktur; tidak ada ringkasan aspek
```

# 3. Pain-point synthesis

| Pain | Hipotesis | Subjek | Evidence |
|---|---|---|---|
| Pencarian multi-kriteria melelahkan, hasil tidak "cocok" | H-01, H-05 | S1 | PENDING |
| Tidak ada pegangan jarak/waktu ke kampus yang bisa dipercaya | H-01 (GIS) | S1 | PENDING |
| Sulit mempercayai review | H-04 | S1 | PENDING |
| Setelah sewa, pengingat/pencatatan sewa manual → riskan lupa/telat | H-02 | S1 | PENDING |
| Stok kamar & pembayaran dicatat terpencar → salah/repot | H-03 | S2 | PENDING |
| Masukan penghuni tidak terkumpul jadi perbaikan | H-03, H-04 | S2 | PENDING |

**Belum ada pain yang boleh dinyatakan "terbukti".**

# 4. Opportunity statements

Format: "Bagaimana kalau <subjek> bisa <outcome> tanpa <beban lama>?"
Semua PENDING konfirmasi kebutuhan.

- **O-1 (S1):** Bagaimana kalau pencari bisa menyusun daftar pendek 3 kos yang cocok budget+kampus dalam hitungan menit, bukan berjam-jam scroll? *(butuh: H-01/H-05 terbukti)*
- **O-2 (S1):** Bagaimana kalau keputusan pakai jarak ke kampus yang akurat-secara-cukup tanpa terka ETA palsu? *(butuh: H-01 terbukti; feasibility routing = CP-03)*
- **O-3 (S1):** Bagaimana kalau review jelas berasal dari penghuni terverifikasi sehingga layak dipercaya? *(butuh: H-04 terbukti)*
- **O-4 (S1+S2):** Bagaimana kalau jatuh tempo sewa terjadwal + pengingat bersama, tanpa gateway pembayaran penuh? *(butuh: H-02/H-03 terbukti; V1 = record & reminder, PRD §9.5)*
- **O-5 (S2):** Bagaimana kalau pemilik melihat ringkasan aspek (kebersihan/internet/…) dari feedback nyata untuk memperbaiki kos? *(butuh: H-03 terbukti; data review = CP-04B)*

# 5. Kaitan ke ML & GIS (justifikasi, bukan klaim)

| Kebutuhan | Bila terbukti… | Peran teknologi | Bila TIDAK terbukti… |
|---|---|---|---|
| H-05/A-05: filter tidak cukup | rec-ML punya tugas nyata: ranking kandidat sesuai preferensi+geospasial (RQ-1) | ML-1 (baseline → hybrid, CP-03B) | rec-ML jadi P1/POC; V1 cukup filter + popularity baseline; **catat sebagai cut scope** |
| H-01: jarak ke kampus menentukan pilihan | GIS = fungsi nyata (nearby, distance filter, campus-aware) | PostGIS query (PRD §14) | GIS cukup pin lokasi statis; jangan klaim "geospatial intelligence" |
| H-04: trust review | verified tenancy → eligibility review + NLP aspek berguna | ML-2 (CP-04B) | structured rating saja; NLP tunda |
| H-02/H-03: lifecycle terpencar | mobile app justified (dibawa ke mana-mana, notif lokal) | Flutter + local notif | validasi dulu kanal apa yang mereka pakai; jangan asumsikan app baru = solusi |

**Kenapa mobile (hipotesis, PENDING):** segmen mahasiswa mengakses lewat
HP; pencarian & pengingat terjadi konteks mobile. Wajib dikonfirmasi di
interview (S1/S2 device & channel usage) sebelum dijadikan alasan resmi.
