# CP-02 — Functional Requirements, User Stories, Acceptance Criteria

Date: 2026-09-25
Status: LOCKED V1 (mengikat PRD §7-§24; scope = `cp02-scope-lock.md`)
Konvensi: `FR-<domain>-NN` = requirement; `AC-<area>-NN` = acceptance
criterion terukur; `TP-<area>-NN` = test case (`cp02-test-plan.md`).

---

## 1. FR Catalog

### 1.1 Auth & Onboarding (FR-AUTH, FR-ONB)

| ID | Requirement (terukur) | Problem | AC |
|---|---|---|---|
| FR-AUTH-01 | User dapat register dengan email+password (Supabase auth) dan wajib menerima ToS v1.0 + data consent sebelum akun aktif | H-01 (akses) | AC-AUTH-01..03 |
| FR-AUTH-02 | Setiap akun punya tepat satu role ∈ {seeker, owner, super_admin}; role dipilih saat register untuk seeker/owner; super_admin TIDAK dapat self-register | PRD §5 | AC-AUTH-04, AC-AUTH-05 |
| FR-AUTH-03 | Session dipulihkan aman saat app dibuka ulang; refresh token tersimpan secure storage | PRD §7 | AC-AUTH-06 |
| FR-AUTH-04 | Logout mengakhiri sesi lokal + revoke server; sesi lain ikut mati pada logout-all | PRD §7 | AC-AUTH-07 |
| FR-AUTH-05 | Tidak ada secret/service-role/privileged token dalam bundel app | PRD §7, AGENTS §4.8 | AC-AUTH-08 |
| FR-AUTH-06 | Register menerima ToS versi + timestamp; consent data dapat dilihat & ditarik di settings | A-07 | AC-AUTH-09, AC-PRIV-03 |
| FR-ONB-01 | Seeker menyelesaikan onboarding: primary campus, budget min/max, gender preference, tipe kamar, prioritas fasilitas, transport mode, maks jarak/waktu, target move-in | H-01/H-05, PRD §6.1 | AC-ONB-01 |
| FR-ONB-02 | Preferensi dapat diubah kapan pun di settings; feed direkomputasi pada pembukaan berikutnya | PRD §8.1 | AC-ONB-02 |
| FR-ONB-03 | Owner register → `owner_profiles` status `pending`; listing tidak publik sebelum verified | PRD §9.1 | AC-OWN-01 |

### 1.2 Discovery (FR-SEARCH, FR-MAP, FR-SAVED, FR-CMP)

| ID | Requirement | Problem | AC |
|---|---|---|---|
| FR-SEARCH-01 | Filter minimum: harga, tipe kos, gender policy, availability, fasilitas, tipe kamar, rating min, radius/jarak, campus, move-in | H-01 | AC-SEARCH-01 |
| FR-SEARCH-02 | Hasil dipaginasi maks 20 item/halaman; sort pilihan: relevansi (default), harga, jarak | H-01 (search cost) | AC-SEARCH-02, AC-SEARCH-03 |
| FR-SEARCH-03 | Property detail menampilkan availability per kamar + timestamp "diperbarui {tanggal}" (`last_availability_update_at`) | H-04 (listing stale, Mamikos evidence) | AC-SEARCH-04 |
| FR-MAP-01 | Explore Map menampilkan marker property terfilter; clustering aktif bila marker > 100 dalam viewport | H-01 | AC-MAP-01 |
| FR-MAP-02 | "Search this area" hanya mengeksekui query setelah viewport berhenti ≥300 ms; hasil = isi viewport baru | H-01 (PRD §8.3) | AC-MAP-02, AC-MAP-03 |
| FR-MAP-03 | "Near me" meminta izin lokasi saat ditekan (just-in-time); ditolak → tetap bisa cari via kampus/area manual; TIDAK ada permintaan ulang otomatis | A-06, PRD §14.3 | AC-MAP-04, AC-LOC-01 |
| FR-MAP-04 | Marker kampus tampil & dapat dipilih sebagai pusat pencarian | H-01 (campus-aware) | AC-MAP-05 |
| FR-MAP-05 | Aplikasi tidak pernah menjalankan pelacakan lokasi di background (tanpa foreground service/geofence) | PRD §14.3, privacy | AC-LOC-01, AC-LOC-02 |
| FR-SAVED-01 | Favorite/unfavorite; list saved; saat dibuka ulang availability di-refresh dari server | H-01 | AC-SAVED-01, AC-SAVED-02 |
| FR-CMP-01 | Compare maks 3 listing (client-side): harga, jarak, travel time (bila ada), availability, fasilitas, rating verified, aspek review, skor rekomendasi | H-05, PRD §8.6 | AC-CMP-01 |

