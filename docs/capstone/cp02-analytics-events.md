# CP-02 — Analytics & Interaction Event Taxonomy

Date: 2026-09-25
Status: LOCKED — menyediakan data path untuk ML-1 (FR-ML-01) & RQ-1/RQ-2/RQ-4.
Mekanisme: client menulis ke tabel `interactions` (RLS insert own, bila
`data_consent_at IS NOT NULL`); batching ringan (buffer ≤10 event / 5 detik)
dengan flush saat app pause.

---

## 1. Skema event (kolom `interactions`)

```text
id, user_id, property_id?, event_type, event_weight?, source,
session_id?, occurred_at, metadata jsonb
```

- `source`: `feed | map | search | detail | saved | compare | deeplink`.
- `session_id`: UUID sesi app dibuka (bukan identitas).
- `metadata`: HANYA payload turunan (filter terpakai, rank, bbox viewport,
  campus_id) — **tanpa nama, phone, koordinat presisi** (NFR-PRIV-02).
- `event_weight`: menyusul dokumentasi §3; NULL = event non-skoring.

## 2. Kamus event (PRD §23 + definisi operasional)

| Event | Kapan dikirim (syarat tegas) | property_id | Weight | Metadata inti |
|---|---|---|---|---|
| `app_open` | cold/warm start sesi | — | — | session_id |
| `onboarding_complete` | preferensi tersimpan penuh | — | — | campus_id |
| `recommendation_impression` | kartu feed **terlihat ≥1 detik** dalam viewport | wajib | 0 | rank, model_version, reason_codes |
| `property_view` | detail terbuka, banner gambar utama ter-render | wajib | 1 | source, rank_awal |
| `property_save` | toggle save → sukses server | wajib | 3 | source |
| `property_unsave` | toggle unsave → sukses | wajib | — | — |
| `compare_add` | item masuk panel compare (maks 3) | wajib | 2 | slot |
| `map_search_area` | query viewport terkirim setelah debounce | opsional | — | bbox (4 double) |
| `near_me_search` | "Near me" dieksekui | opsional | — | `permission=granted\|denied`, radius_m — **tanpa koordinat** |
| `filter_apply` | filter diterapkan/berubah | — | — | filter_snapshot (hash/field) |
| `tenancy_request` | request sukses dibuat | wajib | 5 | room_id |
| `tenancy_accepted` | owner menerima → tenancy aktif | wajib | 8 | tenancy_id |
| `payment_due_view` | layar pembayaran/due dibuka | — | — | status_count |
| `review_submit` | review tersimpan (status pending) | wajib | — | review_type |

Aturan:

1. **Consent gate:** bila `data_consent_at IS NULL` → seluruh event tidak
   ditulis (AC-PRIV-03). `app_open` tetap boleh dicatat lokal untuk crash
   analytics? **Tidak** — V1 tanpa analytics eksternal; semua ke `interactions`.
2. Deduplikasi: `property_view` tidak dikirim >1× per property per session_id
   (dibuffer client-side).
3. Event P0 untuk training: impression, view, save, compare, request,
   tenancy (PRD §15.6 + weights §3).
4. Tidak ada event lokasi presisi, teks pencarian bebas (hanya hash/enum),
   atau data dari dokumen privat.
5. Privacy review wajib sebelum menambah event baru (PRD §23).

## 3. Interaction weights (design parameters — BUKAN ground truth)

| Event | Weight | Justifikasi awal (hipotesis) |
|---|---|---|
| impression | 0 | eksposur saja |
| view | 1 | minat lemah |
| save | 3 | shortlist |
| compare | 2 | pertimbangan aktif |
| tenancy_request | 5 | niat kuat |
| tenancy | 8 | konversi |
| unsave / skip | negatif opsional (−1) | didefinisikan saat eksperimen; default TIDAK dipakai dulu |

Angka = parameter desain (AGENTS §11.3), dicatat di model card, boleh
di-sweep dalam eksperimen; setiap perubahan = run log terpisah.

## 4. Pemakaian per konsumen

| Konsumen | Event yang dipakai |
|---|---|
| ML-1 training (implicit) | impression, view, save, compare, request, tenancy |
| RQ-4 / BI-1, BI-8 | impression, view, save → effort pencarian |
| BI-7 relevansi | impression vs save/request ratio per feed |
| Owner analytics (FR-OWN-07) | property_view, property_save, tenancy_request (aggregate per property owner sendiri) |
| Admin monitoring (FR-ADM-06) | count per event_type |

## 5. Retensi

24 bulan (data dictionary); saat penghapusan akun → `user_id` di-NULL
(agregat tetap dapat dipakai untuk training agregat) — AC-PRIV-02.
