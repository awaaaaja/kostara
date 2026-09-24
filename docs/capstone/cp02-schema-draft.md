# CP-02 — Logical Schema Draft (v0)

Date: 2026-09-25
Status: DRAFT mengikat — implementasi nyata via **versioned migration di CP-03B/CP-04A**
(file: `supabase/migrations/<timestamp>_*.sql`). Dokumen ini adalah kontrak
struktural: tabel, kolom inti, constraint, index, hubungan.
Field lengkap + semantik = `cp02-data-dictionary.md`.

Extension: `postgis`.

---

## 1. Identity & master

```text
profiles (
  id uuid PK REFERENCES auth.users(id) ON DELETE CASCADE,
  role text CHECK (role IN ('seeker','owner','super_admin')) NOT NULL,
  full_name text NOT NULL, avatar_url text, phone text,
  status text CHECK (status IN ('active','suspended')) NOT NULL DEFAULT 'active',
  tos_version text NOT NULL, tos_accepted_at timestamptz NOT NULL,
  data_consent_at timestamptz,            -- NULL = consent ditarik/tidak aktif
  created_at/updated_at timestamptz NOT NULL DEFAULT now()
)
-- INSERT by trigger saat signup (auth), bukan oleh client langsung.

owner_profiles (
  user_id uuid PK REFERENCES profiles(id) ON DELETE CASCADE,
  verification_status text CHECK (...) NOT NULL DEFAULT 'pending',
  doc_path text, submitted_at timestamptz, reviewed_at timestamptz,
  reviewer_id uuid REFERENCES profiles(id), reject_reason text
)

campuses ( id uuid PK/uuid, name text NOT NULL, address text,
  location geography(Point,4326) NOT NULL, is_active bool NOT NULL DEFAULT true )
  + GIST(location)

facilities ( id uuid PK, slug text UNIQUE NOT NULL, name text NOT NULL,
  category text, is_active bool NOT NULL DEFAULT true )
```

## 2. Listing

```text
properties (
  id uuid PK,
  owner_id uuid NOT NULL REFERENCES profiles(id),
  name text NOT NULL CHECK (length(name) BETWEEN 3 AND 120),
  description text, address text NOT NULL,
  location geography(Point,4326) NOT NULL,
  gender_policy text CHECK (gender_policy IN ('male_only','female_only','any')) NOT NULL,
  verification_status text CHECK (...) NOT NULL DEFAULT 'pending',
  listing_status text CHECK (...) NOT NULL DEFAULT 'draft',   -- draft|active|archived
  rules text,
  last_availability_update_at timestamptz NOT NULL DEFAULT now(),
  created_at/updated_at timestamptz NOT NULL DEFAULT now()
) + GIST(location)
CHECK: listing_status='active' → verification_status='verified'  -- via trigger/validasi app+RPC

property_images ( id uuid PK,
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  storage_path text NOT NULL, sort_order int NOT NULL DEFAULT 0,
  is_cover bool NOT NULL DEFAULT false, created_at timestamptz,
  UNIQUE(property_id, storage_path) )

rooms ( id uuid PK,
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  code text NOT NULL, room_type text CHECK (IN ('single','shared','studio')),
  price int NOT NULL CHECK (price >= 0),
  deposit int NOT NULL DEFAULT 0 CHECK (deposit >= 0),
  status text CHECK (IN ('available','reserved','occupied','maintenance','inactive'))
    NOT NULL DEFAULT 'available',
  size_sqm numeric CHECK (size_sqm > 0), availability_date date,
  created_at/updated_at timestamptz,
  UNIQUE(property_id, code) )

property_facilities ( property_id FK CASCADE, facility_id FK,
  PRIMARY KEY (property_id, facility_id) )
```

Transisi status room (divalidasi app + bisa diperkuat trigger di migration):
`available → {reserved, maintenance, inactive}`,
`reserved → {occupied, available}`,
`occupied → {available (tenancy ended), maintenance}`,
`maintenance → {available, inactive}`; self-transition tidak diizinkan.

## 3. Preference & discovery state

