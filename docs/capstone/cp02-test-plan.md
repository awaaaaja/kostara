# CP-02 — Test Plan

Date: 2026-09-25 (rev 1 — setiap TP direferensikan AC ditulis eksplisit)
Status: LOCKED — `cp02-requirements.md` (72 AC) seluruhnya merujuk ≥1 TP di sini.
Pelaksanaan: unit/widget sejak CP-04A; RLS/migration/spatial CP-03B/04A;
evaluasi ML CP-03B/04B; full acceptance CP-05A.

Harness (keputusan): SQL test via `supabase test db`/pgTAP atau skrip SQL
terpisah terhadap DB lokal — kepastian di CP-03A; Flutter memakai
`flutter test` + `integration_test`.

---

## 1. Unit & domain logic (Flutter)

| ID | Target | Kasus | AC |
|---|---|---|---|
| TP-AUTH-01 | form register | valid; password <8 char ditolak; input tidak hilang | AC-AUTH-01, AC-AUTH-03 |
| TP-AUTH-02 | penulisan profil | register sukses → role & `tos_accepted_at` terisi | AC-AUTH-02 |
| TP-AUTH-03 | opsi role | UI register tidak menawarkan `super_admin` | AC-AUTH-04 |
| TP-AUTH-04 | session restore | kill app → buka lagi → sesi aktif tanpa login ulang | AC-AUTH-06 |
| TP-AUTH-05 | logout | token lokal terhapus; request berikut butuh login | AC-AUTH-07 |
| TP-ONB-01 | validator onboarding | semua field wajib → submit sukses; 1 kosong → ditolak | AC-ONB-01 |
| TP-REC-06 | recompute feed | budget_max diubah → hasil >budget lama dapat muncul (query test) | AC-ONB-02 |
| TP-REC-04 | teks UI feed | scan widget: tanpa "probabilitas/kemungkinan/akurasi%"; format "Skor kecocokan NN/100" | AC-REC-04 |
| TP-PAY-01 | kalkulator due date | start 31 Jan → Feb 28/29 (kabisat 2028); 30 Apr → 31 Mei | AC-PAY-01 |
| TP-PAY-05 | regenerasi reminder | offset berubah → lama cancelled, baru scheduled, tanpa duplikat | AC-PAY-05 |
| TP-REV-04 | validator review | overall wajib, 8 aspek wajib, teks ≤1000 karakter | AC-REV-04 |
| TP-CMP-01 | state compare | item ke-4 ditolak; 8 kolom render | AC-CMP-01 |
| TP-OFF-01 | offline/error state | request gagal → banner offline ≤2 detik; input form bertahan | AC-OFF-01, NFR-REL-03/04 |

## 2. Widget / layar (state, a11y, layout)

| ID | Target | Kasus | AC/NFR |
|---|---|---|---|
| TP-LAY-01 | layar utama | 360×800, 390×844, 430×932 + text scale 200% → tanpa overflow/potong | NFR-LAY-01, NFR-ACC-05 |
| TP-LAY-02 | form | keyboard terbuka → tombol submit terjangkau | NFR-LAY-02 |
| TP-LAY-03 | kartu | nama 60 char & alamat 150 char → ellipsis, tanpa overflow | NFR-LAY-03 |
| TP-A11Y-01 | tombol ikon-only | Semantics label ada; touch target ≥44×48 dp | NFR-ACC-01/04 |
| TP-STATE-01 | layar data | loading skeleton; empty + ajakan; error + retry | NFR-REL-01 |

## 3. Repository / service (mock Supabase)

