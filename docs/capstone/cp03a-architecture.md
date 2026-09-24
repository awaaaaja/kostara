# CP-03A — System Architecture, Module Boundaries & Data Flow

Date: 2026-09-25
Status: mengikat (di-ADR-002..006); implementasi = CP-03B/CP-04.
Input: `cp02-*` (schema, RLS, geospatial, ML plan), PRD §18, DESIGN.md.

---

## 1. Architecture diagram (V1)

```text
┌──────────────────────────── Flutter app (mobile) ────────────────────────────┐
│  presentation   screens/widgets · Riverpod providers (loading/success/       │
│                 empty/error/offline) · go_router + role guards               │
│  domain-lite    filter parsing · form validation · fallback ranking decision │
│  data           repositories per feature ── Supabase client (anon key)      │
│  services       geolocator (JIT) · local notifications (tz) · image cache    │
└───────────────┬──────────────────────────────────────────────┬───────────────┘
                │ PostgREST (RLS enforced) + RPC + Storage     │ HTTPS
                │ (service_role TIDAK PERNAH masuk sini)       │
┌───────────────▼───────────────────────────────┐  ┌───────────▼──────────────┐
│ Supabase                                        │  │ ML offline (services/ml │
│  PostgreSQL + PostGIS                           │  │  atau experiments/)     │
│   · 22 tabel (cp02-schema-draft) + RLS penuh    │  │  · export dataset (env  │
│   · SECURITY DEFINER RPC (invariant/transaksi)  │  │    key, bukan repo)     │
│   · helper app_current_role() anti-recursion    │  │  · train/evaluate       │
│   · GIST(loc) · partial unique · composite FK   │  │    (seed, split temporal│
│  Storage 4 bucket (public/private + policy)     │  │  · tulis model_versions │
│  Auth (email+password, trigger → profiles)      │  │    + model_params)      │
│  (Edge Function: DIRESERVE utk P1 push/webhook) │  │  · NLP batch → aspect   │
└─────────────────────────────────────────────────┘  │    _scores              │
                                                     └─────────────────────────┘
```

Aturan keras yang terwujud di diagram:
1. **service_role hanya di server/lingkungan training** (AGENTS §4.8) — app memakai
   anon key; `AppConfig.assertNoServiceRole()` mempertahankan guard CP-00.
2. **App tidak tahu model.** App hanya memanggil `feed_recommendations` / membaca
   kolom hasil — training & serving terpisah (ADR-005).
3. **Tidak ada service hosting di V1** (tanpa FastAPI, tanpa Edge Function wajib) —
   fit 16 minggu; jalur diupgrade via gate CP-04B tanpa mengubah app contract.

## 2. Module boundaries (Flutter)

Mengikuti PRD §18 + AGENTS §9 (feature-first; jangan folder global raksasa):

```text
lib/
  core/
    config/        app_config.dart (existing)
    theme/         warna/typography/spacing dari DESIGN §4-7
    router/        go_router + redirect guards + shell per role
    widgets/       komponen lintas fitur (skeleton, error_view, empty_view,
                   price_text, verified_badge) — hanya yang benar-benar dipakai ≥2 fitur
    utils/         debounce, formatters (rupiah, tanggal, jarak)
  features/
    auth/          data (repo, models) · application (notifiers) · presentation
    onboarding/    wizard preferensi seeker + status owner pending
    discovery/     search/filter, explore map, property detail, saved, compare
    recommendation/ feed repo (RPC feed + fallback), reason codes, logging
    tenancy/       request, tenant home, payment schedule/records, reminders
    review/        form final review, list publik, eligibility state
    owner/         dashboard, property/room CRUD, pin lokasi, requests, payments
    admin/         overview, verifikasi, moderasi, master data, model summary
    settings/      profile, consent/privacy, notification prefs
```

Kontrak antar-feature (dipaksa agar batas tetap jelas):
- `discovery` tidak meng-import `owner`/`admin`;
- `recommendation` dipanggil hanya dari `discovery`/home (provider publik);
- model data lintas fitur (mis. `Property`, `Room`, `Tenancy`) didefinisikan di
  fitur pemiliknya dan dire-export; tidak ada `lib/models/` global;
- repository = satu-satunya tempat memanggil Supabase; screen tidak pernah
  memanggil `supabase.from(...)` langsung.

## 3. Data-flow — Discovery (list & map)

```text
User ubah filter / gesture map selesai (debounce 300 ms, NNFR-PERF-07)
  → DiscoveryFilterNotifier (state filter terpisah dari MapState, sinkron — AGENTS §9.6)
  → SearchRepository.search(filters, sort, page, bbox?)
      └→ RPC search_properties(jsonb filters, sort, page, bbox, near?)   [SECURITY INVOKER]
           ├→ hard filter (harga/gender/status/availability/fasilitas)
           ├→ PostGIS: bbox → location && ST_MakeEnvelope(...); radius → ST_DWithin (GIST)
           ├→ join rating verified + fasilitas + harga min
           └→ ORDER BY stabal + LIMIT 20 (NNFR-PERF-01)
  → hasil = data utk list DAN marker (jumlah identik AC-MAP-01)
  → interaction event (impression) → insert interactions (bila consent aktif)
```

- "Near me": koordinat dari geolocator → argumen RPC → **dibuang** (tidak ada
  kolom lokasi user; FR-PRIV-01/AC-LOC-02).
