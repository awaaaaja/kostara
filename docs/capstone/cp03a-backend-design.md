# CP-03A — Backend Design: RLS, Storage, PostGIS, Boundary

Date: 2026-09-25
Status: mengikat — pola & template SQL ini yang akan ditulis di migration CP-03B.
Matrix ekspektasi hasil per aktor = `cp02-rls-storage.md` (6 aktor × operasi);
test plan = `cp02-test-plan.md` TP-RLS-*, TP-STOR-*, TP-GIS-*.

---

## 1. RLS design

### 1.1 Prinsip

1. **RLS enabled di SEMUA tabel**, termasuk catalog publik (policy read publik
   yang eksplisit — bukan tanpa policy).
2. Tidak ada `USING (true)` untuk I/U/D pada tabel berdata user (AGENTS §4.3).
3. Eligibility/divergensi hak = **server-side predicate**, bukan hanya form.
4. Keamanan transaksi multi-baris = SECURITY DEFINER RPC dengan cek ownership
   **di dalam** fungsi (hindari TOCTOU) — bukan check-then-write dari klien.
5. Setiap tabel + policy lahir di migration yang sama; matrix wajib lulus
   sebelum gate terkait (cp02-rls-storage §3).

### 1.2 Helper anti-recursion (WAJIB — debt arsitektur, diperbaiki sekarang)

Policy `profiles` yang membaca `profiles` untuk menentukan role = recursive RLS.
Solusi: helper SECURITY DEFINER STABLE:

```sql
create or replace function public.app_current_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;
revoke all on function public.app_current_role() from public;
grant execute on function public.app_current_role() to authenticated;
```

Pola serupa `app_is_admin()` → `app_current_role() = 'super_admin'`.
Helper **tidak pernah** membaca tabel lain (mencegah rantai rekursi).

### 1.3 Katalog pola policy

| ID | Pola | SQL template (pola) | Pemakai |
|---|---|---|---|
| P1 | Own-row | `using (owner_id = auth.uid())` | properties (U), favorites, user_preferences, reports, interactions |
| P2 | Visibility publik | `using (verification_status='verified' and listing_status='active')` | properties/rooms (S anon/seeker-other/owner-other) |
| P3 | Participation | `exists (select 1 from tenancies t where t.id=<fk> and t.seeker_id=auth.uid())` (via helper definer bila perlu) | payment_*, reminders, reviews (S/I) |
| P4 | Role gate | `using (public.app_is_admin())` | audit_logs (S), model_versions (S/I), moderasi (U) |
| P5 | Catalog read | `using (is_active)` untuk anon+authenticated; I/U/D role gate | campuses, facilities |
| P6 | Owner-scoped entity | `exists (select 1 from properties p where p.id=property_id and p.owner_id=auth.uid())` | property_images, property_facilities, tenancy_requests (owner side) |
| P7 | Definer-only write | tanpa INSERT policy (klien); insert via fungsi SECURITY DEFINER | audit_logs, review_aspect_scores (nlp), recommendation_logs boleh-I dgn cek consent |

Contoh konkret (properties — dua policy SELECT yang ditumpuk, Supabase OR-kan):

```sql
alter table public.properties enable row level security;

create policy "properties_select_public" on public.properties for select
  using (verification_status = 'verified' and listing_status = 'active');

create policy "properties_select_own" on public.properties for select
  using (owner_id = auth.uid());

create policy "properties_mutate_own" on public.properties
  for insert with check (owner_id = auth.uid());

create policy "properties_update_own" on public.properties for update
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
-- delete: TIDAK ada policy utk owner (archived saja) → hanya super_admin via RPC
```

Tabel `profiles`: SELECT terbatas kolom display tidak bisa diekspresikan di
policy (policy = per tabel/command, bukan per kolom) → **design: view
`profiles_public`** (id, full_name display, avatar_url, role) untuk konsumsi
app; SELECT base table hanya milik sendiri + admin. Phone/PII tidak pernah
keluar lewat view.

### 1.4 Peta tabel → pola (ringkas; matrix lengkap di cp02)

| Tabel | SELECT | INSERT/UPDATE/DELETE |
|---|---|---|
| profiles | P1 own + view public | U own (kolom tertentu), admin U status via RPC |
| owner_profiles | P1 (user_id=auth.uid) + admin S | U own (submit docs), admin via RPC |
| properties, rooms, property_images, property_facilities | P1+P2+P6 | owner own (create/update; delete = archive), admin via RPC |
| user_preferences, favorites, interactions | P1 own | I/U/D own (interactions I only, consent dicek app+policy data_consent_at) |
| tenancy_requests | seeker: own; owner: P6 propertynya | seeker I own + D pending own; owner U via RPC |
| tenancies, payment_schedules, payment_records, reminders | P3 participation (seeker tenancynya) / owner property | U & mutasi = RPC (P7); owner D reminder only |
| reviews | P2 approved (publik) + P3 own (semua status miliknya) | I P3+eligibility (trigger CHECK ended); **U/D konten: tidak ada policy** (moderasi = admin RPC ubah status saja) |
| review_aspect_scores | join review approved (P2/P3) | I hanya pipeline (P7) |
| reports | own S/I | admin U resolve (P4) |
| model_versions, model_params, audit_logs | P4 (S) | P7 (I via definer/pipeline) |
| recommendation_logs | own S + admin S | I dari app saat feed (dgn user sendiri) |
| campuses, facilities | P5 | P4 |

### 1.5 RPC vs Edge vs klien (boundary rule)