### 1.3 Recommendation (FR-REC, FR-ML-01/03)

| ID | Requirement | Problem | AC |
|---|---|---|---|
| FR-REC-01 | Feed rekomendasi personal di Home, direkomendasikan setelah onboarding; urutan = model terpilih setelah hard filter preferensi | H-05 | AC-REC-01 |
| FR-REC-02 | Setiap kartu rekomendasi menampilkan ≥1 alasan valid dari kamus alasan: sesuai budget / dekat kampus / fasilitas prioritas cocok / rating verified tinggi / aspek positif | PRD §13.1 explainability | AC-REC-02 |
| FR-REC-03 | Bila layanan/model gagal atau user cold-start tanpa interaksi: ranking fallback (content-based → popularity) — feed tidak pernah kosong bila ada ≥1 listing aktif | H-05, A-05 | AC-REC-03 |
| FR-REC-04 | Skor ditampilkan sebagai **skor kecocokan 0–100 (normalized)**; label UI dilarang memakai "kemungkinan/akurasi/berhasil %" | PRD §13.1, AGENTS §4.4 | AC-REC-04 |
| FR-ML-01 | Setiap feed menyimpan `recommendation_logs` (user, property, model_version, rank, score, reason_codes, waktu) | evaluasi + explanation | AC-ML-01 |
| FR-ML-03 | Cold-start: urutan sinyal = preferensi onboarding → content-based → relevansi kampus/geo → sinyal verified → popularity hanya tie-breaker/fallback; listing baru TIDAK didiskriminasi karena 0 interaksi | PRD §13.1 | AC-REC-05 |

### 1.4 Owner (FR-OWN)

| ID | Requirement | Problem | AC |
|---|---|---|---|
| FR-OWN-01 | Owner upload dokumen verifikasi (bucket privat); status pending→verified/rejected oleh super_admin (reject wajib alasan) | H-03 (trust) | AC-OWN-01, AC-ADM-02 |
| FR-OWN-02 | Owner CRUD property: nama, deskripsi, alamat, pin geo (dari peta), gender policy, aturan, foto (cover+galeri), fasilitas; listing baru = pending | H-03 | AC-OWN-02 |
| FR-OWN-03 | Owner CRUD room: kode, tipe, harga (≥0), deposit (≥0), ukuran, availability date, status ∈ {available, reserved, occupied, maintenance, inactive} dengan transisi valid | H-03, H-02 | AC-OWN-03, AC-OWN-04 |
| FR-OWN-04 | Perubahan availability room meng-update `last_availability_update_at` properti secara otomatis | H-04 | AC-OWN-05 |
| FR-OWN-05 | Accept request → satu transaksi atomik: buat tenancy aktif + room status occupied + request accepted; reject wajib alasan | H-02/H-03 | AC-TEN-01, AC-TEN-02 |
| FR-OWN-06 | Owner menandai pembayaran paid/unpaid per due date; tidak ada status paid yang tercipta tanpa aksi owner | H-02 | AC-PAY-04 |
| FR-OWN-07 | Owner dashboard: total property/room, okupansi, room available, tenant aktif, status pembayaran (due soon/overdue), jumlah view/save/request, rata-rata rating verified, ringkasan aspek | H-03, PRD §9.6 | AC-OWN-06 |

