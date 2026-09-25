# Risk Register — KOSTARA

Diperbarui minimal setiap sprint. Kolom: ID, Risk, Impact, Likelihood, Mitigation, Status, Since.

| ID | Risk | Impact | Likelihood | Mitigation | Status | Since |
|---|---|---|---|---|---|---|
| R-001 | Tidak cukup interaction data untuk hybrid CF | High | High | Content-based strong baseline + pilot instrumentation (PRD §29) | Open | 2026-09-25 |
| R-002 | Review text terlalu sedikit untuk NLP | High | High | Structured aspect rating + labeled pilot dataset; dokumentasikan batasan | Open | 2026-09-25 |
| R-003 | Location permission ditolak | Medium | Medium | Campus/manual location search fallback | Mitigated (CP-04A: near-me JIT + hint saat ditolak; pencarian kampus/area manual tetap jalan tanpa izin) | 2026-09-25 |
| R-004 | Routing API tidak tersedia → ETA gagal | Medium | Medium | Fallback distance-only; jangan fake ETA | Open | 2026-09-25 |
| R-005 | RLS salah → data leak | Critical | Medium | RLS matrix test wajib sebelum gate PASS; tidak pernah disable RLS | Mitigated (CP-03B: 22 harness + 53 REST lulus; wajib ulang tiap ubah policy) | 2026-09-25 |
| R-006 | Secret bocor ke repository | Critical | Low | Aman.md + .env di .gitignore; secret scan tiap REVIEW | Open | 2026-09-25 |
| R-007 | Scope terlalu besar → deadline gagal | High | Medium | Disiplin V1/P1/V2; quality gate > sprint calendar | Open | 2026-09-25 |
| R-008 | Metric ML direkayasa → integritas akademik gagal | Critical | Low | Semua metric direproduksi dari experiment artifact; dilarang (AGENTS §4.4) | Open | 2026-09-25 |
| R-009 | Stakeholder tidak tersedia untuk CP-01 | High | Medium | Interview plan dibuat; evidence ditandai pending bila belum ada | Open | 2026-09-25 |
| R-010 | Model bias ke listing populer | High | Medium | Content metadata + coverage metric + cold-start analysis | Open | 2026-09-25 |
| R-011 | Evidence CP-01 lemah (hanya sekunder) + primer Padang belum ada | High | Medium | **Mitigasi parsial:** E-001/E-002 (sekunder, diverifikasi) sudah masuk → CP-01 menilai problem terbukti. Primer 1:1 tetap disarankan sebelum/during CP-03 untuk A-08 + kedalaman Capstone (PRD §4.2) | Mitigated (sebagian) | 2026-09-25 |
| R-012 | Rekrutmen partisipan sulit (sukarela, jadwal kuliah) | Medium | Medium | Kanal grup kampus/UKM; sesi 20-40 menit; tawarkan ringkasan hasil anonim | Open | 2026-09-25 |
| R-013 | A-05 ditolak (filter sudah cukup) → scope ML-1 turun | High | Medium | Baseline popularity/content tetap bisa jadi POCP; putuskan di CP-03 berdasarkan evidence, bukan preferensi teknologi | Open | 2026-09-25 |
| R-014 | Bias instrumen interview (leading question) merusak evidence | High | Low | Script netral (`cp01-interview-plan.md` §2-4); larangan menyebut "AI" di pembuka; kutipan dicatat apa adanya | Open | 2026-09-25 |
| R-015 | A-07 unknown: pengumpulan data preferensi/interaksi/review tanpa consent jelas | High | Medium | **Mitigated:** `cp02-privacy.md` (data inventory, consent UX default-ON+tarik, retensi 24 bulan, hak hapus) + FR-AUTH-06/FR-PRIV-01..03; implementasi ToS UI = CP-04A (lihat R-017) | Mitigated | 2026-09-25 |
| R-016 | A-08 unknown: evidence umum Indonesia, belum spesifik Padang | Medium | High | Primer Padang (R-011) atau catat keterbatasan pilot di laporan | Open | 2026-09-25 |
| R-017 | ToS v1.0 (termasuk klausul lisensi UGC review untuk training ML-2) belum ditulis/ditampilkan di app → dasar legal training lemah | High | Medium | Ditulis sebagai task CP-04A bersama FR-AUTH-06; gate CP-04 mengecek penerimaan ToS terekam (`tos_version`) | Mitigated (CP-04A: `docs/tos-v1.0.md` draft final + ringkasan in-app register/profil + penerimaan terekam; **ok owner atas teks masih pending**) | 2026-09-25 |
| R-018 | Seed data demo tidak realistis / tergantung scraping pihak ketiga (izin melanggar) | Medium | Medium | Seed dibuat manual+terdokumentasi (NFR-OPS-01), diberi label demo; dilarang scraping listing komersial | Mitigated (CP-03B: seed sintetis deterministik, terlabel dev, tanpa scraping) | 2026-09-25 |
| R-019 | Kuota Supabase free tier (storage/egress/MAU) habis saat pilot | Medium | Medium | Kompresi gambar (NFR-PERF-05), pantau bulanan (NFR-OPS-03), thumbnail cached | Open | 2026-09-25 |
| R-020 | Reminder lokal hanya tereksekusi saat app dibuka (tanpa push di V1) → tenant bisa melewati notifikasi | Medium | Medium | Jendela reminder 7/3/1/0 hari memperbesar peluang app dibuka; status due tampil di Home; server push = P1 | Mitigated parsial (CP-04B: offset 7/3/1/0 dipilih tenant + notifikasi terjadwal `inexact` + boot reschedule + due di Home; tanpa push server & optimasi baterai OS tetap di luar kendali) | 2026-09-25 |
| R-021 | Prototype tanpa tombol GPS on-demand → user hanya bisa jarak via kampus | Medium | Medium | Kampus/jarak dihitung server-side (jujur, tanpa pseudo-ETA); geolocator JIT = task CP-04A | Mitigated (CP-04A: tombol "Lokasi saya" JIT + session-flag anti dialog ulang + manifest Android; koordinat tidak disimpan) | 2026-09-25 |
| R-022 | Font Plus Jakarta Sans belum dibundel → tipografi belum 100% token DESIGN | Low | High | Bundling asset font di CP-04A sebelum demo akhir | Mitigated (CP-04A: 4 weight TTF + OFL dibundel, `fontFamily` aktif) | 2026-09-25 |
| R-023 | Alur konfirmasi email belum diuji end-to-end (tergantung setting konfirmasi project) | Medium | Medium | State "cek email" sudah ada di UI; E2E + mailbox dev diuji CP-04A | Mitigated parsial (CP-04A: `mailer_autoconfirm=false` terbukti + guard `tos_required` terbukti; baca mailbox dev belum ada) | 2026-09-25 |
| R-024 | Alpha belum pernah di-compile/run on-device (build deferred owner) → integrasi native plugin & layout nyata tak teruji | High | Medium | Jalankan `flutter build apk` + device smoke sebelum demo (prasyarat non-blocking CP-04B) | Open | 2026-09-25 |
| R-025 | `fire_at` seed = tengah malam WIB sedangkan tampilan app = 09:00 WIB → kebingungan saat audit data | Low | Medium | `fire_at` write-only (UI/notif hitung ulang due+offset); formula seed diuji TP-PAY-03; samakan formula saat seed produksi | Open | 2026-09-25 |
| R-026 | Seleksi model pada data sangat kecil (n_eval=3, NDCG gap 0.0) → pemenang rapuh, over-claim performa | High | High | Limitation terbuka di MODEL_CARD §3/§7; popularity tetap fallback (FR-ML-03); wajib reseleksi saat data produksi material berbeda | Open | 2026-09-25 |
