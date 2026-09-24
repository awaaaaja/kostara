# CP-02 — Low-Fidelity User Flows

Date: 2026-09-25
Catatan: lo-fi teks/ASCII — spesifikasi visual detail tetap di `DESIGN.md`
(§11–§32). Dipakai untuk traceability jalur kritis & navigasi role.

---

## 1. Navigasi utama per role (bottom nav V1)

```text
SEEKER/ TENANT          OWNER                 SUPER ADMIN
──────────────          ─────                 ───────────
Home (feed+rec)         Home (dashboard)      Overview
Explore (list/map)      Properties (list)     Verifikasi (owner+listing)
Saved                   Tenants/Requests      Reports & Reviews
Tenancy (kartu+bayar)   Payments              Master data
Profile/Settings        Profile               Model/interaksi summary
                        (role switch tidak ada — akun = 1 role)
```

## 2. Alur kritis end-to-end (PRD §27)

```text
[Register] → (ToS+consent) → [Onboarding preferensi] → [Home feed]
     │                                              │
     │                                              ├→ [Explore map/list] → filter
     │                                              │        └→ detail → save / compare
     │                                              └→ (rec fallback bila ML gagal)
     ▼
[Tenancy request] → status pending ──────────────┐
                                                 ▼
                        [Owner: terima] ── satu transaksi:
                          request accepted + tenancy active +
                          room occupied + 12 payment_records +
                          reminders terjadwal
                                                 │
[Tenant home: kartu tenancy + due date] ◄────────┘
     ├→ reminder lokal (7/3/1/0 hari, Asia/Jakarta)
     ├→ riwayat pembayaran (read-only)
     ▼ (tenancy ended oleh owner)
[Final review: 8 aspek + teks] → pending
     ▼
[Super admin approve] → tampil publik "Penghuni terverifikasi • Mon YYYY"
     ▼
[Owner: ringkasan aspek review di dashboard]  &  [NLP → aspect_scores (approved saja)]
```

## 3. Alur owner listing

```text
[Register role owner] → owner_profiles=pending
  → upload dokumen (bucket privat, signed URL saat dibaca)
  → [Admin verify] ─ rejected(+reason) → tampil alasan, boleh re-submit
                  └ verified
  → [Add property: pin peta] → status pending
  → [Add rooms: kode/tipe/harga/status]
  → [Admin verify listing] → verified + active → publik
  → [Maintenance: ubah availability] → last_availability_update_at ter-update
  → [Requests: terima/tolak(+reason)] → alur tenancy §2
  → [Payments: tandai paid] → status sama dgn tenant
```

## 4. Alur pencarian tanpa lokasi (permission denied)

```text
[Explore] → tekan "Near me" → pre-prompt → dialog sistem
  granted → nearby query (GPS sesaat, TIDAK disimpan)
  denied  → state tombol nonaktif + hint "Cari via kampus/area"
            → user pilih kampus (marker) / area manual / geser peta
            → SEMUA fitur (filter, detail, save, request) tetap jalan
```

## 5. Alur pengaturan privasi

```text
[Settings]
 ├─ Lihat status ToS & consent interaksi
 ├─ [Tarik consent] → konfirmasi → data_consent_at=NULL → event berhenti
 └─ [Ajukan hapus akun] → konfirmasi → (jika punya tenancy aktif →
      ditolak dengan pesan "selesaikan tenancy dulu") → proses penghapusan
      → profil & dokumen dihapus, interaksi dianonimkan
```

## 6. State wajib tiap layar data (DESIGN §33–35)

```text
loading (skeleton) → success → empty (dengan ajakan aksi)
                           └→ error (retry + pesan ramah, input tidak hilang)
offline: banner + cache terakhir (NFR-REL-04)
```