### 1.5 Tenancy & Payment (FR-TEN, FR-PAY)

| ID | Requirement | Problem | AC |
|---|---|---|---|
| FR-TEN-01 | Seeker kirim tenancy request (maks 1 pending per room per seeker); dapat membatalkan selama pending | H-02 | AC-TEN-03 |
| FR-TEN-02 | Tenancy: start date, billing cycle (monthly), amount, due day, status {active, ended}; owner dapat mengakhiri / memperpanjang (ubah end_date) | H-02 | AC-TEN-04 |
| FR-TEN-03 | Tenant home menampilkan kartu tenancy aktif + due date berikutnya | H-02 (lifecycle) | AC-TEN-05 |
| FR-TEN-04 | Tenant melihat riwayat pembayaran miliknya sendiri; seeker lain TIDAK dapat membaca | H-02, privacy | AC-RLS-T1 |
| FR-PAY-01 | `payment_schedules` diturunkan dari tenancy: cycle, due day, amount, timezone **Asia/Jakarta**; due date akhir-bulan ditangani (31→28/29/30) | H-02 | AC-PAY-01 |
| FR-PAY-02 | Daftar due date dibuat 12 bulan ke depan saat tenancy aktif; status dihitung {unpaid, paid, overdue} (overdue bila tanggal > due & belum paid) | H-02 | AC-PAY-02 |
| FR-PAY-03 | Reminder offset {7,3,1,0} + custom 1–30 hari via local scheduled notification; saat schedule/due berubah → lama dibatalkan + dibuat ulang (tanpa duplikat) | PRD §11.2 | AC-PAY-03, AC-PAY-05 |
| FR-PAY-04 | Owner & tenant melihat status pembayaran yang sama sesuai hak akses; due soon/overdue tampil di home masing-masing | PRD §9.5/§11 | AC-PAY-06 |

### 1.6 Verified Review (FR-REV, FR-ML-02)

| ID | Requirement | Problem | AC |
|---|---|---|---|
| FR-REV-01 | Eligibility server-side (RLS/check): punya tenancy pada property itu; review_type=final hanya setelah tenancy `ended`; satu review final per tenancy | H-04 | AC-REV-01..03 |
| FR-REV-02 | Form final review: rating overall (1–5, wajib) + 8 rating aspek (1–5, wajib) + teks bebas (opsional, min 0–1000 karakter) | PRD §12.3 | AC-REV-04 |
| FR-REV-03 | Review masuk `pending`; super_admin approve/reject (reject wajib alasan); konten tidak pernah diedit pihak lain | PRD §10, §12.4 | AC-REV-05, AC-ADM-04 |
| FR-REV-04 | Publik hanya melihat review `approved`; identitas diminimalkan: label "Penghuni terverifikasi" + bulan-tahun, tanpa nama penuh/nomor | PRD §12.4, privacy | AC-REV-06 |
| FR-ML-02 | NLP aspek mengisi `review_aspect_scores` (source=nlp, 8 aspek, label {positive, negative, neutral, insufficient_evidence}, confidence, model_version) HANYA dari review approved; teks asli tidak diubah | PRD §13.2 | AC-NLP-01..03 |

### 1.7 Admin (FR-ADM), Notifications (FR-NOT), Privacy (FR-PRIV)