| ID | Kasus | AC |
|---|---|---|
| TP-SEARCH-01 | filter harga 500rb–1,5jt → 100% hasil dalam range (list & marker) | AC-SEARCH-01 |
| TP-SEARCH-02 | >20 hasil → halaman 1 ≤20 item; halaman 2 ≤20 item, tanpa duplikat | AC-SEARCH-02 |
| TP-SEARCH-03 | sort harga termurah → urutan non-decreasing lintas halaman | AC-SEARCH-03 |
| TP-SEARCH-04 | room berubah → timestamp "diperbarui" = waktu server (selisih ≤1 menit) | AC-SEARCH-04 |
| TP-SAVED-01 | buka list saved → item tampil + availability = nilai server terbaru | AC-SAVED-01 |
| TP-SAVED-02 | double-save dalam <500 ms → tepat 1 baris favorite | AC-SAVED-02 |
| TP-REC-01 | feed Home user baru & lama → ≥1 item | AC-REC-01 |
| TP-REC-02 | tiap kartu → ≥1 reason code dari kamus 6 kode | AC-REC-02 |
| TP-REC-03 | service timeout → fallback ranking, feed terisi, tanpa crash | AC-REC-03 |
| TP-REC-05 | user baru tanpa interaksi → ≥1 hasil dgn sinyal preferensi/geo/verified | AC-REC-05 |
| TP-LOC-01 | alur pencarian tanpa "Near me" → 0 permintaan izin lokasi (mock channel) | AC-LOC-01 |

## 4. Migrasi & constraint (SQL)

| ID | Kasus | AC |
|---|---|---|
| TP-DB-01 | migrasi dari DB bersih sukses; eksekusi ulang idempotent | NFR-SEC-06 |
| TP-DB-02 | CHECK: price −1000, budget_max<min, due_day 0 → ditolak | AC-OWN-03 |
| TP-DB-03 | 2 request pending sama room → ditolak; 2 tenancy aktif sama room → ditolak | AC-TEN-03 |
| TP-DB-04 | composite FK: review property ≠ tenancy.property → ditolak | AC-REV-01 (lapis 2) |
| TP-DB-05 | unique (tenancy_id, review_type) → review final ke-2 ditolak | AC-REV-03 |

## 5. RLS matrix (tabel kritis)

Setup: 2 seeker (A,B) + 2 owner (X,Y) masing-masing 1 property aktif +
1 tenancy, 1 super_admin, 1 sesi anon.

| ID | Tabel | Kasus | AC |
|---|---|---|---|
| TP-RLS-01 | payment_records, tenancies | seeker B baca data A → 0 row; A → row miliknya | AC-RLS-T1 |
| TP-RLS-02 | properties | anon hanya verified+active; owner baca draft sendiri; owner Y tidak bisa UPDATE property X | AC-OWN-01 |
| TP-RLS-03 | favorites, user_preferences | seeker lain 0 row; own SELECT/INSERT/DELETE sukses | FR-SAVED-01 |
| TP-RLS-04 | reviews | tanpa tenancy INSERT ditolak; owner UPDATE konten review ditolak; anon hanya approved | AC-REV-01, AC-REV-05 |
| TP-RLS-05 | tenancy_requests | owner property terkait boleh UPDATE; owner lain ditolak; seeker lain SELECT 0 | AC-TEN-01 |
| TP-RLS-06 | audit_logs, model_versions | non-admin SELECT/INSERT ditolak; super_admin SELECT sukses; INSERT client polos ditolak | AC-AUTH-05, AC-ADM-06 |
| TP-RLS-07 | interactions | consent NULL → INSERT ditolak; consent ada → INSERT sukses + SELECT hanya sendiri | AC-PRIV-03 |
| TP-RLS-08 | seluruh tabel | 100% tabel enabled RLS + ≥1 policy (query `pg_policies`) | NFR-SEC-01 |

## 6. Storage policy

| ID | Kasus | AC |
|---|---|---|
| TP-STOR-01 | GET objek `verification-documents-private` tanpa signed URL → 403/400 | AC-STOR-01 |
| TP-STOR-02 | owner Y tulis/hapus path milik property X → ditolak | AC-STOR-02 |
| TP-STOR-03 | owner X tulis property miliknya → sukses; read publik mengikuti status property | FR-PRIV-03 |

## 7. Geospatial

