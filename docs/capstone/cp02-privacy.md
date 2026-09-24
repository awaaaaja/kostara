# CP-02 — Privacy & Data Retention Notes

Date: 2026-09-25
Status: LOCKED — **menutup A-07 (consent/legal)** dari CP-01; menjadi dasar
review privacy di setiap gate berikutnya. Regulasi rujukan: UU PDP (Indonesia)
minimisasi data + persetujuan + hak hapus; praktik minimum dari PRD §21.

---

## 1. Data inventory (apa yang dikumpulkan, untuk apa, dasar hukum)

| Data | Untuk | Dasar / kontrol | Disimpan di | Retensi |
|---|---|---|---|---|
| Email, password (hashed by Supabase), nama, phone (opsional) | akun & login | kontrak layanan (registrasi + ToS) | Supabase Auth + `profiles` | selama akun |
| ToS version + timestamp | bukti persetujuan | kewajiban legal | `profiles` | selama akun + 5 tahun setelah penutupan (bukti) |
| Preferensi onboarding | personalisasi & filter | kontrak (fungsi inti) | `user_preferences` | selama akun; ikut hapus akun |
| Data interaksi (event perilaku) | training/evaluasi rekomendasi, analitik produk | **persetujuan** (`data_consent_at`), dapat ditarik | `interactions`, `recommendation_logs` | 24 bulan; tarik consent → event baru berhenti; hapus akun → anonimkan |
| Lokasi GPS | "Near me" sesaat | izin sistem JIT; **tidak disimpan** | transient argumen RPC | 0 hari (tidak pernah persist) |
| Bbox peta / campus_id | query & metadata event | bagian fungsi pencarian | argumen query; metadata event | event 24 bulan |
| Foto profil, foto property | listing | kontrak owner (listing) | Storage `avatars`, `property-images` (public read terbatas policy) | ikut akun/property |
| Dokumen verifikasi owner | verifikasi platform | kontrak + kewajiban platform | bucket **privat** + signed URL | dihapus saat akun owner dihapus |
| Tenancy, jadwal & riwayat pembayaran | lifecycle sewa & reminder | kontrak tenant-owner; wajib untuk fungsi | `tenancies`, `payment_*` | ≥2 tahun setelah tenancy berakhir |
| Review (teks, rating) | feedback publik + training NLP | **lisensi UGC di ToS** + review memang konten publik | `reviews` | permanen selama platform; hide ≠ hapus |
| Report, audit log | keamanan & moderasi | kewajiban keamanan platform | `reports`, `audit_logs` | 24 bulan |

Tidak dikumpulkan V1: data finansial kartu/payment credential (PRD §12),
lokasi background, riwayat lokasi, face print, kontak buku telepon.

## 2. Aturan lokasi (ringkas — detail `cp02-geospatial-plan.md` §3)

1. Permission hanya saat tombol "Near me" (just-in-time) — AC-LOC-01.
2. Tanpa izin → seluruh pencarian tetap berfungsi (kampus/area manual).
3. Koordinat GPS tidak pernah masuk tabel/log/metadata event — AC-LOC-02.
4. Tidak ada foreground/background service, tidak ada riwayat trail.
5. Penarikan izin sistem tidak memicu dialog ulang otomatis.

## 3. Consent UX

```text
Registrasi:  checkbox ToS v1.0 (wajib) + ringkasan privasi (wajib baca)
             + checkbox "Gunakan data interaksi saya untuk meningkatkan
             rekomendasi" (default aktif, dapat dilepas)
Settings:    menampilkan status ToS & consent
             [Tarik consent] → data_consent_at = NULL, event berhenti
             [Ajukan hapus akun] → alur konfirmasi → proses penghapusan
```

- Penarikan consent tidak menghapus riwayat tenancy/pembayaran milik owner
  lain (kepentingan bersama pihak kedua) — dijelaskan di ringkasan privasi.
- Hapus akun: profil dihapus (auth user dihapus), interaksi/analytics
  di-NULL user_id (agregat training tetap), dokumen verifikasi dihapus,
  review tetap sebagai konten (boleh dianonimkan identitasnya).

## 4. Akses & keamanan

- RLS semua tabel (`cp02-rls-storage.md`); anon hanya data publik terverifikasi.
- Bucket privat + signed URL ≤5 menit (FR-PRIV-03, NFR-SEC-04).
- Service role hanya di server (migration/training pipeline); tidak di app.
- Audit log aksi admin (FR-ADM-05).
- Data latih ML = ekspor server-side ber-credential environment; row mentah
  tidak masuk repo (`data/` git-ignored untuk raw export).

## 5. Hak pengguna (butir wajib di ToS/ringkasan privasi)

Akses (lihat data saya di settings/riwayat), koreksi (edit profil/preferensi),
penarikan consent interaksi, penghapusan akun, riwayat review yang pernah dibuat.
Permintaan ditangani via kontak yang dicantumkan di app (owner project).

## 6. Keputusan & residu risiko

| Keputusan | Alasan | Residu |
|---|---|---|
| Consent interaksi default ON + mudah ditarik | personalisasi = fungsi inti; transparan & dapat dikontrol | user menarik → data training lebih sedikit (dicatat sebagai keterbatasan) |
| Review UGC berlisensi via ToS | dasar legal ML-2 tanpa scraping | bergantung pada teks ToS v1.0 ditulis & ditampilkan (task CP-04A, R-017) |
| Retensi 24 bulan event | cukup untuk eksperimen Capstone | perlu penghapusan berkala (dijadwalkan bila melewati) |
| Identitas review dipublikasikan minimal | trust + privasi | tetap bisa dikenali dari gaya menulis (residu diterima, disebut di laporan) |
