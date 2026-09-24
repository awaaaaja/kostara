# CP-02 — V1 Scope Lock

Date: 2026-09-25
Status: **LOCKED** — mengikat SPRINTS backlog P0/P1/P2 ke checklist rilis.
Aturan: **V1 = P0** (wajib selesai sebelum CP-05 PASS); **P1** = dikerjakan
bila waktu tersisa setelah V1 stabil; **P2** = di luar Capstone.
Jika PRD badan terasa berbeda dari tabel ini, tabel ini yang menentukan
**urutan rilis** (PRD tetap menentukan isi produk).

---

## V1 (P0) — wajib

| # | Area | Fitur | FR |
|---|---|---|---|
| 1 | Auth | register, role, session, logout, no-secret, ToS+consent | FR-AUTH-01..06 |
| 2 | Onboarding | preferensi seeker (kampus, budget, fasilitas, transport, jarak/waktu, move-in); owner daftar → pending | FR-ONB-01..03 |
| 3 | Search/Filter | 10 filter, sort, pagination, detail + last availability update | FR-SEARCH-01..03 |
| 4 | Explore Map | marker+cluster, search this area (debounce), near me JIT permission, marker kampus, NO background tracking | FR-MAP-01..05 |
| 5 | Saved | favorite/unfavorite, refresh availability saat dibuka | FR-SAVED-01 |
| 6 | Compare | maks 3 listing, client-side, event dicatat | FR-CMP-01 |
| 7 | Recommendation | feed personal, explanation, fallback tak-pernah-kosong, skor = normalized match | FR-REC-01..04, FR-ML-01/03 |
| 8 | Owner | verifikasi owner, property CRUD + pin lokasi, room CRUD + status, availability, terima/tolak request, tandai paid, analytics dasar | FR-OWN-01..07 |
| 9 | Tenancy | request (1 pending/room), lifecycle active/ended, tenant home card, riwayat pembayaran | FR-TEN-01..04 |
| 10 | Payment reminder | schedule dari tenancy, due/overdue, offset 7/3/1/0+custom via local notif + regenerasi, view dua arah | FR-PAY-01..04 |
| 11 | Verified review | eligibility server-side, final review (8 aspek + teks), moderasi admin, tampil publik terverifikasi-minimal-identitas | FR-REV-01..04 |
| 12 | ML-2 | aspek NLP → review_aspect_scores (source=nlp) di atas review approved | FR-ML-02 |
| 13 | Admin | overview, verify owner/listing (+reason), moderasi report/review, master data, audit log | FR-ADM-01..06 |
| 14 | Privacy | lokasi JIT tanpa persist, consent bisa ditarik, dokumen privat signed | FR-PRIV-01..03 |

## P1 — jika waktu tersisa (setelah V1 stabil)

| Fitur | Alasan ditunda | Acuan PRD/SPRINTS |
|---|---|---|
| Pulse feedback bulanan | butuh data interaksi lebih dulu; final review cukup untuk V1 | PRD §12.2, SPRINTS P1 |
| Server push notification (lintas device) | local notification sudah menutup kebutuhan reminder V1 | PRD §20, SPRINTS P1 |
| Upload bukti pembayaran (private bucket flow) | owner tandai paid sudah cukup untuk siklus V1 | PRD §9.5 ("bila flow dipilih tim") |
| Travel time (routing provider) | A-09 unknown; V1 = distance-only, jangan ETA palsu | PRD §14.4, SPRINTS P1 |
| Isochrone | butuh routing | PRD §14.5, SPRINTS P1 |
| Advanced owner analytics | analytics dasar sudah P0 | SPRINTS P1 |
| Model monitoring dashboard | recommendation_logs + model_versions cukup untuk eval manual | SPRINTS P1 |
| notification_outbox (table) | tidak dipakai sebelum push P1 | PRD §15 |

## P2 / V2 — di luar Capstone

Payment gateway, chat real-time, dynamic pricing, web owner dashboard,
multi-city ops, smart contract, fraud detection canggih, kredit scoring,
face recognition, background tracking, marketplace nasional (PRD §3.2 + SPRINTS P2).

---

## Keputusan scope yang perlu dicatat (rekonsiliasi)

| Keputusan | Dasar |
|---|---|
| V1 **distance-only**; travel time & isochrone P1 | A-09 unknown (CP-01); PRD §14.4 fallback `distance only` |
| Pulse feedback P1; **final review** = verified feedback V1 | SPRINTS P1 list; PRD §12.2 tetap menyiapkan tipe pulse |
| Reminder V1 = **local scheduled notification** + view status di app; push P1 | PRD §20 (dua opsi disetujui); hindari dependency FCM di V1 |
| Pembayaran V1 = **owner menandai paid/unpaid**; upload bukti P1 | PRD §9.5; memotong kompleksitas storage private di critical path |
| Super admin **tidak dapat self-register** (dibuat via proses server/seed terdokumentasi) | VALIDATION_PROTOCOL §23 (admin auth kuat) |
| Review **pending → moderasi super_admin** (tanpa auto-approve) | PRD §10; volume awal kecil |
| Registrasi **email + password** (Supabase auth); SSO/magic link opsional menyusul | dependensi paling kecil, testable offline dari mock |
| ToS + data-consent wajib saat registrasi (FR-AUTH-06) | syarat legal training data ML-2 (lisensi UGC) + menutup A-07 |
| Interaksi/ML consent **default aktif + bisa ditarik** di settings | transparan; personalisasi = tujuan inti produk; withdrawal → event berikutnya tidak dikumpulkan, data lama dianonimkan |

## Konflik / ambiguitas yang didokumentasikan (PROMPTS §2.4)

1. PRD §4.2 primer interview vs CP-01 sekunder → **tidak memblokir CP-02**
   (VALIDATION_PROTOCOL §11 tidak mensyaratkan primer; R-011 tetap open).
2. PRD menyebut fitur yang SPRINTS golongkan P1 → diselesaikan oleh lock di atas.
3. Compare "tidak disimpan server" (PRD §8.6) vs event `compare_add` (PRD §23)
   → **tidak konflik**: state compare di client, event tetap dikirim.