- Gagal RPC/offline → state error + banner offline + cache terakhir (AC-OFF-01);
  bukan kosongkan layar.

## 4. Data-flow — Recommendation feed

```text
[Training offline, berkala / saat ada data cukup]        [Runtime — app]
 export events/users/items (service key di ENV)           Home dibuka
  → split temporal + seed → train baseline A/B / hybrid    → RecommendationRepository.getFeed(limit)
  → evaluate (NDCG/P@K/…, nyata saja)                              └→ RPC feed_recommendations(limit)
  → tulis model_versions (metrics, dataset_version, seed)              ├→ baca model_params utk active_version
  → tulis model_params (bobot/fitur; JSON)                             ├→ hard filter preferensi user
  → (kandidat hybrid hanya bila gate cp02 A8 lulus)                    ├→ skor 0–100 deterministik
                                                                       │    rantai sinyal cold-start
                                                                       │    (cp02 A9: preferensi → CB
                                                                       │     → geo → verified → populer)
                                                                       ├→ reason_codes per item
                                                                       └→ insert recommendation_logs
  ← model_versions = sumber "model terpilih"; app tidak tahu isi model
```

Failure handling (FR-REC-03/AC-REC-03):
1. RPC error/timeout/`model_params` kosong → client panggil
   `search_properties(sort='popularity')` sebagai ranking fallback;
2. log fallback dengan `model_version='baseline-fallback'`;
3. UI tampilkan feed biasa (tanpa klaim personalisasi bila fallback aktif —
   DESIGN §35 "ML unavailable");
4. feed **tidak pernah kosong** selama ada ≥1 listing aktif.

## 5. Data-flow — Tenancy → payment → reminder

```text
Seeker: FR-TEN-01  insert tenancy_requests (RLS: property visible + 1 pending/room)
Owner : FR-OWN-05  RPC activate_tenancy(request_id)     [SECURITY DEFINER]
          transaksi tunggal: request=accepted → tenancies(active) → room=occupied
                             → 12 payment_records → reminders dijadwalkan
          idempotent (guard status) → AC-TEN-01/02
Owner : mark_payment_paid(id)  → paid + paid_at + marked_by (cek ownership dlm fungsi)
Client : schedule local notifications dari payment_schedules.reminder_offsets
          (Asia/Jakarta; regenerasi = cancel + insert, AC-PAY-05)
Tenant : tenancy home membaca tenancy miliknya (RLS participation) → kartu + due date
Overdue : dihitung saat read (now > due_date & unpaid) — tanpa cron (V1)
```

Enforceable di DB: partial unique `tenancies(room_id) WHERE active`; unique
partial pending request; composite FK `reviews(tenancy_id, property_id)`;
trigger transisi status room (§backend-design).

## 6. Data-flow — Review → moderasi → NLP

```text
Tenant (tenancy ended): INSERT reviews (RLS eligibility server-side) → status=pending
Super admin: approve → status=approved (reject wajib reason; konten tak diedit)
NLP batch (offline, service key ENV):
  SELECT reviews WHERE status='approved' AND belum punya aspect_scores
   → pipeline (lexicon → TF-IDF+linear bila label cukup) 
   → confidence < threshold → insufficient_evidence (AC-NLP-02)
   → INSERT review_aspect_scores (source='nlp', model_version_id) + model_versions row
   → teks review TIDAK disentuh (AC-NLP-03)
Publik: reviews approved saja; identitas = "Penghuni terverifikasi • Mon YYYY"
Fallback: pipeline gagal → app tetap tampil rating struktural saja (AGENTS §11.7)
```

## 7. Data-flow — Moderasi & audit

```text
Aksi privileged (verify owner/listing, moderasi review/report, ubah master data)
  → RPC SECURITY DEFINER w/ app_current_role()='super_admin'
  → perubahan state + INSERT audit_logs (actor, action, target, detail, ts) dalam satu transaksi
audit_logs: RLS SELECT super_admin saja; INSERT hanya via fungsi (tidak bisa dipalsukan klien)
```

## 8. Fit 16 minggu (sprint mapping)

| Sprint | Memakai arsitektur ini untuk | Infra yang TIDAK dibangun (sengaja) |
|---|---|---|
| CP-03B (w5-6) | migration v1 + RLS baseline + RPC discovery/tenancy + Explore Map slice + baseline ML script | Edge Function, push, FastAPI |
| CP-04A (w7-8) | fitur seeker lengkap, owner lifecycle, payment/reminder, review+moderasi, storage policies, ToS v1.0 | isochrone, pulse, bukti bayar |
| CP-04B (w9-10) | hybrid experiment + gate model + integrasi params + NLP baseline | transformer (gate data) |
| CP-05A/B (w11+) | polish, uji (RLS matrix, GIS, a11y), capstone evidence | semua P1/P2 |

Bukti tidak-berlebihan (REVIEW "no unnecessary infra"): 0 Edge Function dipakai V1;
0 service hosting; 0 paket state-management tambahan di luar Riverpod; Realtime
Supabase tidak dipakai (status dibaca on-pull — cukup untuk siklus V1).

## 9. Non-goals arsitektur (tegas)

- Bukan microservice; bukan event-sourcing; bukan offline-first penuh (hanya cache
  last-viewed + preserve input).
- Tidak ada background location service / geofence / riwayat GPS (AC-LOC-01).
- Tidak ada chat, payment gateway, dynamic pricing (PRD §3.2).
