# CP-01 — Current Journey, Pain Synthesis, Opportunity Statements

Date: 2026-09-25 (updated: evidence E-001/E-002 masuk)
Status: **terdukung evidence sekunder/proxy** (`cp01-evidence-log.md`);
primer Padang masih disarankan (R-011).

---

# 1. Current journey — Seeker (terkonfirmasi sekunder)

```text
[H1] Butuh kos (kuliah/pindahan)
  → [H2] Buka Mamikos/Google Maps/FB/grup WA + tanya kenalan   ← E-001 P1
  → [H3] Kumpulkan kandidat; cek WA pemilik; baca review        ← E-001 P1, P5
  → [H4] Bandingkan budget, jarak/waktu, fasilitas wajib        ← E-001 P2, P4
  → [H5] Chat 1:1 verifikasi masih kosong (sering penuh/stale)  ← E-001 P3, P5
  → [H6] Survei langsung; deal; transfer manual                 ← E-001 P1, P6
  → [H7] Tinggal: ingat jatuh tempo sendiri / diingatkan pemilik ← E-001 P6
  → [H8] Keluhan via chat; pengalaman tidak terkumpul            ← E-002 S2.4
  → [H9] Perpanjang/pindah → siklus ulang dari [H2]
```

# 2. Current journey — Owner (terkonfirmasi sekunder)

```text
[O1] Listing multi-channel (platform, IG, maps, mulut)      ← E-002 S2.2
  → [O2] Calon masuk via WA/kenalan/datang langsung           ← E-002 S2.2
  → [O3] Status kamar: buku/Excel/ingatan (tanpa SSOT)        ← E-002 S2.1
  → [O4] Pembayaran transfer, dicek 1:1, reminder manual WA    ← E-002 S2.3
  → [O5] Komplain di chat campur tagihan (mudah tenggelam)     ← E-002 S2.4
  → [O6] Kamar kosong → pasarkan lagi → [O1]
```

# 3. Pain-point synthesis (semua terdukung)

| Pain | Hipotesis | Subjek | Evidence |
|---|---|---|---|
| Pencarian multi-kriteria melelahkan; banyak pilihan ≠ cocok (search cost) | H-01, H-05 | S1 | E-001 P2,P3,P7 ✓ |
| Yang penting waktu tempuh, bukan jarak lurus | H-01 (GIS) | S1 | E-001 P4 ✓ |
| Info listing stale → wajib verifikasi manual | H-01, H-04 | S1 | E-001 P1,P5; Mamikos help center ✓ |
| Lifecycle sewa manual → riskan telat/tidak terlacak | H-02 | S1+S2 | E-001 P6; E-002 S2.3 ✓ |
| Kamar/penghuni/pembayaran tanpa SSOT | H-03 | S2 | E-002 S2.1-S2.3 ✓ |
| Keluhan tenggelam di chat | H-03 | S2 | E-002 S2.4; KostEZ QR-complain ✓ |

# 4. Opportunity statements (need terkonfirmasi; solusi tetap dirancang di CP-02/03)

- **O-1 (S1):** shortlist 3 kos cocok budget+kampus dalam menit, bukan berjam-jam scroll + chat 1:1. ← H-01/H-05, E-001 P3,P7
- **O-2 (S1):** keputusan berbasis travel accessibility (menit), bukan tebakan jarak — tanpa ETA palsu. ← E-001 P4; routing valid = CP-03
- **O-3 (S1+S2):** listing yang jujur (last availability update + owner verified) + review dari penghuni terverifikasi. ← H-04, E-001 P5
- **O-4 (S1+S2):** jatuh tempo terjadwal + pengingat + riwayat pembayaran tanpa gateway penuh. ← H-02, E-001 P6 + E-002 S2.3
- **O-5 (S2):** SSOT kamar + feedback terstruktur (bedakan feedback vs maintenance) → perbaikan terarah. ← H-03, E-002 S2.1,S2.4

# 5. Kaitan ke ML & GIS (justifikasi — task, bukan klaim metrik)

| Kebutuhan | Peran teknologi | Boundary jujur |
|---|---|---|
| H-05 (filter ≠ ranking) | ML-1 ranking personal after filter; baseline dulu | **Belum ada angka performa** — CP-03 |
| H-01 (waktu tempuh) | GIS: nearby, distance, campus-aware; travel time bila routing valid | ETA/isochrone P1; fallback distance-only |
| H-04 (trust) | Verified tenancy → eligibility review; listing accuracy + owner verification; ML-2 nanti | NLP butuh data valid (CP-04B) |
| H-02/H-03 (lifecycle manual) | Mobile app + local notif (A-06 validated lemah) | Primer Padang disarankan untuk memperkuat (R-011) |
