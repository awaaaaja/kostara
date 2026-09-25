# CP-04B — ML + Tenancy + Payment + Feedback + Admin Integration — GATE REPORT

Date: 2026-09-25
Sprint 6 (weeks 9-10) · Prompt: `PROMPTS.md` §11 ·
Status: **PASS** (device-run tetap deferred atas instruksi owner §7-1)
Target: selected model/justified baseline terintegrasi + alur
tenancy/payment/review stabil + admin console + review verified tidak bisa
di-bypass; evidence = suite live yang dieksekusi di sesi ini.

---

## 1. Context acquisition (dijalankan sebelum THINK)

- Source of truth: AGENTS, VALIDATION_PROTOCOL, PRD (LOCKED), DESIGN
  (§11/§12/§25/§26/§35), SPRINTS §CP-04B, PROMPTS §11, `cp02-*`
  (ml-data-plan, privacy, data-dictionary, scope-lock), `cp03a-backlog`
  (A5/A7/A8/A9-sisa), gate report CP-04A, `MODEL_CARD.md`, `DATASET_CARD.md`.
- Codebase awal = hasil CP-04A (alpha-1: auth/discovery/map/tenancy request/
  owner lifecycle/ToS). Rekonkonsiliasi scope: **A5** (jadwal bayar + reminder
  tz + regen), **A7** (admin console), **A8** (review/feedback), **A9-sisa**
  (hapus akun) + **integrasi model hybrid** → semua masuk CP-04B.
- Data/ML re-check (perintah prompt, tanpa mempercayai summary lama):
  - interaction data **ada dan terpakai**: 1200 baris seed dev, 3 seeker
    konsen, taxonomy event + bobot desain terdokumentasi (DATASET_CARD);
  - **hybrid dibenarkan tidak?** — pada data ini NDCG hybrid = popularity =
    1.0 (gap 0.0), content murni lebih buruk (0.877), n_eval=3, cold-start
    subgroup kosong → seleksi hybrid **ditetapkan dengan limitation terbuka**,
    bukan klaim superioritas: tie-break mengikuti FR-ML-03 (popularity hanya
    fallback), reseleksi wajib saat data produksi cukup (MODEL_CARD §3, R-026);
  - inference contract: RPC PostgREST `feed_recommendations` (invoker + RLS),
    timeout/error → fallback klien `search_properties(sort: popularity)` +
    label jujur; skor 0–100 = skor kecocokan, label probabilitas/akurasi
    **dilarang dan diuji otomatis** (`test/copy_scan_test.dart`);
  - review eligibility: server-side `fn_can_review` (tenancy `ended` + owner
    match + auth.uid) — client hanya memanggil;
  - payment semantics: `next_due_date` = due terbayar paling awal (trigger
    recompute), reminder seed = offset 7/3/1/0 hari, app menampilkan fire
    02:00 UTC (09:00 WIB) + offset harian (DESIGN §26);
  - aspect: 8 aspek wajib diisi; insight owner/seeker = agregat verified,
    tanpa identitas reviewer.
- Data/schema impact: 7 migration **additif** (`…010010`–`…010016`);
  dua di antaranya supersede `create or replace` (bukan drop/rename).
- Security impact: tetap tanpa service_role di Flutter; `delete_my_account`
  = satu-satunya jalur hapus akun (definer, anonimisasi + rename email);
  hapus berkas storage = `{"prefixes":[…]}` dengan policy owner (bucket
  `avatars`); audit log = rpc `audit_log_write` (client, tanpa trigger);
  matriks RLS diperluas (tabel `reminders` + storage).
- Design/UX impact: label feed tanpa klaim probabilitas, fallback copy jujur,
  form review error dekat field, konsol admin role-tab, dialog konsekuensi
  hapus akun, layar setup pengingat (7/3/1/0), skeleton/empty/error state.

## 2. BUILD — apa yang dihasilkan

### 2.1 Backend — 7 migration (semua via `run_sql.py`)

