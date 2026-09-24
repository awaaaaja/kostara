# CP-01 — Project Charter & Problem Statement

Date: 2026-09-25
Status: DRAFT — problem evidence PENDING (belum divalidasi interview)
Capstone track: **PIF683 Proyek dalam Kecerdasan Buatan**

---

# 1. Project Charter (draft)

| Item | Isi | Status |
|---|---|---|
| Nama produk | KOSTARA — pencarian & manajemen kos dengan lifecycle panjang | fixed (PRD) |
| Masalah (hipotesis) | Lihat §2 di bawah | PENDING bukti |
| Target pengguna awal | Mahasiswa/pencari kos & pemilik kos, pilot Kota Padang | hipotesis pasar |
| Stakeholder Capstone | 3-5 pencari kos, 2-3 pemilik, 1 validator (PRD §4.2) | rencana rekrutmen, nama PENDING |
| Tim & peran | Diisi pemilik project | PENDING |
| Pembimbing | Diisi pemilik project | PENDING |
| Repository | repo ini (main), CP-00 PASS (`docs/logs/CP-00-gate-report.md`) | valid |
| Platform | Flutter mobile + Supabase | fixed (PRD) |
| ML scope | ML-1 hybrid recommendation; ML-2 aspect-based review analysis | conditional — wajib dibuktikan perlu (A-05) |
| Non-goals V1 | payment gateway, chat, background tracking, credit scoring, dll. (PRD §3.2) | fixed |
| Success framing | Bukan "membuat aplikasi kos dengan AI" — manfaat terukur (lihat `cp01-benefit-indicators.md`) | draft |

**Bukan sekadar marketplace listing:** nilai utama = lifecycle panjang
(discovery → tenancy → payment reminder → verified feedback → renew/move)
dan keputusan pencarian yang relevan secara personal (README §Prinsip produk).

---

# 2. Problem Statement

Semua pernyataan di bawah adalah **hipotesis (H-xx)**. Status bukti: PENDING
sampai ada entri di `cp01-evidence-log.md`. Jangan mengutipnya sebagai fakta.

## H-01 (seeker) — Keputusan multi-kriteria sulit dilakukan manual
Pencari kos harus menggabungkan budget, jarak ke kampus, fasilitas, tipe,
aturan, internet, keamanan, dan pengalaman penghuni secara manual.
*Bukti dibutuhkan:* cerita proses pencarian aktual, kandidat yang dibuang, kriteria yang berubah di tengah jalan.

## H-02 (seeker) — Aplikasi listing kehilangan nilai setelah transaksi
Lifecycle penghuni (jatuh tempo, riwayat, feedback, perpanjangan) tidak
ditangani aplikasi pencarian.
*Bukti dibutuhkan:* cara penghuni saat ini mengingatkan/mencatat sewa; kejadian terlambat bayar/komunikasi dengan pemilik.

## H-03 (owner) — Pengelolaan operasional terfragmentasi
Pemilik kesulitan mengelola availability, tenant, pembayaran, dan feedback
di satu tempat.
*Bukti dibutuhkan:* alat yang dipakai saat ini (buku, WA, spreadsheet), waktu yang habis, kesalahan stok kamar.

## H-04 (trust) — Review tanpa verifikasi menurunkan kepercayaan
Review anonim mudah dimanipulasi; pencari tidak tahu mana yang berasal dari penghuni sungguhan.
*Bukti dibutuhkan:* perilaku saat menilai review; insiden yang dirasakan/didengar.

## H-05 (decision gap) — Filter saja tidak cukup untuk menemukan kos yang "cocok"
*Bukti dibutuhkan:* situasi di mana filter mentok (terlalu banyak hasil
tidak relevan / kriteria tidak bisa diekspresikan lewat filter); ini
justifikasi utama recommendation ML — lihat `cp01-assumptions.md` A-05.

---

# 3. Research questions (dari PRD §26 — belum dijawab)

- RQ-1: apakah ranking personal (preferensi + fitur + geospasial) lebih relevan dari popularity baseline?
- RQ-2: pengaruh feedback interaksi terhadap kualitas rekomendasi seiring data bertambah?
- RQ-3: efektivitas NLP ekstraksi sentimen per aspek dari feedback verified tenant?
- RQ-4: apakah rekomendasi + map exploration mengurangi effort pencarian vs listing/filter saja?

Status: PENDING — butuh data/eksperimen (CP-03B ke atas). CP-01 hanya
memastikan pertanyaan ini relevan dengan masalah nyata.