| ID | Requirement | Problem | AC |
|---|---|---|---|
| FR-ADM-01 | Platform overview: jumlah user/property/room/tenancy/review/report + status antrian moderasi | operasi | AC-ADM-01 |
| FR-ADM-02 | Verify/reject owner & listing; reject wajib `reason`; state transition tervalidasi | H-03/H-04 | AC-ADM-02, AC-ADM-03 |
| FR-ADM-03 | Moderasi report (open→resolved/rejected) & review (approve/reject/hide) dengan alasan | H-04 | AC-ADM-04 |
| FR-ADM-04 | Master data facilities & campuses (CRUD, is_active) | data | AC-ADM-05 |
| FR-ADM-05 | Semua aksi privileged menulis `audit_logs` (actor, action, target, detail, waktu) dan hanya bisa ditulis via jalur aksi admin | PRD §16 | AC-ADM-06 |
| FR-ADM-06 | Admin dapat melihat ringkasan interaksi/model (count event, model_versions) — tanpa ubah hasil evaluasi | PRD §10 | AC-ADM-07 |
| FR-NOT-01 | Local scheduled notification untuk payment reminder (FR-PAY-03); user dapat memilih offset & mematikan | PRD §20 | AC-PAY-03 |
| FR-NOT-02 | Status request/verifikasi/review tampil di layar terkait saat app dibuka (derived status, tanpa inbox di V1) | PRD §20 | AC-TEN-06 |
| FR-PRIV-01 | Koordinat GPS tidak pernah disimpan ke tabel mana pun (hanya argumen query sesaat); analytics menyimpan bbox viewport / campus_id, bukan titik presisi | PRD §14.3 | AC-LOC-02, AC-PRIV-01 |
| FR-PRIV-02 | Settings: lihat status consent, tarik consent (event baru berhenti dikumpulkan), ajukan penghapusan akun | A-07 | AC-PRIV-02, AC-PRIV-03 |
| FR-PRIV-03 | Dokumen verifikasi & bukti bayar hanya dapat diakses via signed URL oleh pemiliknya / super_admin; bucket privat tidak public | PRD §17 | AC-STOR-01, AC-STOR-02 |

---

## 2. User Stories (V1)

**Seeker**
1. Sebagai pencari kos, saya ingin menyaring kos sesuai budget & fasilitas (FR-SEARCH-01, AC-SEARCH-01) agar tidak membaca listing yang tidak relevan. → H-01
2. Sebagai pencari kos, saya ingin melihat peta kos dekat kampus tanpa harus menyerahkan lokasi persis (FR-MAP-03/04, AC-MAP-04/05) agar pencarian saya tetap privat. → H-01
3. Sebagai pencari kos, saya ingin feed rekomendasi beserta alasannya (FR-REC-01/02, AC-REC-01/02) agar keputusan lebih cepat. → H-05
4. Sebagai pencari kos, saya ingin tahu kapan kamar terakhir diperbarui ketersediaannya (FR-SEARCH-03, AC-SEARCH-04) agar tidak kena info basi. → H-04
5. Sebagai pencari kos, saya ingin membandingkan maksimal 3 kos (FR-CMP-01, AC-CMP-01) agar pilihan final berbasis data. → H-05
6. Sebagai pemohon sewa, saya ingin melihat status request saya di layar tenancy (FR-TEN-01/FR-NOT-02, AC-TEN-03/AC-TEN-06) tanpa perlu chat bertanya. → H-02

**Tenant (state seeker)**
7. Sebagai tenant, saya ingin diingatkan jatuh tempo 7/3/1/0 hari sebelum tanggal (FR-PAY-03, AC-PAY-03) agar tidak telat bayar. → H-02
8. Sebagai tenant, saya ingin melihat riwayat pembayaran saya (FR-TEN-04, AC-RLS-T1) dan user lain tidak bisa. → H-02
9. Sebagai tenant akhir masa sewa, saya ingin memberi review final untuk kos ini saja (FR-REV-01/02, AC-REV-01..04) agar pengalaman saya tercatat dan bermanfaat. → H-04

**Owner**
10. Sebagai pemilik kos, saya ingin satu tempat mengelola kamar, harga, dan status (FR-OWN-02/03, AC-OWN-02..04) karena selama ini saya pakai buku/Excel. → H-03
11. Sebagai pemilik kos, saya ingin menerima/menolak pemohon dalam satu aksi yang langsung men-update status kamar (FR-OWN-05, AC-TEN-01/02) agar tidak double-booking. → H-03
12. Sebagai pemilik kos, saya ingin menandai pembayaran yang sudah masuk (FR-OWN-06, AC-PAY-04) dan melihat siapa yang overdue (FR-OWN-07, AC-PAY-06). → H-02/H-03
13. Sebagai pemilik kos terverifikasi, saya ingin melihat ringkasan aspek review (FR-OWN-07, AC-OWN-06) agar tahu yang harus diperbaiki. → H-03/H-04