| Migration | Isi |
|---|---|
| `…010010_cp04b_integration.sql` | `feed_recommendations` (hybrid, reason dictionary 6 kode, hard filter harga/gender/jarak, fallback SQL `trending`), review/aspect/report schema + `fn_can_review`, `delete_my_account` (rename email + anonimisasi + null interaksi), policy review/aspect/report |
| `…010011_cp04b_sync.sql` | sync interaksi/event + `audit_log_write(p_action,p_target_type,p_target_id,p_detail)` |
| `…010012_due_calculator.sql` | trigger `payment_records` → `next_due_date` = due terbayar paling awal; `cancel reminders` saat lunas; guard `payment_schedules_guard` (tenant hanya ubah field offsets) |
| `…010013_aspect_score.sql` | upsert `review_aspect_scores` (8 aspek wajib, CHECK enum) saat review masuk |
| `…010014_admin_master.sql` | policy admin (owner verify/reject + alasan, listing verify/reject, reports resolve/hide, review approve/reject/hide flag-only, facilities master, model_versions read, interactions read-only) + view antrean |
| `…010015_admin_rooms_select.sql` | supersede `rooms_select` + `app_is_admin()` → room count admin 40/40 (sebelumnya 36/40) |
| `…010016_facilities_trigger_security_definer.sql` | `facilities_deactivate` → SECURITY DEFINER → hapus mark fasilitas dijalankan benar walau policy `property_facilities_delete` = owner-only |

### 2.2 ML

| Artefak | Isi |
|---|---|
| `experiments/recommendation/run_baselines.py` | kandidat `popularity` / `content_based` / `hybrid` (α=0.7 = design parameter), split temporal 70/10/20, determinism 2× assert, coverage/cold-start |
| `runs/20260925T170952Z/` | manifest (`git_dirty=false`, commit `34a5c76`, seed 42, dataset `ebc8e8e3cadecd7d`) + metrics — **identik** dengan run `…T065411Z` sebelumnya (determinism terbukti lintas run) |
| `MODEL_CARD.md` | kandidat vs baseline (tabel P/R/NDCG/HR/coverage), pemilihan + keterbatasan jujur (n_eval=3, gap 0.0), inference contract + latency terukur, fallback 3 lapis, NLP = N/A, reproducibility, batasan penyajian |
| `activate_model.py` | idempoten: `model_versions` `c626ac15-…` status active, `artifact_uri` → run bersih, params aktif `w_budget .245 / w_campus .21 / w_facility .105 / w_rating .14 / w_trending .3 / hybrid_alpha .7` |

### 2.3 Flutter

| Area | File | Isi |
|---|---|---|
| Payment | `core/util/payment_schedule.dart`, `core/notifications/**`, `tenancy/{payment_history,reminder_setup,reminder_sync}.dart`, `tenancy_repository` (`paymentHistory/reminderOffsets/saveReminderOffsets/syncReminderRows/myOpenDues/paymentSummary`), `owner/owner_payments_screen` | hitung fire 09:00 WIB + offset harian; notifikasi lokal **tanpa exact alarm** + reschedule `BOOT_COMPLETED`; riwayat (DESIGN §25); tenant pilih offset 7/3/1/0 (guard server hanya kolom offsets); regen baris `reminders` tanpa duplikat; angka home seeker = home owner (AC-PAY-06) |
| Feedback | `features/feedback/**` (repository+layar+report), `property_detail_screen` (section ulasan + aspek), `owner_repository.feedbackInsight`, `owner_dashboard_screen` (panel insight) | submit review final dari tenancy ended; validasi client **sebelum jaringan** (overall 1..5, 8 aspek, teks ≤1000) + versi server; report dialog → antrean admin; insight agregat aspek verified |
| Discovery | `discovery_{repository,providers}`, `home_feed_screen` | feed hybrid + hydration, payment banner, fallback lokal (hard filter + skor transparan), reason codes 6 kode, copy tanpa probabilitas |
| Admin | `features/admin/**` (dashboard/verify/moderation/master/dialogs/repository), `core/router/{app_router,app_shell}` | verifikasi owner (alasan wajib), moderasi listing, queue report, moderasi review, master fasilitas/kampus, ringkasan model + hitungan interaksi read-only (FR-ADM-01/AC-ADM-07), tab role super_admin/owner/seeker + guard rute |
| Account | `auth_repository.deleteAccount`, `profile_screen` | list+remove berkas `avatars` (prefixes), rpc `delete_my_account`, dialog konsekuensi permanen, state suspended/renamed |

### 2.4 Tests

