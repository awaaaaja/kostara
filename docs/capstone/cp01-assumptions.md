# CP-01 — Assumptions Register

Date: 2026-09-25 (updated: evidence E-001/E-002 masuk)
Status legend: `validated` (evidence mendukung) / `rejected` (evidence menolak) / `unknown` (belum ada evidence)

**Rekap: validated = 6 · rejected = 0 · unknown = 3** (A-07, A-08, A-09)

Basis evidence: `cp01-evidence-log.md` (sekunder/proxy + verifikasi sumber publik 2026-09-25).

| ID | Asumsi | Asal | Status | Bukti | Tindakan jika ditolak |
|---|---|---|---|---|---|
| A-01 | Pencari sulit memutuskan kos multi-kriteria secara manual | PRD §2.1 | **validated** (secondary) | E-001 (P2, P3, P7): budget+jarak+fasilitas+aturan; search cost tinggi; banyak pilihan ≠ relevan | Re-frame; pangkas scope discovery |
| A-02 | Pemilik kesulitan kelola availability/tenant/payment/feedback di satu tempat | PRD §2.3 | **validated** (secondary) | E-002 (S2.1-S2.5); pasar: OpenKOS, KostEZ, SuperKos, kospay.id, SIKOSSANKU semua menjual solusi pola buku/Excel/WA | Pangkas owner features ke minimum |
| A-03 | Review/info tanpa verifikasi menurunkan kepercayaan pencari | PRD §2.4 | **validated** (secondary) — *direframe*: masalah inti = trustworthiness of listing information (availability/fasilitas stale), review verified = salah satu solusi | E-001 (P5); Mamikos Help Center resmi mengakui iklan tidak update & beda saat survei | Verified-feedback tetap P0? evaluasi turun ke P1 bila fokus cukup di listing accuracy |
| A-04 | Aplikasi pencarian kehilangan nilai setelah user dapat kos (lifecycle terpencar) | PRD §2.2 | **validated** (secondary) | E-001 (P6) + E-002 (S2.3): transfer manual, bukti di chat, reminder manual, riwayat sulit dibuktikan | Tenancy/reminder turun prioritas — catat di PRD |
| A-05 | Filter saja tidak cukup → recommendation ML nilai terukur di atas filter/popularity | PRD §13.1 | **validated** (secondary, untuk *keberadaan tugas*) | E-001 (P7): filter mengurasi, tidak menranking sesuai prioritas; P2: prioritas bertingkat (required vs optional) | Cut scope ML-1 ke baseline; **catatan: validasi = task justified; performa model tetap wajib eksperimen CP-03** |
| A-06 | Mobile kanal tepat (device & konteks pemakaian) | agent hypothesis | **validated** (secondary, lemah) | E-001: kanal utama = aplikasi listing, Google Maps, WA — semua mobile-first | Evaluasi alternatif; ADR bila berubah |
| A-07 | Data (preferensi, interaksi, review) bisa dikumpulkan legal + consent | PRD §16 | unknown | belum disentuh evidence | Reduksi event collection; privacy note di PRD (CP-02) |
| A-08 | Pilot Kota Padang layak (kepadatan kos, kampus, akses stakeholder) | PRD initial market | unknown | evidence E-001/E-002 umum Indonesia, **bukan spesifik Padang** | Ganti/perluas pilot — keputusan owner |
| A-09 | Routing provider tersedia untuk travel time (P1) | PRD §14.4 | unknown | feasibility teknis = CP-03 | Fallback distance-only (wajib) |

## Justifikasi (diperbarui dengan evidence)

- **ML task (A-05 validated):** ranking kandidat kos per seeker
  (budget/campus/facility/trust + preferensi bertingkat), AFTER hard
  filter — bukan menggantikan filter. Baseline wajib popularity +
  content-based (AGENTS §11.2); hybrid hanya bila data interaksi cukup.
  *Belum ada klaim performa — itu urusan eksperimen CP-03.*
- **GIS (A-01 + E-001 P4 validated):** waktu tempuh (bukan jarak lurus)
  adalah kriteria keputusan → nearby/viewport/travel-accessibility = fungsi
  nyata; ETA/isochrone tetap P1 tanpa routing valid (jangan dipalsukan).
- **Verified feedback (A-03 validated, direframe):** pelengkap ke
  listing-accuracy (last availability update + owner verification) untuk
  masalah trust; NLP aspek berguna bila review valid terkumpul (CP-04B).
- **Mobile (A-06 validated lemah):** kanal pencarian sudah mobile-first;
  justifikasi penuh diperkuat primer menyusul (R-011).

## Rule

Saat primer interviews (E-003..) masuk: cocokkan A-07/A-08 (fokus), ubah
status + kolom Bukti; bila ada yang **rejected** → update PRD + SPRINTS
lewat change note di LOGBOOK, jangan diiamkan.
