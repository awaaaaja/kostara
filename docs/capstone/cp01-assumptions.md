# CP-01 — Assumptions Register

Date: 2026-09-25
Status legend: `validated` (ada evidence mendukung) / `rejected` (evidence menolak) / `unknown` (default, belum ada evidence)

**Rekap: validated = 0 · rejected = 0 · unknown = 9** — konsisten dengan evidence log kosong.

| ID | Asumsi | Asal | Status | Bukti | Tindakan jika ditolak |
|---|---|---|---|---|---|
| A-01 | Pencari (mahasiswa Padang) sulit memutuskan kos multi-kriteria secara manual | PRD §2.1 | unknown | pending interview S1 | Re-frame; pangkas scope discovery |
| A-02 | Pemilik kos kesulitan kelola availability/tenant/payment/feedback di satu tempat | PRD §2.3 | unknown | pending interview S2 | Pangkas owner features ke minimum |
| A-03 | Review tanpa verifikasi menurunkan kepercayaan pencari | PRD §2.4 | unknown | pending S1+S2 | Verified-feedback jadi P1, bukan P0 |
| A-04 | Aplikasi pencarian kehilangan nilai setelah user dapat kos (lifecycle terpencar) | PRD §2.2 | unknown | pending S1 | Tenancy/reminder turun prioritas — nilai produk berubah, catat di PRD |
| A-05 | Filter saja tidak cukup → recommendation ML memberi nilai terukur di atas filter/popularity | PRD §13.1 | unknown | pending S1 (skt. 7) + data interaksi nanti | **Cut scope ML-1 ke baseline/popularity; jangan paksa hybrid** (SPRINTS Sprint 1 FIX) |
| A-06 | Mobile adalah kanal tepat (target device & konteks pemakaian) | agent hypothesis | unknown | pending S1/S2 device usage | Evaluasi web/loket alternatif; dokumentasikan di ADR |
| A-07 | Data yang dibutuhkan (preferensi, interaksi, review) bisa dikumpulkan legal & dengan consent | PRD §16, privacy rules | unknown | pending — checklist privacy + persetujuan wawancara sudah dijalankan untuk riset ini | Reduksi event collection; privacy note di PRD |
| A-08 | Pilot Kota Padang layak (kepadatan kos, kampus, akses stakeholder) | PRD initial market | unknown | pending — sampling plan di interview plan | Ganti lokasi pilot / perluas, keputusan owner |
| A-09 | Routing provider tersedia untuk travel time (P1) | PRD §14.4 | unknown | feasibility teknis = CP-03 | Fallback distance-only (wajib, sudah aturan) |

## Justifikasi singkat (belum boleh diklaim final)

- **ML task yang didukung (bila A-05 valid):** meranking kandidat kos untuk
  seeker X dengan budget/campus/facility/trust signals — bukan klasifikasi
  atau generation. Baseline wajib: popularity/filtered + content-based
  (AGENTS §11.2). Hybrid hanya bila data interaksi cukup.
- **GIS (bila A-01 valid):** jarak/distance ke kampus adalah atribut
  keputusan nyata → nearby/viewport/distance filter = fungsi, bukan
  dekorasi. ETA/isochrone tetap P1 dan tidak boleh dipalsukan.
- **Verified feedback (bila A-03 valid):** eligibility server-side dari
  tenancy → data review legal untuk diringkas (ML-2), identitas minim.
- **Mobile (bila A-06 valid):** konteks pencarian + pengingat tempat user
  berada; justifikasi akhir tetap butuh jawaban interview.

## Rule

Setiap kali `cp01-evidence-log.md` dapat entri baru:
1. cocokkan ke A-01..A-09;
2. ubah status + isi kolom Bukti;
3. bila A-05/A-06/A-08 rejected → update PRD + SPRINTS lewat change note (change log di LOGBOOK), jangan diiamkan.