| Suite | Isi |
|---|---|
| `scripts/test_cp04b_flow.py` | **35 kasus** TP-REV/REC/ADM/PAY/PRIV end-to-end via REST (anon/seeker/owner/admin/svc + storage), fixture `zz-cp04b` ber-acara awal+akhir, mirror `audit_log_write` |
| `test/review_validation_test.dart` | TP-REV-04: validasi form dijalankan sebelum request jaringan |
| `test/copy_scan_test.dart` | TP-REC-04: `lib/**` dilarang `probabilitas/kemungkinan/akurasi`; label skor wajib `/100` |
| `test/payment_schedule_test.dart` | TP-PAY-03 unit: fire 09:00 WIB + offset harian |
| `run_db_tests.py` / `test_rls_matrix.py` | +due/reminder/aspect (27) · +storage reminders 01f–01i (57) |

## 3. REVIEW — checklist gate CP-04B (PROMPTS §11 PASS criteria)

| Kriteria | Jawaban | Bukti |
|---|---|---|
| Function utama integrated | **Ya** — feed, review, payment, reminder, admin, hapus akun dijalankan end-to-end | flow 35/35 §4 |
| Selected model / justified baseline integrated | **Ya** — `hybrid` α=0.7 active (`model_versions c626ac15…`), justifikasi + limitation jujur (tie n_eval=3, reselect CP-05) | MODEL_CARD §3, flow TP-REC-05 |
| No fabricated metric | **Ya** — semua angka dari artefak run; determinism 2× assert + rerun lintas run identik; data dev sintetis disclaim di card | §4, MODEL_CARD §1 |
| Fallback works | **Ya** — server `baseline-fallback` / SQL trending + klien popularity + label jujur; feed tidak pernah kosong | TP-REC-05 (model=hybrid, 10 item), contract test |
| Tenancy/payment/review flows stable | **Ya** — tenancy 30/30 · payment TP-PAY-02…07 (trigger, guard, next_due, duplikat 409) · review TP-REV suite | §4 |
| Verified review tidak bisa di-bypass | **Ya** — `fn_can_review` server-side: anon 403 (TP-REV-01), tenancy aktif 403 (02a), duplikat 409 (03), aspek 8 wajib (07), pending tak terlihat anon (05a), leak keys bersih (06) | §4 |
| RLS complete | **Ya** — 23/23 tabel + policy, matrix 57/57 (termasuk storage reminders) | §4 |
| Model/dataset reproducibility documented | **Ya** — MODEL_CARD + DATASET_CARD + manifest (dataset/commit/seed/params) + `requirements.txt` + perintah §6 | MODEL_CARD §6 |

### 3.1 REVIEW ML (prompt §11)

| Item | Hasil |
|---|---|
| Dataset version | `ebc8e8e3cadecd7d` (content-hash ekspor; delta CP-03B dijelaskan di MODEL_CARD §1) |
| Split / leakage | temporal 70/10/20 pada `occurred_at`; popularitas dari train saja; catatan jujur: fitur rating = agregat terkini (leakage ringan, dicatat bukan disembunyikan) |
| P@K/R@K/NDCG/HR | hybrid P@5 0.267 · R@5 1.0 · NDCG@5/10 1.0 · HR 1.0 (tabel lengkap vs popularity/content di MODEL_CARD §2) |
| Cold-start | `n_cold_users=0` → subgroup kosong (N/A, bukan 0 palsu) |
| Coverage | catalog 41.7% (hard filter membuang 21 test positive — diungkap) · user 100% |
| NLP | **N/A by gate**: 4 baris review (3 approved) < syarat labeling → tanpa label, tanpa model, tanpa Macro F1 karangan (MODEL_CARD §5) |
| Error analysis | content_based lebih buruk (NDCG 0.877); hybrid=popularity (gap 0.0) pada data kecil → keterbatasan seleksi terbuka |
| Inference latency | p50 169 ms · p95 478 ms · max 918 ms (15 panggilan auth) — di bawah ambang NFR-ML-04 (≤2000 ms) |
| Fallback behavior | 3 lapis (aktif→klien→kosong tak mungkin bila ada listing) |
| Model/dataset card | `MODEL_CARD.md` + `DATASET_CARD.md` |

### 3.2 REVIEW product/security

- Tenancy transition integrity: FSM via policy split anti-TOCTOU (CP-04A)
  + suite 30/30 tetap hijau setelah migration baru.
- Payment consistency: trigger `next_due` terbukti (TP-PAY-05: setelah bayar
  Nov, `next_due` tetap due terbayar paling awal = 2026-10-01, bukan Desember);
  guard `payment_schedules_guard` (tenant hanya offsets); `batal_bayar` hanya
  svc (TP-PAY-04); duplikat request 409.
