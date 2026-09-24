# CP-02 — Data Dictionary v0

Date: 2026-09-25 (draft pertama; diperbarui CP-03B saat migration dibuat)
Tipe memakai konvensi PostgreSQL. Mata uang **IDR (integer)**.
`PII` = data pribadi. Kolom identitas bersifat minimal.

| Tabel | Entitas | Kolom kunci (tipe) | PII | Pemilik data | Retensi / catatan |
|---|---|---|---|---|---|
| profiles | akun pengguna | id uuid PK→auth.users · role enum(seeker,owner,super_admin) · full_name text · avatar_url text · phone text? · status enum(active,suspended) · tos_version text · tos_accepted_at timestamptz · data_consent_at timestamptz? · created_at/updated_at | ya (nama, phone) | user sendiri; admin | selama akun; hapus/anonimkan saat account deletion |
| owner_profiles | verifikasi pemilik | user_id PK→profiles · verification_status enum(pending,verified,rejected,suspended) · doc_path text · submitted_at · reviewed_at · reviewer_id? · reject_reason text? | dokumen = sensitif | owner; super_admin | dokumen dihapus bila akun owner dihapus |
| campuses | master kampus | id · name · address · location geography(Point,4326) · is_active bool | tidak | super_admin | permanen (master) |
| properties | listing kos | id · owner_id→profiles · name · description · address · location geography(Point,4326) · gender_policy enum(male_only,female_only,any) · verification_status enum(pending,verified,rejected,suspended) · listing_status enum(draft,active,archived) · rules text? · last_availability_update_at timestamptz · created_at/updated_at | tidak | owner | archived >2 tahun boleh dibersihkan |
| property_images | foto listing | id · property_id→properties(CASCADE) · storage_path text · sort_order int · is_cover bool | tidak | owner | ikut property; path di bucket `property-images` |
| rooms | kamar | id · property_id→properties(CASCADE) · code text · room_type enum(single,shared,studio) · price int (≥0) · deposit int (≥0, default 0) · status enum(available,reserved,occupied,maintenance,inactive) · size_sqm numeric? · availability_date date? · created_at/updated_at | tidak | owner | ikut property |
| facilities | master fasilitas | id · slug unique · name · category · is_active bool | tidak | super_admin | permanen |
| property_facilities | relasi property↔facility | property_id · facility_id · PK(keduanya) | tidak | owner | ikut property |
| user_preferences | preferensi seeker | user_id PK→profiles · primary_campus_id? →campuses · budget_min int (≥0) · budget_max int (≥ budget_min) · gender_preference enum · transport_mode enum(walk,bike,motorcycle,public_transport) · max_distance_m int? · max_travel_minutes int? · move_in_date date? · facility_priority uuid[] · updated_at | semi (preferensi) | user sendiri | selama akun; ikut withdrawal consent |
| favorites | simpanan | user_id · property_id · created_at · PK(user_id,property_id) | tidak | user sendiri | selama akun |
| interactions | event perilaku | id · user_id? (SET NULL saat anonymisasi) · property_id? · event_type enum · event_weight numeric? · source text · session_id text? · occurred_at timestamptz · metadata jsonb | semi (perilaku) | sistem; di-list hanya utk user sendiri | 24 bulan; saat hapus akun → user_id di-NULL (data agregat tetap utk training) |
| tenancy_requests | pengajuan sewa | id · property_id · room_id · seeker_id · status enum(pending,accepted,rejected,cancelled) · message text? · decided_at? · decided_by? · reject_reason? · created_at | ya (identitas pemohon terkait tenancy) | seeker + owner property tsb | ikut tenancy lifecycle; ≥2 tahun |
| tenancies | hubungan sewa | id · property_id · room_id · seeker_id · owner_id · start_date date · end_date date? · billing_cycle enum(monthly) · amount int (>0) · due_day smallint (1..31) · status enum(active,ended,cancelled) · ended_at? · created_at | ya | tenant + owner property; admin | ≥2 tahun setelah ended (riwayat pembayaran) |
| payment_schedules | jadwal tagihan | id · tenancy_id UNIQUE · next_due_date date · amount int · reminder_offsets int[] default {7,3,1,0} · timezone text default 'Asia/Jakarta' · updated_at | tidak | tenant + owner | ikut tenancy |
| payment_records | tagihan per periode | id · tenancy_id · due_date date · amount int · status enum(unpaid,paid,overdue) · paid_at timestamptz? · marked_by uuid? · UNIQUE(tenancy_id,due_date) | tidak (nilai sewa termasuk data keuangan ringan) | tenant + owner property | ikut tenancy |
| reminders | jadwal local notif | id · tenancy_id · payment_record_id? · fire_at timestamptz · offset_days int · status enum(scheduled,fired,cancelled) · local_notification_id text? · created_at | tidak | tenant | regenerate saat schedule berubah; dibersihkan setelah fired >30 hari |
| reviews | feedback | id · tenancy_id · user_id · property_id · review_type enum(final,pulse) · rating_overall smallint (1..5) · review_text text? (≤1000) · status enum(pending,approved,rejected,hidden) · moderated_by? · moderation_reason? · created_at/updated_at · UNIQUE(tenancy_id,review_type) | teks bisa berisi PII sukarela → panduan menulis tanpa data pribadi | reviewer (konten); publik baca approved | permanen selama platform; hide bukan hapus |
| review_aspect_scores | skor aspek per review | review_id · aspect enum(cleanliness,security,internet,water,comfort,access,owner,value) · sentiment enum(positive,negative,neutral,insufficient_evidence) · confidence numeric? · source enum(manual,nlp) · model_version_id? · PK(review_id,aspect) | tidak | sistem | ikut review |
| reports | laporan pengguna | id · reporter_id · target_type enum(property,review,user) · target_id uuid · reason_code · detail text? · status enum(open,resolved,rejected) · resolved_by? · resolved_at? · resolution_note? | ya (pelapor) | pelapor; admin | ≥2 tahun |
| model_versions | registry model | id · kind enum(recommender,review_nlp) · name · artifact_uri · metrics jsonb · dataset_version text · seed int · created_at | tidak | riset | permanen (reproducibility) |
| recommendation_logs | feed yang disajikan | id · user_id · property_id · model_version_id · rank int · score numeric · reason_codes text[] · context jsonb? · requested_at | semi (perilaku) | sistem | 24 bulan; ikut anonymisasi akun |
| audit_logs | jejak aksi admin | id · actor_id · actor_role · action text · target_type · target_id · detail jsonb · created_at | ya (jejak admin) | platform | 24 bulan; INSERT hanya via jalur aksi admin |
| notification_outbox | (P1) | — | — | — | dibuat bersama fitur push P1 |

## Konvensi global

- Semua timestamp `timestamptz`, default `now()`.
- Enum ditambahkan via migration versioned (tidak ada ALTER diam-diam).
- `event_weight` = design parameter (AGENTS §11.3: impression 0, view 1,
  save 3, compare 2, request 5, tenancy 8) — **bukan ground truth**; perubahan
  dicatat di experiment log.
- Koordinat user **tidak pernah** menjadi kolom tabel mana pun.
