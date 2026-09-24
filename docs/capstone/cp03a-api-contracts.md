# CP-03A — Prototype API / Inference Contracts

Date: 2026-09-25
Status: kontrak prototipe — detail signature bisa bergeser kecil saat implementasi
CP-03B, tetapi **semantik, guard, dan error behavior mengikat**. Client memanggil
hanya lewat repository (Supabase SDK: PostgREST + `rpc` + `functions`).

---

## 1. Konvensi

- **Pagination:** `{ page: int (1-based), page_size: ≤20 }` →
  `{ items: [...], page, has_more }`; ORDER stabal (`sort_key, id`).
- **Errors:** Postgres raise → SDK exception → repository map ke
  `AppFailure { network | auth | forbidden | notFound | validation | rateLimited | server }`
  — state error per layar (AGENTS §9.3), pesan tidak mengandung detail internal.
- **Timestamps:** timestamptz UTC; tampilan lokal Asia/Jakarta.
- **Money:** integer rupiah (tanpa desimal).
- **Konsistensi list↔map:** `search_properties` adalah SATU sumber utk list dan
  marker (AC-MAP-01).

## 2. RPC — Discovery

| RPC | Param | Return | Guard |
|---|---|---|---|
| `search_properties` | `filters jsonb, sort text ('relevansi'\|'harga'\|'jarak'), page int, page_size int, bbox numeric[4]?, near_lat?, near_lng?, near_radius_m?` | `items[] {id,name,price_from,cover_url,rating_avg,rating_count,distance_m,availability,gender_policy,facilities[],updated_at}` + paging | SECURITY INVOKER (RLS aktif; hanya listing verified+active utk non-owner) |
| `nearby_properties` | `lat, lng, radius_m (≤20000), filters jsonb, page` | sama dgn di atas | argumen GPS sesaat — fungsi TIDAK menyimpan lat/lng |
| `campus_suggestions` | `q text limit` | `{id,name,location_label}` | read campuses aktif |

Filter jsonb (allow-list): `price_min/max, gender, room_types[], facility_ids[],
rating_min, available_only, campus_id, max_distance_m, move_in_from, q`.

## 3. RPC — Recommendation (inference contract runtime)

```text
feed_recommendations(limit int default 12)
  → items[] { property_id, score (0–100 int), reason_codes[], display_name... }
  + (side-effect server) INSERT recommendation_logs (user, property,
      model_version aktif, rank, score, reason_codes, context)
```

Behavior:
1. Baca `model_versions` aktif (`kind='recommender', status='active'` — flag di
   row) → `model_params.params` (bobot + konfigurasi fitur).
2. Hard filter preferensi user (budget/gender/kampus radius/availability) →
   kandidat → skor deterministik 0–100 (bobot terparameterisasi).
3. Rantai cold-start mengikuti `cp02-ml-data-plan.md` A9 (user tanpa interaksi
   → preferensi+geo+verified; popularity hanya tie-breaker).
4. `reason_codes` ∈ kamus 6: `budget_fit, near_campus, facility_match,
   high_verified_rating, positive_aspects, trending` (FR-REC-02).
5. Tidak ada `model_params` aktif / error → raise `22023` atau return kosong
   **hanya jika benar-benar 0 listing**; client menangkap → fallback
   `search_properties(sort='popularity')` + log `baseline-fallback`
   (AC-REC-03). Feed tak-pernah-kosong bila ≥1 listing aktif (AC-REC-01).
6. **Skor = normalized match, bukan probability** — teks UI dilarang
   "kemungkinan/akurasi" (FR-REC-04/AC-REC-04).

### 3b. Kontrak training → serving (offline)

```text
Export (ENV service key, tidak di repo):
  events/users/items → data/raw/<dataset_version>/ + dataset card
Training (seed, split temporal 70/10/20, requirements terkunci):
  → metrics.json + model artifact
  → tulis model_versions (kind, name, artifact_uri, metrics, dataset_version,
     seed, commit) lalu model_params(model_version_id, params jsonb)
  → set status active bila gate cp02-A8 lulus; baseline tetap tersedia
App TIDAK pernah memuat artifact — hanya RPC membaca params.
Reproducibility: run ulang seed sama → metrik identik (NFR-ML-01).
```

## 4. RPC — Tenancy, Payment, Reminder