- Notification behavior: offsets hanya lewat guard (TP-PAY-05), regen rows
  tanpa duplikat + `cancelled` lama, boot receiver ada di manifest, tanpa
  exact alarm (AndroidManifest dikomentari eksplisit).
- Privacy: agregat insight tanpa identitas reviewer; `TP-REV-06` leak-keys
  kosong; hapus akun = anonimisasi profil + rename email + null interaksi +
  berkas storage terhapus (TP-PRIV-02 `list2=[]`); audit admin-only.

## 4. Validation — hasil perintah (evidence)

```text
dart format .                          → 55 files, 0 changed
flutter analyze                        → No issues found
flutter test                           → 33/33 PASS
  - review validation (3) · copy scan (2) · payment schedule unit
  - contract RPC anon nyata · boot widget · EWKB/cache/compare …
python3 scripts/run_db_tests.py        → 27/27 PASS  (baru: due, reminder, aspect)
python3 scripts/test_rls_matrix.py     → 57/57 PASS  (23/23 tabel; +storage reminders 01f–01i)
python3 scripts/test_tenancy_flow.py   → 30/30 PASS  (regresi pasca-migration)
python3 scripts/test_cp04b_flow.py     → 35/35 PASS  (diulang 2×, sekali setelah activate model)
ML determinism                         → run 2× identik; rerun 20260925T170952Z metrics
                                         == 20260925T065411Z; git_dirty=false
activate_model.py                      → idempoten; active = c626ac15… artifact_uri run bersih
latency feed_recommendations           → p50 169 ms / p95 478 ms / max 918 ms (15 panggilan)
AndroidManifest XML parse              → well-formed (application: activity, meta-data, 2 receiver)
secret scan (nilai Aman.md + JWT/sbp_) → bersih (kata 'service_role' hanya di guard/docs/grant;
                                         'sbp_' hanya label teks laporan; PROJECT_REF = info publik)
emoji scan lib/**/*.dart               → 0  (setelah fix 'dokumen ✓' → teks)
Aman.md ignored                        → .gitignore ✓ (tidak ikut commit)
```

## 5. Masalah yang ditemukan & diperbaiki (FIX)

| # | Masalah | Severity | Bukti awal | Perbaikan | Verifikasi ulang |
|---|---|---|---|---|---|
| 1 | `rooms_select` listable-only → room count admin 36/40 | P1 (backend) | flow TP-ADM-01 | migration `…010015` supersede + `app_is_admin()` | TP-ADM-01 PASS 40/40 |
| 2 | trigger `facilities_deactivate` jalan sebagai admin → policy `property_facilities_delete` owner-only → 0 row terhapus | P1 (backend) | probe admin hapus fasilitas | migration `…010016` → SECURITY DEFINER | probe 10→0→10 (restore) PASS |
| 3 | `AndroidManifest.xml` malformed — `</activity>` kembar setelah penyisipan receiver notifikasi → build pasti gagal | **P0 (build)** | `ElementTree ParseError: line 41` | hapus tag kembar, struktur kembali sama seperti HEAD + 2 receiver | XML well-formed parse ✓ |
| 4 | Suite flow memakai body array telanjang untuk delete storage massal → 400 (kontrak server = `{"prefixes":[…]}` — sama dengan `storage_client` 2.8 `remove()`; **app benar, test salah**) | P1 (test integrity) | TP-PRIV-02 `del=400`, file tersisa | test memakai body prefixes | TP-PRIV-02 PASS: `del=200`, `list2=[]` |
| 5 | `'dokumen ✓'` emoji di list admin | P1 (AGENTS 4.9) | emoji scan | teks `dokumen terlampir` | emoji scan 0 |
| 6 | Batch bug authoring suite flow: PK komposit tanpa kolom `id` (owner_profiles/property_facilities), `select=id` gagal di review_aspect_scores, PGRST102 batch-insert kunci beda, review pending hanya terlihat penulis, retry login `URLError` | P1 (test integrity) | run awal suite | diperbaiki per kasus; `audit()` mirror rpc; cleanup dua arah | 35/35 dua kali berturut |

## 6. Deviasi, defer, dan keputusan