```text
user_preferences (
  user_id uuid PK REFERENCES profiles(id) ON DELETE CASCADE,
  primary_campus_id uuid REFERENCES campuses(id),
  budget_min int NOT NULL CHECK (budget_min >= 0),
  budget_max int NOT NULL CHECK (budget_max >= budget_min),
  gender_preference text CHECK (...),
  transport_mode text CHECK (...),
  max_distance_m int CHECK (max_distance_m > 0),
  max_travel_minutes int CHECK (max_travel_minutes > 0),
  move_in_date date, facility_priority uuid[],
  updated_at timestamptz NOT NULL DEFAULT now()
) + GIN(facility_priority)

favorites ( user_id FK, property_id FK,
  created_at timestamptz, PRIMARY KEY (user_id, property_id) )

interactions ( id uuid PK,
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  event_type text NOT NULL CHECK (event_type IN (...taxonomy cp02-analytics...)),
  event_weight numeric, source text NOT NULL,
  session_id text, occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}' )
  + INDEX (user_id, occurred_at), INDEX (property_id, event_type)
-- TIDAK ADA kolom koordinat user (NFR-PRIV-01).
```

## 4. Tenancy & payment

```text
tenancy_requests ( id uuid PK,
  property_id uuid NOT NULL REFERENCES properties(id),
  room_id uuid NOT NULL REFERENCES rooms(id),
  seeker_id uuid NOT NULL REFERENCES profiles(id),
  status text CHECK (IN ('pending','accepted','rejected','cancelled')) DEFAULT 'pending',
  message text, decided_at timestamptz, decided_by uuid,
  reject_reason text, created_at timestamptz,
  CHECK (status<>'rejected' OR reject_reason IS NOT NULL) )
  + UNIQUE partial (room_id, seeker_id) WHERE status='pending'

tenancies ( id uuid PK,
  property_id uuid NOT NULL REFERENCES properties(id),
  room_id uuid NOT NULL REFERENCES rooms(id),
  seeker_id uuid NOT NULL REFERENCES profiles(id),
  owner_id uuid NOT NULL REFERENCES profiles(id),
  start_date date NOT NULL, end_date date,
  billing_cycle text NOT NULL DEFAULT 'monthly' CHECK (billing_cycle='monthly'),
  amount int NOT NULL CHECK (amount > 0),
  due_day smallint NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  status text CHECK (IN ('active','ended','cancelled')) NOT NULL DEFAULT 'active',
  ended_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_date IS NULL OR end_date >= start_date),
  UNIQUE (id, property_id)                     -- kunci utk composite FK reviews
)
  + UNIQUE partial (room_id) WHERE status='active'   -- 1 tenancy aktif per kamar
  + INDEX (seeker_id, status), INDEX (owner_id, status)

payment_schedules ( id uuid PK,
  tenancy_id uuid NOT NULL UNIQUE REFERENCES tenancies(id) ON DELETE CASCADE,
  next_due_date date NOT NULL, amount int NOT NULL CHECK (amount > 0),
  reminder_offsets int[] NOT NULL DEFAULT '{7,3,1,0}',
  timezone text NOT NULL DEFAULT 'Asia/Jakarta',
  updated_at timestamptz NOT NULL DEFAULT now() )

payment_records ( id uuid PK,
  tenancy_id uuid NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  due_date date NOT NULL, amount int NOT NULL CHECK (amount > 0),
  status text CHECK (IN ('unpaid','paid','overdue')) NOT NULL DEFAULT 'unpaid',
  paid_at timestamptz, marked_by uuid REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenancy_id, due_date) )

reminders ( id uuid PK,
  tenancy_id uuid NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  payment_record_id uuid REFERENCES payment_records(id) ON DELETE CASCADE,
  fire_at timestamptz NOT NULL, offset_days int NOT NULL CHECK (offset_days BETWEEN 0 AND 30),
  status text CHECK (IN ('scheduled','fired','cancelled')) NOT NULL DEFAULT 'scheduled',
  local_notification_id text, created_at timestamptz NOT NULL DEFAULT now() )
  + UNIQUE (payment_record_id, offset_days) WHERE status='scheduled'  -- anti-duplikat
```

Aturan pembuatan: `payment_records` = 12 baris ke depan saat tenancy
diaktifkan (via RPC `activate_tenancy`); `overdue` dihitung saat read
(`now() > due_date AND status='unpaid'`) — tanpa cron di V1.
Reminder diregenerasi (cancel lama + insert baru) setiap perubahan
`reminder_offsets`/`due_date` (FR-PAY-03).

## 5. Feedback & ML