**Super Admin**
14. Sebagai super admin, saya ingin memverifikasi owner/listing dengan alasan penolakan wajib (FR-ADM-02, AC-ADM-02/03) agar platform tetap tepercaya. → H-04
15. Sebagai super admin, saya ingin setiap aksi privileged tercatat di audit log (FR-ADM-05, AC-ADM-06) agar dapat ditelusuri. → operasi
16. Sebagai super admin, saya ingin memoderasi review/report (FR-ADM-03, AC-ADM-04) tanpa mengubah isi review orang. → H-04

---

## 3. Acceptance Criteria Master (terukur)

| AC | Given / When / Then (terukur) | TP |
|---|---|---|
| AC-AUTH-01 | Given email valid + password ≥8 karakter, When register tanpa menerima ToS, Then akun TIDAK aktif dan pesan error muncul dekat field | TP-AUTH-01 |
| AC-AUTH-02 | Given registrasi valid + ToS diterima, When submit, Then akun dibuat dengan role sesuai pilihan & kolom `tos_accepted_at` terisi | TP-AUTH-02 |
| AC-AUTH-03 | Given password <8 karakter, Then submit ditolak, input lama tidak hilang | TP-AUTH-01 |
| AC-AUTH-04 | Given akun dibuat via registrasi publik, Then role ∈ {seeker, owner} saja (super_admin tidak muncul sebagai opsi) | TP-AUTH-03 |
| AC-AUTH-05 | Given sesi token super_admin tidak valid/dibuat sendiri di client, When dipakai aksi admin, Then ditolak oleh RLS/policy | TP-RLS-06 |
| AC-AUTH-06 | Given app di-kill lalu dibuka lagi, Then sesi user aktif kembali tanpa login ulang | TP-AUTH-04 |
| AC-AUTH-07 | Given user menekan logout, Then token lokal terhapus & request berikutnya meminta login | TP-AUTH-05 |
| AC-AUTH-08 | Given build APK, When discan string `service_role`/secret key, Then tidak ditemukan | TP-SEC-01 |
| AC-AUTH-09 | Given user menekan tarik consent di settings, Then `data_consent_at` di-null-kan, event baru tidak tercatat, UI menampilkan status "nonaktif" | TP-PRIV-01 |
| AC-ONB-01 | Given onboarding lengkap (semua field wajib), When selesai, Then `user_preferences` terisi lengkap & feed terbuka (bukan error) | TP-ONB-01 |
| AC-ONB-02 | Given preferensi diubah budget_max 1jt→2jt, When feed dibuka ulang, Then property >2jt dapat muncul di hasil (query test) | TP-REC-06 |
| AC-SEARCH-01 | Given filter harga 500.000–1.500.000, When diterapkan, Then 100% hasil (list & marker) berada dalam range harga tersebut | TP-SEARCH-01 |
| AC-SEARCH-02 | Given >20 hasil, When halaman 1 dimuat, Then tepat ≤20 item; halaman 2 memuat ≤20 item berikutnya tanpa duplikat | TP-SEARCH-02 |
| AC-SEARCH-03 | Given sort "harga termurah", Then urutan non-decreasing pada seluruh halaman | TP-SEARCH-03 |
| AC-SEARCH-04 | Given room status berubah oleh owner, When detail property dibuka, Then timestamp "diperbarui" = waktu perubahan (≤1 menit selisih server) | TP-SEARCH-04 |
| AC-MAP-01 | Given filter & viewport identik antara mode list dan map, Then jumlah marker == jumlah hasil list | TP-MAP-01 |
| AC-MAP-02 | Given viewport digeser lalu berhenti ≥300 ms, Then tepat 1 query baru terkirim (debounce tervalog) | TP-MAP-02 |
| AC-MAP-03 | Given "Search this area" ditekan, Then hasil hanya berisi property dalam bbox viewport baru | TP-MAP-03 |
| AC-MAP-04 | Given izin lokasi ditolak, When "Near me" ditekan lagi, Then dialog izin tidak muncul otomatis; pencarian kampus manual tetap berfungsi | TP-MAP-04 |
| AC-MAP-05 | Given marker kampus dipilih, Then map re-berpusat & list terfilter radius default kampus | TP-MAP-05 |
| AC-LOC-01 | Given app dibuka, When seluruh alur pencarian dijalankan tanpa menekan "Near me", Then TIDAK ada permintaan location permission | TP-LOC-01 |
| AC-LOC-02 | Given pencarian "Near me" dilakukan, When query selesai, Then tidak ada kolom/tabel yang menyimpan koordinat user (audit query/schema) | TP-LOC-02 |
| AC-SAVED-01 | Given property di-save, When list Saved dibuka ulang, Then item muncul dan status availability = nilai server terbaru | TP-SAVED-01 |
| AC-SAVED-02 | Given tombol save ditekan 2× dalam <500 ms, Then hanya 1 baris favorite (unique constraint) | TP-SAVED-02 |
| AC-CMP-01 | Given 3 property dipilih, When ke-4 dipilih, Then ditolak dengan pesan "maksimal 3"; tabel compare menampilkan 8 kolom sesuai FR | TP-CMP-01 |
| AC-REC-01 | Given ≥1 listing aktif, When Home dibuka (user baru maupun user lama), Then feed menampilkan ≥1 item (bukan empty state error) | TP-REC-01 |
| AC-REC-02 | Given feed dirender, When setiap kartu diperiksa, Then ≥1 reason code tampil & reason berasal dari kamus alasan (6 kode valid) | TP-REC-02 |
| AC-REC-03 | Given ML service tidak merespons (timeout), When Home dibuka, Then fallback ranking dipakai, feed tetap terisi, tidak ada crash | TP-REC-03 |
| AC-REC-04 | Given skor ditampilkan, Then format "Skor kecocokan NN/100"; kata "probabilitas/kemungkinan/akurasi" tidak ada di teks UI (scan widget) | TP-REC-04 |
| AC-REC-05 | Given user baru tanpa interaksi, When feed dibuka, Then ranking memakai preferensi+geo+verified (urutan sinyal FR-ML-03) dan ≥1 hasil muncul | TP-REC-05 |
| AC-ML-01 | Given feed dirender, Then baris `recommendation_logs` terisi (user, property, model_version, rank, score, reason_codes) untuk tiap item | TP-ML-01 |
| AC-OWN-01 | Given owner pending, When submit property, Then listing status `pending` & tidak muncul di hasil publik | TP-OWN-01 |
| AC-OWN-02 | Given owner verified menambah property lengkap + pin geo, When disimpan, Then row ada, `location` valid point (SRID 4326), status pending | TP-OWN-02 |
| AC-OWN-03 | Given room price −1000, When disimpan, Then ditolak CHECK constraint (error, bukan tersimpan) | TP-OWN-03 |
| AC-OWN-04 | Given transisi room occupied→maintenance diizinkan dan occupied→available tanpa perantaraan tidak sah, Then yang kedua ditolak (validasi transisi) | TP-OWN-04 |
| AC-OWN-05 | Given room status diubah owner, Then `properties.last_availability_update_at` = waktu perubahan (±0 detik, trigger) | TP-OWN-05 |
| AC-OWN-06 | Given 3 property (2 aktif, 1 draft), When dashboard dibuka, Then angka total/okupansi/available/tenant/pembayaran sesuai query ground-truth fixture | TP-OWN-06 |
| AC-TEN-01 | Given owner menekan accept, When transaksi selesai, Then tenancy aktif ADA + room = occupied + request = accepted (ketiganya dalam satu transaksi; gagal = tidak ada yang berubah) | TP-TEN-01 |
| AC-TEN-02 | Given owner menekan accept 2× dalam <500 ms, Then hanya 1 tenancy aktif (idempotent) | TP-TEN-02 |
| AC-TEN-03 | Given seeker sudah punya request pending di room X, When request lagi ke X, Then ditolak (unique partial index) | TP-TEN-03 |
| AC-TEN-04 | Given end tenancy oleh owner, Then status = ended, room kembali available, review final terbuka (eligibility) | TP-TEN-04 |
| AC-TEN-05 | Given tenancy aktif, When tenant home dibuka, Then kartu tenancy + due date berikutnya tampil sesuai data | TP-TEN-05 |
| AC-TEN-06 | Given request diterima/ditolak, When tenant membuka app, Then status request baru terlihat di layar tenancy (tanpa inbox push) | TP-TEN-06 |
| AC-RLS-T1 | Given seeker B (bukan pemilik data), When SELECT payment_records/tenancies milik seeker A, Then 0 baris | TP-RLS-01 |
| AC-PAY-01 | Given tenancy start 31 Jan (monthly), Due dates Feb = 28/29 (tahun kabisat diuji), Maret = 31 (unit test kasus) | TP-PAY-01 |
| AC-PAY-02 | Given tenancy aktif t, When row dihitung, Then ada 12 due date berikutnya & status overdue otomatis bila now > due_date & unpaid | TP-PAY-02 |
| AC-PAY-03 | Given offset {7,3,1,0} & custom 5, When schedule dibuat, Then 4+1 reminder terjadwal tepat pada hari-H−offset (timezone Asia/Jakarta) | TP-PAY-03 |
| AC-PAY-04 | Given payment unpaid, When owner menandai paid, Then status paid + paid_at terisi; seeker B tidak punya jalan men-set paid (RLS) | TP-PAY-04 |
| AC-PAY-05 | Given due date diubah owner, When proses regenerasi, Then reminder lama status cancelled & reminder baru sesuai offset baru; tidak ada reminder ganda utk waktu sama | TP-PAY-05 |
| AC-PAY-06 | Given 1 overdue + 1 due-soon, When home owner & tenant dibuka, Then keduanya menampilkan status yang sama (angka identik) | TP-PAY-06 |
| AC-REV-01 | Given user tanpa tenancy, When INSERT review, Then ditolak (RLS 403/0 row) | TP-REV-01 |
| AC-REV-02 | Given tenancy masih active, When INSERT review final, Then ditolak; setelah ended → diterima | TP-REV-02 |
| AC-REV-03 | Given 1 final review utk tenancy X, When INSERT ke-2, Then ditolak unique(tenancy_id, review_type) | TP-REV-03 |
| AC-REV-04 | Given form review, When overall=4 & 8 aspek terisi & teks 1001 karakter, Then submit ditolak (validasi panjang ≤1000); seluruh field wajib terisi sebelum submit | TP-REV-04 |
| AC-REV-05 | Given review pending, When publik membuka property, Then review TIDAK tampil; setelah approve → tampil | TP-REV-05 |
| AC-REV-06 | Given review approved tampil publik, Then tidak ada nama lengkap/phone/identitas; hanya "Penghuni terverifikasi • {Mon YYYY}" | TP-REV-06 |
| AC-NLP-01 | Given review status ≠ approved, When pipeline NLP dijalankan, Then baris aspect_scores tidak dibuat untuk review itu | TP-NLP-01 |
| AC-NLP-02 | Given confidence < threshold (didefinisikan di model card), Then label = `insufficient_evidence`, bukan pos/neg | TP-NLP-02 |
| AC-NLP-03 | Given NLP selesai, Then teks review asli tidak berubah (checksum before/after) & setiap baris punya model_version_id | TP-NLP-03 |
| AC-ADM-01 | Given fixture 2 property/3 tenancy, When overview dibuka, Then seluruh angka = query ground truth | TP-ADM-01 |
| AC-ADM-02 | Given reject owner tanpa reason, When submit, Then ditolak (reason NOT NULL) | TP-ADM-02 |
| AC-ADM-03 | Given listing pending, When approve, Then verification_status=verified & listing tampil publik; reject → tetap tidak tampil + reason tersimpan | TP-ADM-03 |
| AC-ADM-04 | Given report open, When resolve dengan catatan, Then status resolved + note tersimpan; review yang di-hide tetap isi asli (flag saja) | TP-ADM-04 |
| AC-ADM-05 | Given facility baru diubah admin, Then property yang menandai facility itu ikut ter-update/tidak aktif sesuai is_active | TP-ADM-05 |
| AC-ADM-06 | Given aksi verify owner, When selesai, Then 1 baris audit_logs (actor, action, target, detail, ts) muncul | TP-ADM-06 |
| AC-ADM-07 | Given 100 event interaksi, When model summary dibuka, Then count per event_type cocok (tanpa kemampuan ubah metrik) | TP-ADM-07 |
| AC-PRIV-01 | Given seluruh skema, When dicari kolom koordinat user, Then tidak ada (kecuali milik property/campus) | TP-LOC-02 |
| AC-PRIV-02 | Given user ajukan hapus akun, When diproses, Then profil terhapus/anonimkan & interaksi lama kehilangan user_id (reteni untuk training agregat) | TP-PRIV-02 |
| AC-PRIV-03 | Given consent ditarik, When event berikutnya dikirim app, Then event TIDAK tersimpan | TP-PRIV-01 |
| AC-STOR-01 | Given URL objek verification-docs tanpa signed URL (anon), When diakses, Then 400/403 | TP-STOR-01 |
| AC-STOR-02 | Given owner X mencoba hapus foto property owner Y (path berbeda), When request, Then ditolak policy storage | TP-STOR-02 |
| AC-OFF-01 | Given koneksi terputus, When membuka list property, Then ditampilkan cache terakhir + banner offline; input form yang sedang diisi TIDAK hilang saat error | TP-OFF-01 |