| ID | Kasus | AC/NFR |
|---|---|---|
| TP-GIS-01 | fixture jarak diketahui → ST_DWithin radius akurat ±0,01% | FR-MAP-03 |
| TP-GIS-02 | bbox kosong → 0 row; bbox penuh → semua point | AC-MAP-03 |
| TP-GIS-03 | `EXPLAIN ANALYZE` fixture 1000 point → index GIST, bukan seq scan | NFR-PERF-08 |
| TP-GIS-04 | flow tanpa permission (identik TP-LOC-01) | AC-LOC-01 |
| TP-GIS-05 | audit skema: 0 kolom lokasi user | AC-LOC-02, AC-PRIV-01 |
| TP-MAP-01 | filter & viewport identik → jumlah marker == jumlah list | AC-MAP-01 |
| TP-MAP-02 | geser cepat → berhenti ≥300 ms → tepat 1 query (terlog debounce) | AC-MAP-02 |
| TP-MAP-03 | hasil hanya dalam bbox viewport baru | AC-MAP-03 |
| TP-MAP-04 | izin ditolak → tidak ada dialog ulang otomatis; pencarian kampus tetap jalan | AC-MAP-04 |
| TP-MAP-05 | marker kampus dipilih → map re-berpusat + list terfilter radius | AC-MAP-05 |
| TP-MAP-06 | >100 marker → clustering aktif; pan ≥60 fps rata-rata | NFR-PERF-04 |
| TP-LOC-02 | audit skema + query log: tidak ada kolom/tabel yang menyimpan koordinat GPS user | AC-LOC-02, AC-PRIV-01 |

## 8. Domain flow (integration critical path — PRD §27)

| ID | Alur | AC |
|---|---|---|
| TP-E2E-01 | register → onboarding → feed tampil (≥1, reason) | AC-AUTH-02, AC-ONB-01, AC-REC-01, AC-REC-02 |
| TP-E2E-02 | explore → filter → detail → save → compare | AC-SEARCH-01, AC-SAVED-01, AC-CMP-01 |
| TP-E2E-03 | request → accept → tenancy aktif + room occupied (atomik, idempotent) | AC-TEN-01, AC-TEN-02 |
| TP-E2E-04 | tenancy → 12 due date → reminder → owner paid → tenant lihat paid | AC-PAY-01..AC-PAY-04, AC-PAY-06 |
| TP-E2E-05 | tenancy ended → final review → pending → approve → tampil publik | AC-REV-01..AC-REV-06 |
| TP-E2E-06 | owner pending → upload doc → verify → property boleh aktif | AC-OWN-01, AC-ADM-02, AC-ADM-03 |

### 8a. Detail per alur pendukung

| ID | Kasus | AC |
|---|---|---|
| TP-OWN-01 | owner pending submit property → listing pending, tidak publik | AC-OWN-01 |
| TP-OWN-02 | property lengkap + pin geo → row ada, point SRID 4326 valid | AC-OWN-02 |
| TP-OWN-03 | price negatif → ditolak CHECK (bukan tersimpan) | AC-OWN-03 |
| TP-OWN-04 | occupied→maintenance diterima; occupied→available tanpa perantaraan ditolak | AC-OWN-04 |
| TP-OWN-05 | room berubah → `last_availability_update_at` = waktu perubahan (trigger, ±0 dtk) | AC-OWN-05 |
| TP-OWN-06 | fixture 3 property → angka dashboard == query ground truth | AC-OWN-06 |
| TP-TEN-01 | accept atomik: tenancy+room+request dalam 1 transaksi; gagal = tidak ada yang berubah | AC-TEN-01 |
| TP-TEN-02 | accept 2× dalam <500 ms → hanya 1 tenancy aktif | AC-TEN-02 |
| TP-TEN-03 | request pending ke-2 di room sama → ditolak unique partial | AC-TEN-03 |
| TP-TEN-04 | end tenancy → status ended, room available, eligibility review terbuka | AC-TEN-04 |
| TP-TEN-05 | tenant home → kartu tenancy + due date berikutnya sesuai data | AC-TEN-05 |
| TP-TEN-06 | request diterima/ditolak → status baru terlihat saat app dibuka | AC-TEN-06 |
| TP-PAY-02 | tenancy aktif → 12 due date; overdue otomatis saat now>due & unpaid | AC-PAY-02 |
| TP-PAY-03 | offsets {7,3,1,0}+custom 5 → reminder tepat hari-H−offset (Asia/Jakarta) | AC-PAY-03 |
| TP-PAY-04 | owner tandai paid → paid_at terisi; seeker lain tidak bisa men-set paid | AC-PAY-04 |
| TP-PAY-06 | 1 overdue + 1 due-soon → home owner & tenant identik | AC-PAY-06 |
| TP-REV-01 | INSERT review tanpa tenancy → ditolak (403/0 row) | AC-REV-01 |
| TP-REV-02 | tenancy active → final review ditolak; setelah ended → diterima | AC-REV-02 |
| TP-REV-03 | review final ke-2 utk tenancy sama → ditolak unique | AC-REV-03 |
| TP-REV-05 | review pending tidak tampil publik; setelah approve tampil | AC-REV-05 |
| TP-REV-06 | review approved publik tanpa nama/phone; hanya label verifikasi + bulan | AC-REV-06 |