```text
reviews ( id uuid PK,
  tenancy_id uuid NOT NULL REFERENCES tenancies(id),
  property_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES profiles(id),
  review_type text CHECK (IN ('final','pulse')) NOT NULL DEFAULT 'final',
  rating_overall smallint NOT NULL CHECK (rating_overall BETWEEN 1 AND 5),
  review_text text CHECK (length(review_text) <= 1000),
  status text CHECK (IN ('pending','approved','rejected','hidden')) DEFAULT 'pending',
  moderated_by uuid, moderation_reason text,
  created_at/updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenancy_id, review_type),
  FOREIGN KEY (tenancy_id, property_id)
    REFERENCES tenancies(id, property_id) ON DELETE RESTRICT
  -- ↑ property wajib sama dengan property pada tenancy (PRD §15.7)
)
-- Eligibility RLS: EXISTS tenancy milik auth.uid() tsb + status tenancy='ended'
-- untuk review_type='final'.

review_aspect_scores (
  review_id uuid REFERENCES reviews(id) ON DELETE CASCADE,
  aspect text CHECK (IN ('cleanliness','security','internet','water','comfort',
                         'access','owner','value')),
  sentiment text CHECK (IN ('positive','negative','neutral','insufficient_evidence')),
  confidence numeric CHECK (confidence BETWEEN 0 AND 1),
  source text CHECK (IN ('manual','nlp')) NOT NULL,
  model_version_id uuid REFERENCES model_versions(id),
  PRIMARY KEY (review_id, aspect) )

reports ( id uuid PK, reporter_id uuid REFERENCES profiles(id),
  target_type text CHECK (IN ('property','review','user')) NOT NULL,
  target_id uuid NOT NULL, reason_code text NOT NULL, detail text,
  status text CHECK (IN ('open','resolved','rejected')) DEFAULT 'open',
  resolved_by uuid, resolved_at timestamptz, resolution_note text,
  created_at timestamptz DEFAULT now() )

model_versions ( id uuid PK,
  kind text CHECK (IN ('recommender','review_nlp')) NOT NULL,
  name text NOT NULL, artifact_uri text NOT NULL,
  metrics jsonb, dataset_version text NOT NULL, seed int,
  created_at timestamptz DEFAULT now() )

recommendation_logs ( id uuid PK,
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  model_version_id uuid REFERENCES model_versions(id),
  rank int NOT NULL, score numeric NOT NULL,
  reason_codes text[] NOT NULL DEFAULT '{}',
  context jsonb, requested_at timestamptz DEFAULT now() )
  + INDEX (user_id, requested_at)

audit_logs ( id uuid PK,
  actor_id uuid, actor_role text NOT NULL,
  action text NOT NULL, target_type text, target_id uuid,
  detail jsonb, created_at timestamptz DEFAULT now() )
-- RLS: SELECT super_admin saja; INSERT via security-definer function aksi admin.
```

## 6. RPC yang direncanakan (contract awal CP-03A)

| Fungsi | Tujuan | Catatan |
|---|---|---|
| `search_properties(bounds/filters/radius, limit, offset)` | pencarian server-side + join fasilitas/rating | ST_DWithin / && operator, GIST |
| `nearby_properties(lat, lng, radius_m, filters)` | near me | argumen GPS sesaat, tidak disimpan |
| `activate_tenancy(request_id)` | accept atomik: request→accepted, tenancy insert, room→occupied, 12 payment_records, reminders | SECURITY DEFINER; cek pemilik property |
| `end_tenancy(tenancy_id)` | ended + room→available | cek pemilik |
| `mark_payment_paid(payment_record_id)` | paid + paid_at + marked_by | cek pemilik tenancy |
| `regenerate_reminders(tenancy_id)` | cancel + insert sesuai offsets | dipanggil saat schedule berubah |
| `audit_log_write(...)` | insert audit_logs dari aksi admin | security definer |

## 7. Index ruang & performa

- `properties`: GIST(location); btree (owner_id), (listing_status, verification_status).
- `rooms`: btree (property_id, status).
- `interactions`: (user_id, occurred_at), (property_id, event_type).
- `tenancies`: (seeker_id), (owner_id), partial unique aktif per room.
- Pagination selalu `ORDER BY` kunci stabil + `limit/offset` (NFR-PERF-01).

## 8. Yang TIDAK ada di V1 (penting)

- Tabel lokasi user / riwayat GPS — tidak ada, tidak dibuat.
- `notification_outbox` — P1.
- Payment gateway tables — di luar scope (PRD §3.2).
- Realtime channel — hanya jika CP-03A memutuskan ada kebutuhan nyata.