| RPC | Param | Guard (di dalam fungsi) | Efek |
|---|---|---|---|
| `submit_tenancy_request` | `property_id, room_id, message?` | auth; room visible+available; UPU 1 pending | insert request |
| `activate_tenancy` | `request_id` | `app_current_role()='owner'` + property.owner_id=auth.uid() | transaksi atomik (accept→tenancy active→room occupied→12 payment_records→regen reminders); idempotent |
| `end_tenancy` | `tenancy_id, end_date?` | pemilik tenancy | tenancy ended; room→available; (review final terbuka) |
| `mark_payment_paid` | `payment_record_id` | pemilik property atas tenancynya | paid + paid_at + marked_by |
| `regenerate_reminders` | `tenancy_id` | pemilik | cancel scheduled lama + insert sesuai offsets (utk) |

Reminder scheduling **device-side** dari `payment_schedules` (read →
`flutter_local_notifications` + tz Asia/Jakarta) — server tidak mengirim push di
V1 (ADR-006). Regen saat due/offsets berubah → client re-sync (AC-PAY-05).

## 5. RPC — Admin & audit

| RPC | Param | Guard | Efek |
|---|---|---|---|
| `admin_verify_owner` | `user_id, decision, reason?` | `app_is_admin()` | owner_profiles → verified/rejected (reason wajib saat reject) + audit_logs |
| `admin_verify_listing` | `property_id, decision, reason?` | idem | verification_status; rejected→tidak publik + audit |
| `admin_moderate_review` | `review_id, decision, reason?` | idem | status approved/rejected/hidden; **konten tidak diubah** + audit |
| `admin_resolve_report` | `report_id, status, note` | idem | resolve + audit |
| `admin_master_upsert` | `entity, payload` | idem | facilities/campus master + audit |

`audit_logs`: INSERT hanya dari fungsi definer (P7); SELECT admin (P4).

## 6. Peta client (repository → resource)

```text
AuthRepository        signIn/signUp(+tos,role)/signOut/sessionStream
PreferenceRepository  get/upsert user_preferences
SearchRepository      search(...) → RPC; suggestions
MapRepository         viewport search (bbox) / nearby
FavoriteRepository    add/remove/list (idempotent; U constraint)
CompareRepository     state lokal ≤3 + event compare_add
RecommendationRepo    getFeed() → RPC + fallback chain
TenancyRepository     submit/cancel; myTenancy; status stream (on-pull)
PaymentRepository     schedule, records (my), markPaid (owner)
ReminderService       scheduleFrom(schedule, offsets); cancelAllFor(tenancy)
ReviewRepository      eligibility; submit; listApproved(property)
OwnerRepository       dashboard summary; property/room CRUD; pin; requests
AdminRepository       queues; verify; moderate; master; model summary
EventRepository       track(event_type,...) → interactions (skip bila consent off)
StorageRepository     upload image (compress) ; signedUrl (private)
```

## 7. Kontrak event/analytics (PRD §23)

`interactions` INSERT dari app: `event_type ∈ taxonomy cp02-analytics`,
`event_weight` dihitung server-side saat read training (bukan dipercaya dari
client — kolom `event_weight` diisi default lalu recompute saat export);
`metadata jsonb` tanpa PII/koordinat; **diblokir bila `data_consent_at IS NULL`**
(AC-PRIV-03 — dicek app + policy).

## 8. Kontrak NLP batch (offline)

```text
input : SELECT reviews WHERE status='approved' AND id NOT IN (SELECT review_id
        FROM review_aspect_scores WHERE source='nlp')
output: INSERT review_aspect_scores (review_id, aspect, sentiment,
        confidence, source='nlp', model_version_id)  -- 8 aspek, hati-hati:
        hanya aspek yang DISEBUT (cp02 B4) → baris dibuat per aspek tsb
        + row model_versions (kind='review_nlp', metrics, dataset_version)
invariant: teks review invariabel (checksum before/after — AC-NLP-03);
        confidence < threshold → insufficient_evidence (AC-NLP-02);
        failure → tidak ada tulis parsial; fitur UI jadi structured-rating saja
```

## 9. Out of contract V1

Push/FCM, `notification_outbox`, travel-time/ETA, isochrone, payment gateway,
realtime subscription, pulse feedback — semua P1 (cp02-scope-lock); kontraknya
ditulis saat fiturnya di-authorized.