## 9. Moderation & admin

| ID | Kasus | AC |
|---|---|---|
| TP-ADM-01 | fixture 2 property/3 tenancy → overview == ground truth | AC-ADM-01 |
| TP-ADM-02 | reject owner tanpa reason → ditolak (NOT NULL) | AC-ADM-02 |
| TP-ADM-03 | approve listing → verified + tampil publik; reject → tetap tersembunyi + reason tersimpan | AC-ADM-03 |
| TP-ADM-04 | resolve report → status+note; hide review → flag saja, isi asli utuh | AC-ADM-04 |
| TP-ADM-05 | facility diubah is_active=false → property penandainya ikut | AC-ADM-05 |
| TP-ADM-06 | aksi verify → 1 baris audit_logs (actor, action, target, ts) | AC-ADM-06 |
| TP-ADM-07 | 100 event fixture → count per event_type == summary | AC-ADM-07 |

## 10. Privacy

| ID | Kasus | AC |
|---|---|---|
| TP-PRIV-01 | consent ditarik → event berikutnya tidak tersimpan | AC-PRIV-03 |
| TP-PRIV-02 | hapus akun → profil terhapus, interaksi kehilangan user_id, dokumen terhapus | AC-PRIV-02 |

## 11. ML evaluation (CP-03B/04B)

| ID | Kasus | AC/NFR |
|---|---|---|
| TP-ML-01 | tiap item feed → baris recommendation_logs lengkap | AC-ML-01 |
| TP-ML-REC-01 | pipeline eval baseline A/B → Precision/Recall/NDCG/Hit@5,10 + coverage dari split temporal | RQ-1 |
| TP-ML-REC-02 | run ulang seed sama → metrik identik | NFR-ML-01 |
| TP-ML-REC-03 | cek leakage: cutoff temporal ditegakkan, fitur time-as-of | PRD §13.1 |
| TP-ML-REC-04 | subset <5 event & listing <30 hari dilaporkan; feed tidak kosong | AC-REC-05 |
| TP-ML-NLP-01 | Macro F1 + per-class P/R + confusion matrix dari run nyata; 10 contoh error | RQ-3 |
| TP-NLP-01 | review non-approved tidak menghasilkan aspect_scores | AC-NLP-01 |
| TP-NLP-02 | confidence < threshold → `insufficient_evidence` | AC-NLP-02 |
| TP-NLP-03 | checksum teks review sebelum=sesudah; setiap baris punya model_version | AC-NLP-03 |

## 12. Security & performance

| ID | Kasus | AC/NFR |
|---|---|---|
| TP-SEC-01 | scan source & output build: 0 match `service_role`/private key (CI) | AC-AUTH-08, NFR-SEC-02 |
| TP-SEC-02 | audit row muncul utk verify/reject/report resolve | AC-ADM-06 |
| TP-SEC-03 | semua tabel enabled RLS (query pg_policies) | NFR-SEC-01 |
| TP-PERF-01 | throttle Fast 3G → first list ≤2,5 detik (p50, 3 run) | NFR-PERF-02 |

## 13. Manual exploratory (CP-05A)

- Permission denied; mode pesawat; slow network (DevTools throttle);
- device menengah nyata; teks 200%; data panjang;
- konsistensi dashboard owner vs ground truth;
- demo smoke: seeker, owner, admin, ML fallback (VALIDATION_PROTOCOL §24).

## 14. Traceability check otomatis (dijalankan di gate CP-02)

- 56 FR → ≥1 AC; 72 AC → ≥1 TP literal (bukan range).
- 100% tabel schema draft tercakup matrix RLS (TP-RLS-08).
