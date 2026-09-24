# CP-01 — Project Charter & Problem Statement

Date: 2026-09-25 (updated: evidence E-001/E-002 masuk)
Status: **Problem terbukti (evidence sekunder/proxy — lihat `cp01-evidence-log.md`)**
Capstone track: **PIF683 Proyek dalam Kecerdasan Buatan**

---

# 1. Project Charter (draft)

| Item | Isi | Status |
|---|---|---|
| Nama produk | KOSTARA — pencarian & manajemen kos dengan lifecycle panjang | fixed (PRD) |
| Masalah | Terbukti sekunder — lihat §2 (H-01..H-05 terdukung E-001/E-002) | **validated (secondary)** |
| Target pengguna awal | Mahasiswa/pencari kos & pemilik kos, pilot Kota Padang | hipotesis pasar (A-08 unknown — spesifik Padang belum) |
| Stakeholder Capstone | 3-5 pencari kos, 2-3 pemilik, 1 validator (PRD §4.2) | primer PENDING (disarankan); sekunder ✓; validator → CP-03 |
| Tim & peran | Diisi pemilik project | PENDING |
| Pembimbing | Diisi pemilik project | PENDING |
| Repository | repo ini (main), CP-00 PASS (`docs/logs/CP-00-gate-report.md`) | valid |
| Platform | Flutter mobile + Supabase | fixed; A-06 validated (lemah) |
| ML scope | ML-1 hybrid recommendation; ML-2 aspect-based review analysis | **task justified (A-05)**; performa = eksperimen CP-03 |
| Non-goals V1 | payment gateway, chat, background tracking, credit scoring, dll. (PRD §3.2) | fixed |
| Success framing | Manfaat terukur BI-1..BI-8 (`cp01-benefit-indicators.md`), target = setelah baseline | draft |

**Bukan sekadar marketplace listing:** nilai utama = lifecycle panjang
(discovery → tenancy → payment reminder → verified feedback → renew/move)
dan keputusan pencarian yang relevan secara personal (README §Prinsip produk).

---

# 2. Problem Statement (terbukti sekunder, 2026-09-25)

**Problem statement utama (diperkuat):**

> Pencarian dan pengelolaan kos masih terfragmentasi antara platform
> listing, Google Maps, komunikasi WhatsApp, survei lapangan, serta
> pencatatan manual. Bagi pencari kos, kondisi tersebut meningkatkan waktu
> dan usaha untuk menemukan hunian yang sesuai dengan preferensi, anggaran,
> dan kebutuhan mobilitas. Bagi pemilik kos, pencatatan availability,
> penghuni, pembayaran, dan feedback yang tersebar meningkatkan risiko
> informasi tidak mutakhir dan histori operasional yang tidak terlacak.

Status bukti per hipotesis (evidence: `cp01-evidence-log.md`):

| ID | Pernyataan | Bukti | Status |
|---|---|---|---|
| H-01 | Pencarian multi-kriteria sulit; info listing (availability/fasilitas) sering tidak aktual vs kondisi nyata | E-001 (P1,P2,P3); Mamikos Help Center resmi (verifikasi agent) | **terdukung** |
| H-02 | Setelah sewa, lifecycle (jatuh tempo, riwayat, pengingat) dikelola manual → riskan lupa/telat/tidak terlacak | E-001 (P6); E-002 (S2.3); kategori produk SuperKos/kospay/OpenKOS | **terdukung** |
| H-03 | Operasional owner terfragmentasi: kamar/penghuni/pembayaran/feedback tanpa single source of truth | E-002 (S2.1-S2.5); KostEZ/SIKOSSANKU/OpenKOS (verifikasi) | **terdukung** |
| H-04 | Trust informasi rendah: review tidak cukup, listing stale → pencari wajib survei manual | E-001 (P5); Mamikos Help Center; *reframe: trustworthiness of listing information* | **terdukung** |
| H-05 | Filter mengurasi tapi tidak menranking sesuai prioritas bertingkat → banyak pilihan ≠ cocok | E-001 (P2, P7) | **terdukung** |

Sub-temuan pemilik/deret sintesis owner (F1 availability stale, F2
fragmentasi channel, F3 waktu tempuh > jarak, F4 screening manual,
F5 pembayaran manual, F6 data kamar tersebar, F7 keluhan tak
terkelola) terpetakan ke H-01..H-05 di atas — ID H-xx tetap kanonik
agar konsisten dengan artefak lain.

**Reframe penting (A-03):** masalah trust bukan sekadar "review palsu"
tapi **trustworthiness of listing information** → solusi KOSTARA =
verified listing + last availability update + owner verification +
verified tenant review.

---

# 3. Justifikasi teknologi (bukan klaim performa)

| Kebutuhan terbukti | Respons | Catatan jujur |
|---|---|---|
| H-05: filter ≠ ranking (A-05) | **ML-1**: personalized ranking AFTER hard filter; baseline popularity + content-based dulu (AGENTS §11.2) | Task justified; **metrik performa belum ada — jangan diklaim sebelum eksperimen CP-03** |
| H-01: waktu tempuh menentukan (E-001 P4) | **GIS**: distance/nearby/campus-aware; travel time hanya bila routing valid | Isochrone P1; jangan fake ETA |
| H-04: trust listing + review | **Verified feedback** (eligibility tenancy) + **ML-2** NLP aspek bila data valid | Listing accuracy (last update) sama pentingnya dengan review |
| H-02/H-03: lifecycle manual | **Tenancy + payment record + reminder** (bukan payment gateway) | V1 record & reminder (PRD §9.5) |

---

# 4. Research questions (PRD §26 — status)

- RQ-1 (rec vs popularity): **layak dievaluasi** — A-05/H-05 terdukung; metrik di CP-03B.
- RQ-2 (feedback interaksi): menunggu instrumentasi data (CP-04).
- RQ-3 (NLP aspek): menunggu data review valid (CP-04B).
- RQ-4 (effort pencarian): BI-8; baseline dari primer menyusul.
