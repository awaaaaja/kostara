# CP-02 — RLS Matrix Draft & Storage Policy Plan

Date: 2026-09-25
Status: DRAFT mengikat untuk migration CP-03B/CP-04A.
Wajib: RLS **enabled** pada semua tabel di `cp02-schema-draft.md`
(kecuali tabel yang memang public-catalog milik platform tetap punya policy
read publik — tetap enable RLS). Test matrix = `cp02-test-plan.md` TP-RLS-*.

Legenda operasi: **S**elect, **I**nsert, **U**pdate, **D**elete.
`—` = ditolak (0 row / error). `p` = publik (anon termasuk).

---

## 1. Aktor

| Aktor | Definisi |
|---|---|
| anon | tanpa sesi (Supabase: `auth.uid() IS NULL`) |
| seeker-own | `auth.uid()` = pemilik baris, role seeker |
| seeker-other | role seeker, bukan pemilik baris |
| owner-own | role owner atas property/barnya sendiri |
| owner-other | role owner atas data owner lain |
| super_admin | role `super_admin` pada profiles |

## 2. Matrix per tabel

| Tabel | anon | seeker-own | seeker-other | owner-own | owner-other | super_admin |
|---|---|---|---|---|---|---|
| profiles | — | S,U profil sendiri* | S profil publik terbatas† | S,U profil sendiri† | S† | S,U (status user) |
| owner_profiles | — | S milik sendiri (sbagai owner) | — | S milik sendiri | — | S,U (verifikasi) |
| campuses | S (is_active) | S | S | S | S | S,I,U,D |
| properties | S **hanya** verified+active | S,U milik sendiri (semua status) | S verified+active | S,I,U milik sendiri | S verified+active | S,U (verifikasi) |
| property_images | S bila property visible | S,U path miliknya | S bila property visible | S,I,U,D utk propertynya | S bila visible | S,U |
| rooms | S bila property visible | S milik property sendiri | S bila property visible | S,I,U,D milik sendiri | S bila visible | S |
| facilities | S (is_active) | S | S | S | S | S,I,U,D |
| property_facilities | S bila property visible | — | S bila visible | I,D utk propertynya | S bila visible | S,I,D |
| user_preferences | — | S,I,U | — | — | — | S |
| favorites | — | S,I,D | — | — | — | S |
| interactions | — | S (baris sendiri), I (sesuai consent) | — | — | — | S |
| tenancy_requests | — | S,I,D milik sendiri (cancel) | — | S,U (terima/tolak) utk propertynya | — | S |
| tenancies | — | S milik sendiri | — | S,U (end/extend) utk propertynya | — | S |
| payment_schedules | — | S milik tenancy sendiri | — | S,U utk tenancynya | — | S |
| payment_records | — | S milik tenancy sendiri | — | S,U (mark paid) utk tenancynya | — | S |
| reminders | — | S milik tenancy sendiri | — | S utk tenancynya | — | S,U (cancel) |
| reviews | S **hanya approved** | S semua status miliknya; I bila eligible (final+ended) | S hanya approved | S approved; **U,D ditolak selamanya** | S approved | S, U status (moderasi) |
| review_aspect_scores | S bila review approved | S bila review miliknya | S bila approved | S bila approved | S | S,I (pipeline)‡ |
| reports | — | S,I milik sendiri | — | — | — | S,U (resolve) |
| model_versions | — | — | — | — | — | S,I |
| recommendation_logs | — | S baris sendiri, I (dari app saat feed) | — | — | — | S |
| audit_logs | — | — | — | — | — | S; I hanya via function |

\* profiles: kolom sensitif (phone) tidak ikut select milik orang lain.
† select publik terbatas ke kolom display (full_name, avatar_url, role).
‡ pipeline NLP memakai service role **di server** (edge/runner), bukan client.

## 3. Aturan keras (non-negotiable)

1. **Tidak ada policy `USING (true)`** untuk INSERT/UPDATE/DELETE di tabel
   ber-data user (AGENTS §4.3).
2. Reviews: **owner TIDAK PERNAH** punya UPDATE/DELETE atas konten review
   (VALIDATION_PROTOCOL §22); moderasi hanya mengubah `status` oleh super_admin.
3. Eligibility review ditegakkan **server-side** (predicate RLS + CHECK +
   composite FK), bukan hanya form client.
4. `activate_tenancy`/`mark_payment_paid` = SECURITY DEFINER dengan cek
   ownership di dalam fungsi (menghindari TOCTOU antara check client & write).
5. Service role key: hanya untuk proses server (migration, pipeline training,
   ML export) — **tidak pernah** di Flutter (FR-AUTH-05).
6. Setiap policy baru = bagian migration yang sama dengan tabelnya;
   test matrix wajib lulus sebelum gate terkait PASS.

## 4. Kebutuhan uji minimal (dirinci di test plan)

Untuk tabel kritis `profiles, properties, rooms, favorites, tenancy_requests,
tenancies, payment_records, reviews, audit_logs`:

```text
anon / seeker-own / seeker-other / owner-own / owner-other / super_admin
× SELECT INSERT UPDATE DELETE  →  hasil sesuai matrix di §2
```

---

# Storage Policy Plan

Buckets (PRD §17):

| Bucket | Visibility | Path convention | Writer | Reader |
|---|---|---|---|---|
| `avatars` | public-read | `{user_id}/{filename}` | pemilik user_id tsb (authenticated) | semua (CDN/publik) |
| `property-images` | public-read **dengan policy** | `{property_id}/{filename}` | owner property tsb | anon/semua **hanya bila** property verified+active; selain itu owner property tsb |
| `verification-documents-private` | **private** | `{user_id}/{filename}` | pemilik (owner upload dokumen verifikasi) | pemilik sendiri + super_admin (signed URL) |
| `payment-proofs-private` | **private** (dibuat bersama fitur P1) | `{tenancy_id}/{filename}` | tenant/owner terkait tenancy | pihak tenancy + super_admin |

Aturan:

1. Policy `storage.objects` ditulis per bucket, memakai
   `storage.foldername(name)[1]` sebagai pemilik/entitas.
2. Kepemilikan diverifikasi lewat EXISTS ke tabel terkait
   (`properties.owner_id = auth.uid()`, dst.) — folder-name saja tidak cukup.
3. Akses privat V1 = **signed URL** dengan expiry pendek (≤5 menit) dihasilkan
   oleh app setelah cek hak akses (FR-PRIV-03). `createSignedUrl` dari SDK.
4. Upload gambar property mewajibkan pemilik terverifikasi **atau** dalam mode
   draft miliknya; foto tidak tampil publik sebelum listing verified (diproteksi
   policy read §2 + status property).
5. Anomali: file tanpa folder valid (tanpa uuid pada segmen pertama) → ditolak
   policy (WAL pola `check`).
6. Uji: TP-STOR-01 (anon akses privat → 403/400), TP-STOR-02 (owner lain
   tulis/hapus → ditolak), TP-STOR-03 (owner tulis property sendiri → sukses).

Retention: dokumen verifikasi dihapus saat akun owner dihapus; foto ikut
cascade property; semua operasi hapus objek mencatat audit bila terkait
aksi admin.
