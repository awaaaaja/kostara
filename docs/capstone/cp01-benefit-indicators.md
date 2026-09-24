# CP-01 — Measurable Benefit Indicators

Date: 2026-09-25 (updated: directional signal dari E-001/E-002)
Status: indikator & metode dikunci; **baseline kuantitatif PENDING**
(data primer/platform). Anekdot publik = directional, bukan target.
Kebijakan (PRD §25): dilarang menulis target numerik final tanpa baseline nyata.

---

| ID | Indikator | Definisi terukur | Sumber data | Baseline | Target | Kaitan |
|---|---|---|---|---|---|---|
| BI-1 | Waktu ke shortlist | Median menit dari mulai pencarian sampai ≥3 kandidat tersimpan | Interview primer → event `property_save` | Directional: proses multi-hari + banyak chat 1:1 + survei (E-001 P1,P3); primer TBD | TBD | H-01, H-05 |
| BI-2 | Keyakinan keputusan | Skalа 1-5 setelah shortlist/pilih | Interview / usability CP-03 | TBD | TBD | H-01, H-04 |
| BI-3 | Beban operasional owner | Median menit/minggu urus kamar + pembayaran | Interview owner | Directional: klaim produk pasar "5+ jam/minggu tagihan manual" (KostEZ) — sinyal pasar, bukan baseline KOSTARA | TBD | H-03 |
| BI-4 | Insiden pencatatan | Kegiatan salah-stok-kamar / selisih catat per bulan | Interview → `room status` | Directional: stale availability + tanpa SSOT (E-002 S2.1-S2.2) | TBD | H-03, H-01 |
| BI-5 | Review verified rate | % review lolos eligibility tenancy / semua review | `reviews` (CP-04B) | n/a pra-launch | TBD | H-04 |
| BI-6 | Ketepatan pengingat | % pembayaran tercatat ≤ due date | `payment_records` (CP-04B) | Directional: reminder manual WA / ingat-sendiri (E-001 P6, E-002 S2.3) | TBD | H-02 |
| BI-7 | Relevansi rekomendasi | Save/request rate feed personal vs non-personal | `interactions` | TBD (butuh data) | TBD | A-05, RQ-1 |
| BI-8 | Effort pencarian | Jumlah listing dibuka sebelum shortlist | `interactions` property_view | TBD | TBD | RQ-4 |

## Aturan main

1. **Baseline kuantitatif dari primer/platform dulu, target kemudian.**
2. Directional signal (anekdot/pesan pasar) **tidak boleh** dikutip sebagai "baseline KOSTARA" di laporan akhir.
3. BI-7/BI-8 butuh events (PRD §23) — CP-04.
4. Indikator tanpa hipotesis = scope creep, hapus.
5. Jangan mengarang angka baseline (AGENTS §4.4).
