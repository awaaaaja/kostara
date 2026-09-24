# CP-01 — Measurable Benefit Indicators

Date: 2026-09-25
Status: indikator & metode dikunci; **baseline PENDING** (belum ada data).
Kebijakan (PRD §25): dilarang menulis target numerik final tanpa baseline nyata.
Kolom "Target" sengaja `TBD after baseline`.

---

| ID | Indikator | Definisi terukur | Sumber data | Baseline | Target | Kaitan hipotesis |
|---|---|---|---|---|---|---|
| BI-1 | Waktu ke shortlist | Median menit dari mulai pencarian sampai user punya ≥3 kandidat tersimpan | Interview (self-report) → nanti event `property_save` | TBD (interview) | TBD | H-01, H-05 |
| BI-2 | Keyakinan keputusan | Skor 1-5 setelah memilih/menyimpan shortlist (pertanyaan pasca-tugas kecil) | Interview / usability test CP-03 | TBD | TBD | H-01, H-04 |
| BI-3 | Beban operasional owner | Median menit/minggu untuk urus kamar kosong + catat pembayaran | Interview owner | TBD | TBD | H-03 |
| BI-4 | Insiden pencatatan | Jumlah kejalian salah-stok-kamar / selisih catat per bulan (self-report) | Interview owner → nanti data room status | TBD | TBD | H-03 |
| BI-5 | Review verified rate | % review yang lolos eligibility tenancy terhadap semua review masuk | DB `reviews` (CP-04B) | n/a pra-launch | TBD | H-04 |
| BI-6 | Ketepatan pengingat | % pembayaran tercatat tepat sebelum/saat due date (record & reminder, bukan gateway) | `payment_records` (CP-04B) | TBD (dari interview: berapa sering telat) | TBD | H-02 |
| BI-7 | Relevansi rekomendasi | Save/request rate item dari feed rekomendasi vs feed non-personal (setelah baseline ada) | `interactions` + A/B sederhana bila memungkinkan | TBD (butuh data) | TBD | A-05, RQ-1 |
| BI-8 | Effort pencarian | Jumlah listing dibuka sebelum shortlist (lebih rendah = lebih relevan) | `interactions` property_view | TBD | TBD | RQ-4 |

## Aturan main

1. **Baseline dulu, target kemudian.** Target diisi setelah kolom Baseline terisi dari evidence nyata.
2. BI-7/BI-8 butuh instrumentasi events (PRD §23) — scope CP-04, bukan klaim di CP-01.
3. Setiap indikator wajib punya hipotesis yang dihubungkan; indikator tanpa hipotesis = scope creep, hapus.
4. Jangan mengarang angka baseline. Kolom kosong lebih aman daripada angka palsu (AGENTS §4.4).