| Kebutuhan | Tempat | Alasan |
|---|---|---|
| CRUD biasa, single-row, sudah dijamin constraint | **klien + RLS** | sederhana, audit via policy |
| Multi-row transaksi / invariant (accept request, activate/end tenancy, mark paid, regenerate reminders) | **RPC SECURITY DEFINER** | atomicity + cek ownership dalam satu transaksi |
| Query spasial + agregasi feed/ranking | **RPC (SECURITY INVOKER)** | server-side computation (AGENTS §10.5); tetap ter-RLS |
| Aksi privileged admin + audit | **RPC SECURITY DEFINER** (role check dlm fn) | audit_logs tidak bisa ditulis klien |
| Logika butuh SECRET (push P1, webhook) | **Edge Function** (reserved) | secret tidak boleh di klien — V1 nihil pemakaian |
| Training/NLP/export dataset | **script offline + service key di ENV** | key tidak di repo & tidak di app |

## 2. Storage design

4 bucket (detail di `cp02-rls-storage.md` §Storage): `avatars` (public-read),
`property-images` (public-read terkondisi), `verification-documents-private`,
`payment-proofs-private` (dibuat bersama P1 — bucket dibuat saat fitur P1, jangan
dibuat kosong di V1).

Template policy (bucket private; folder = entitas pemilik):

```sql
create policy "doc_owner_insert" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'verification-documents-private'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (select 1 from public.owner_profiles o
                where o.user_id = auth.uid()) );

create policy "doc_owner_admin_select" on storage.objects for select
  using (
    bucket_id = 'verification-documents-private'
    and ( (storage.foldername(name))[1] = auth.uid()::text
          or public.app_is_admin() ) );
```

Aturan: (a) folder-name saja tidak cukup — selalu EXISTS ke tabel pemilik
(property milik `auth.uid()`, dst.); (b) file tanpa segmen uuid pertama →
ditolak; (c) baca privat V1 = signed URL ≤5 menit dari app setelah cek hak
(FR-PRIV-03); (d) upload property-images hanya utk property miliknya (P6).

## 3. PostGIS / spatial query design

### 3.1 Storage

- `properties.location`, `campuses.location`: `geography(Point,4326)` NOT NULL;
  index `USING gist (location)`.
- SRID 4326 WGS84; `geography` → jarak meter akurat di permukaan bumi.

### 3.2 Template query (semua lewat RPC, indeks GIST)

```sql
-- bbox / "search this area" (axis-aligned envelope)
where p.location && ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
-- (operator && utk geography bekerja via bbox internal; fallback bounding box dgn ST_Intersects(geom::box2d))

-- radius / near me (argumen GPS sesaat, tidak disimpan)
where ST_DWithin(p.location,
        ST_SetSRID(ST_MakePoint($lng, $lat), 4326)::geography, $radius_m)

-- jarak utk ditampilkan (m)
select ST_Distance(p.location, c.location)::int as distance_m
```

GABUNGAN filter hard + spasial dalam SATU query RPC (`search_properties`) —
jangan split ke klien. Sort: `relevansi` (skor ringan: harga-fit + jarak),
`harga`, `jarak` — selalu dengan `id` sebagai tie-breaker stabal + `limit 20`.

### 3.3 Performa & perilaku

- Debounce 300 ms setelah gesture berhenti + tombol "Search this area" eksplisit
  (FR-MAP-02; AC-MAP-02 menverifikasi 1 query per jeda).
- `EXPLAIN ANALYZE` wajib menunjukkan **index scan GIST** pada 1000 fixture
  (TP-GIS-03) — bukti indeks terpakai, bukan sekadar ada.
- Clustering marker >100/viewport dilakukan client-side atas hasil query
  viewport (NFR-PERF-04) — clustering server (ST_ClusterDBSCAN) dicatat sebagai
  upgrade bila payload >500 row.
- Tidak ada perhitungan jarak massal di device; device hanya menampilkan
  `distance_m` yang dihitung server.

## 4. Transisi status yang ditegakkan DB

```sql
-- room state machine (trigger; cegah occupied→available tanpa perantaraan)
create or replace function public.rooms_transitions() returns trigger ...
  allowed: available→{reserved,maintenance,inactive}
           reserved→{occupied,available}
           occupied→{available,maintenance}   -- available via end_tenancy
           maintenance→{available,inactive}; self-transition → raise
-- last_availability_update_at di-set di trigger yang sama (AC-OWN-05 ±0 detik)

-- CHECK listing aktif = verified: dijaga di RPC publish_listing + trigger guard
-- reminders anti-duplikat: partial unique (payment_record_id, offset_days) WHERE scheduled
```

Transaksi `activate_tenancy` = 1 function, 1 transaksi: cek pemilik request →
request accepted → insert tenancy (assert partial unique lolos) → room
occupied → 12 payment_records → reminders → return tenancy_id. Gagal di mana
saja = rollback penuh (AC-TEN-01) + idempotent pada panggilan ulang (AC-TEN-02).

## 5. Keamanan ringkas (pre-gate CP-03B)

- Anon key app; service_role hanya ENV server/CI secret.
- `assertNoServiceRole()` tetap (CP-00) — scan APK di TP-SEC-01.
- Fungsi definer: `search_path` di-set eksplisit; `revoke ... from public`;
  parameter tidak pernah masuk string dinamis (statement plpgsql dibangun via
  `format()` hanya dengan allow-list kolom sort — anti SQL injection).
- Secret scan setiap REVIEW gate.