---

## 4. Traceability Matrix (problem → FR → AC → test)

| Problem (CP-01) | Asumsi | FR | AC | TP |
|---|---|---|---|---|
| H-01 pencarian multi-kriteria & listing stale | A-01 | FR-SEARCH-01..03, FR-MAP-01..05, FR-SAVED-01, FR-CMP-01, FR-ONB-01/02 | AC-SEARCH-*, AC-MAP-*, AC-SAVED-*, AC-CMP-01, AC-ONB-* | TP-SEARCH, TP-MAP, TP-SAVED, TP-CMP, TP-ONB |
| H-02 lifecycle sewa manual (reminder/riwayat) | A-04 | FR-TEN-01..04, FR-PAY-01..04, FR-NOT-01/02 | AC-TEN-*, AC-PAY-*, AC-RLS-T1 | TP-TEN, TP-PAY, TP-RLS |
| H-03 operasional owner terfragmentasi | A-02 | FR-OWN-01..07, FR-ADM-01 | AC-OWN-*, AC-ADM-01 | TP-OWN, TP-ADM |
| H-04 trust informasi (verified review + listing akurat) | A-03 | FR-REV-01..04, FR-SEARCH-03, FR-ADM-02/03, FR-ML-02 | AC-REV-*, AC-SEARCH-04, AC-ADM-02..04, AC-NLP-* | TP-REV, TP-NLP, TP-ADM |
| H-05 filter ≠ ranking (butuh ranking personal) | A-05 | FR-REC-01..04, FR-ML-01/03, FR-AUTH-01..06 | AC-REC-*, AC-ML-01, AC-AUTH-* | TP-REC, TP-ML, TP-AUTH |
| (privacy/location) | A-06, A-07 | FR-MAP-03/05, FR-PRIV-01..03, FR-AUTH-06 | AC-LOC-*, AC-PRIV-*, AC-STOR-* | TP-LOC, TP-PRIV, TP-STOR |

**Kelengkapan:** 56 FR · 72 AC · setiap FR minimal 1 AC · setiap AC merujuk ≥1 TP (dicek di REVIEW).