1. **Seleksi hybrid dengan data kecil**: metrik terikat (NDCG gap 0.0,
   n_eval=3) → hybrid aktif karena aturan FR-ML-03 (popularity = fallback,
   bukan model utama) + limitation terbuka di MODEL_CARD; **reseleksi wajib**
   di CP-05+ saat data tumbuh (R-026). Bukan klaim "lebih akurat".
2. **NLP baseline tidak dibangun** (deferred by gate, bukan lupa): 4 baris
   review jauh di bawah syarat labeling → `Macro F1/P/R = N/A`, pipeline
   dievaluasi ulang CP-05 bila data + lisensi UGC (R-017) siap.
3. **Copy fallback ≠ literal DESIGN §35**: DESIGN: "…pilihan berdasarkan
   preferensi kamu"; app: "Rekomendasi personal tidak tersedia — menampilkan
   kos populer." Alasan: fallback klien memang murni popularity (tanpa
   preferensi) → literal DESIGN akan overclaim. Rekomendasi: perbarui
   DESIGN §35 pada review desain berikutnya.
4. **`fire_at` seed vs app**: seed = tengah malam WIB (17:00Z−offset), app
   = 02:00 UTC (09:00 WIB). Selisih tidak berdampak perilaku — `fire_at`
   write-only; UI/notifikasi menghitung ulang `due+offset` (DESIGN §26);
   TP-PAY-03 menguji formula seed apa adanya → R-025 (P2, sinkronkan saat
   seed produksi).
5. **Pulse review** (`review_type CHECK` memuat `'pulse'`) tetap P1 per
   CP-02 scope-lock; UI hanya `final`.
6. **Audit tanpa trigger**: `audit_logs` ditulis client lewat rpc
   `audit_log_write` (jalur sama dengan app) — sengaja minim trigger;
   `interactions` tanpa UPDATE policy → metric immunitas (PATCH 204,
   0 row) diverifikasi di TP-ADM-07.
7. **Dua supersede migration** (`…010015/010016`): perbaikan policy/trigger
   atas tabel live via `create or replace`, non-destruktif, divergensi
   dicatat di sini.
8. **Build on-device tetap deferred** atas instruksi owner ("build nanti
   saja") → R-024 tidak berubah status.

## 7. Risiko & keterbatasan (update)

- **R-020 → Mitigated parsial (CP-04B)**: pengingat 7/3/1/0 dapat dipilih
  tenant + notifikasi lokal + reschedule boot + status due tampil; push
  server background tetap P1.
- **R-024 (Open)**: alpha belum pernah di-compile/run on-device; risiko
  integrasi plugin native (notifikasi, geolocator, image_picker) tak teruji
  sampai `flutter build apk` dieksekusi.
- **R-017 (pending)**: ToS v1.0 menunggu ok owner — lisensi UGC = prasyarat
  NLP CP-05.
- **R-001/R-002 (Open → CP-05)**: data interaksi/review masih sintetis kecil;
  NLP gate tertutup sampai data cukup.
- **R-025 (baru, P2)**: selisih `fire_at` seed (00:00 WIB) vs tampilan app
  (09:00 WIB) — kosmetik, sinkronkan formula seed saat produksi.
- **R-026 (baru)**: seleksi model pada n_eval=3 + gap 0.0 rapuh → wajib
  re-evaluasi kandidat saat dataset produksi berbeda material (MODEL_CARD §7).

## 8. Gate decision

**PASS** — seluruh PASS criteria PROMPTS §11 terpenuhi dengan evidence yang
dieksekusi di sesi ini: function utama integrated (flow 35/35), model hybrid
teraktif dengan justifikasi + limitation terbuka, tanpa metrik karangan
(determinism terbukti lintas run), fallback bekerja (server+klien), alur
tenancy/payment/review stabil (30/30 + TP-PAY + TP-REV), review verified
mustahil di-bypass dari client (403/409 server-side), RLS lengkap (57/57 +
27/27), reproducibility terdokumentasi (MODEL_CARD + DATASET_CARD + manifest).
0 analyze issue · 33/33 unit · secret/emoji scan bersih. Enam masalah
ditemukan & diperbaiki (1 P0 manifest, 5 P1) — tidak ada P0/P1 tersisa.

## 9. Next allowed step

**Sprint 7 / CP-05A** — AUTHORIZED oleh gate ini. Prasyarat non-blocking
yang tetap disarankan: `flutter build apk` + device smoke (R-024) kapan owner
siap; ok owner untuk teks ToS (R-017) sebelum NLP CP-05.
