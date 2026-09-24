# CP-03A — Entity Relationship Diagram

Date: 2026-09-25
Status: mengikat — sumber kolom detail = `cp02-schema-draft.md` + `cp02-data-dictionary.md`.
**Delta skema CP-03A: +1 tabel `model_params` (parameter serving rekomendasi,
ADR-005) → total 23 tabel** (dihitung ulang di REVIEW; migrasi tetap di CP-03B).
Extension: `postgis`. Legenda: `PK` primary key, `FK` foreign key, `U` unique,
`PU` partial unique, `CFK` composite FK.

---

## 1. Diagram relasi (23 tabel)

```text
auth.users
  │ 1:1 (trigger saat signup)
  ▼
profiles ──────┬───────────────────── owner_profiles (1:1, verification lifecycle)
(role: seeker|  │ 1:0..1 user_preferences (onboarding)
 owner|super_   │ 1:N favorites ────────────┐
 admin)         │ 1:N interactions          │
                │ 1:N tenancy_requests      │
                │ 1:N tenancies ────────────┤
                │    │ 1:1 payment_schedules│
                │    │ 1:N payment_records ─┼── 1:N reminders
                │    │ 1:N reviews (CFK:     │
                │    │  tenancy_id+property_id; U(tenancy_id, review_type))
                │    │        └─ 1:N review_aspect_scores (PK: review_id+aspect)
                │    └── UPU(room_id) active ─┐
                │ 1:N reports                 │
                │ 1:N recommendation_logs     │
                │ (actor) 1:N audit_logs      │
                │                             │
properties ─────┼── owner_id FK profiles ─────┘
  │             ├── 1:N property_images (U(property_id, path))
  │             ├── 1:N rooms ─── UPU(property_id, code)
  │             │      └── PU(room_id) 1 tenancy aktif
  │             ├── N:M property_facilities ── facilities (catalog)
  │             └── 1:N (target) reports / recommendation_logs
campuses        (master geospasial; FK dari user_preferences.primary_campus_id)
model_versions  (kind: recommender|review_nlp; 1:N model_params, 1:N
                 review_aspect_scores.model_version_id, 1:N recommendation_logs)
```

## 2. Tabel & kunci per domain

| Domain | Tabel | Kunci/invariant utama |
|---|---|---|
| Identity | `profiles` | PK=auth.users.id; role CHECK 3 nilai; tos wajib |
| | `owner_profiles` | PK user_id; verification_status default pending |
| Master | `campuses`, `facilities` | GIST(location) di campuses; slug U |
| Listing | `properties` | location geography NOT NULL; CHECK active→verified (trigger/app+RPC) |
| | `property_images` | U(property_id, storage_path) |
| | `rooms` | U(property_id, code); CHECK price/deposit ≥0; transisi status via trigger |
| | `property_facilities` | PK(property_id, facility_id) |
| Preference | `user_preferences` | PK user_id; CHECK budget_max ≥ budget_min |
| Discovery | `favorites` | PK(user_id, property_id) → idempotent save |
| | `interactions` | TANPA kolom lokasi user; index (user_id, occurred_at) |
| Tenancy | `tenancy_requests` | UPU(room_id, seeker_id) WHERE pending |
| | `tenancies` | **PU(room_id) WHERE status='active'**; U(id, property_id) sbg kunci CFK |
| Payment | `payment_schedules` | 1:1 tenancy (U tenancy_id) |
| | `payment_records` | U(tenancy_id, due_date); status computed overdue saat read |
| | `reminders` | UPU(payment_record_id, offset_days) WHERE scheduled |
| Feedback | `reviews` | **CFK (tenancy_id, property_id) → tenancies**; U(tenancy_id, review_type) |
| | `review_aspect_scores` | PK(review_id, aspect); source manual\|nlp |
| Trust | `reports` | target polymorphik (type+id) + reason_code |
| | `audit_logs` | INSERT hanya via SECURITY DEFINER; SELECT admin |
| ML | `model_versions` | reproducibility record (seed, dataset_version, metrics) |
| | `model_params` | 1:N model_versions — parameter serving (bobot) |
| | `recommendation_logs` | jejak feed (rank, score, reason_codes, model_version) |

## 3. Kenapa constraint ini (bukan app code saja)

| Invariant | Ditegakkan di | AC |
|---|---|---|
| 1 tenancy aktif per kamar (anti double-booking) | partial unique index | AC-TEN-01/02 |
| 1 request pending per room per seeker | partial unique index | AC-TEN-03 |
| Review wajib dari tenancy-nya & property sama | composite FK | AC-REV-01..03 |
| Harga/budget ≥ 0, budget_min ≤ budget_max | CHECK | AC-OWN-03, TP-PAY-01 |
| 1 review final per tenancy | unique(tenancy_id, review_type) | AC-REV-03 |
| Reason wajib saat reject | CHECK / NOT NULL pada RPC | AC-ADM-02 |
| Transisi room status valid | trigger (state machine) | AC-OWN-04 |
| listing aktif = verified | validasi di RPC update + trigger | AC-OWN-01/03 |

Catatan: RLS menentukan **siapa boleh**; constraint menentukan **kebenaran data
tidak peduli siapa yang menulis** — keduanya wajib (AGENTS §10.2).
