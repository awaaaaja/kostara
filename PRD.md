# PRD — KOSTARA

**Document type:** Product Requirements Document  
**Status:** Baseline V1 untuk Capstone  
**Primary platform:** Flutter mobile  
**Backend:** Supabase  
**Database:** PostgreSQL + PostGIS  
**ML service:** Python/FastAPI atau service setara yang dapat direproduksi dan diintegrasikan  
**Initial market:** Mahasiswa/pencari kos dan pemilik kos, pilot awal Kota Padang  
**Capstone track:** PIF683 Proyek dalam Kecerdasan Buatan

---

# 1. Executive Summary

KOSTARA adalah aplikasi mobile untuk pencarian, rekomendasi, eksplorasi, dan manajemen kos yang mempertahankan lifecycle pengguna dari fase **pencari kos** sampai menjadi **verified tenant**.

Aplikasi menggabungkan:

1. personalized kos recommendation berbasis Machine Learning;
2. geospatial search dan Explore Map;
3. preferensi pengguna dan kampus/tujuan utama;
4. listing dan room management untuk pemilik kos;
5. tenancy dan pengingat pembayaran;
6. verified resident feedback;
7. analisis feedback penghuni berbasis NLP;
8. dashboard operational intelligence untuk pemilik;
9. verifikasi dan moderasi oleh Super Admin.

KOSTARA tidak diposisikan sebagai aplikasi "cari kos terdekat" semata. Produk harus membantu user menemukan kos yang **cocok**, bukan hanya yang paling dekat.

---

# 2. Problem Statement

## 2.1 Masalah pencari kos

Pencari kos, khususnya mahasiswa, harus menggabungkan banyak pertimbangan secara manual:

- budget;
- jarak atau waktu tempuh ke kampus;
- fasilitas;
- tipe kos;
- jenis penghuni yang diterima;
- ketersediaan kamar;
- aturan;
- kondisi lingkungan;
- kualitas internet;
- keamanan;
- pengalaman penghuni sebelumnya.

Marketplace listing biasa cenderung memaksa user membaca dan membandingkan banyak listing tanpa personalisasi yang memadai.

## 2.2 Masalah setelah user mendapat kos

Aplikasi pencarian kos biasa kehilangan relevansi setelah transaksi terjadi. Padahal lifecycle penghuni masih panjang:

- jatuh tempo sewa;
- riwayat pembayaran;
- status kamar;
- komunikasi kebutuhan tenancy;
- pengalaman tinggal;
- feedback berkala;
- perpanjangan atau pindah kos.

## 2.3 Masalah pemilik kos

Pemilik membutuhkan satu tempat untuk:

- mengelola kos dan kamar;
- memperbarui harga dan availability;
- mengelola tenant;
- melihat payment status;
- memahami feedback;
- mengetahui aspek yang harus diperbaiki;
- melihat performa listing.

## 2.4 Masalah kualitas informasi

Review anonim tanpa bukti tenancy mudah dimanipulasi. KOSTARA harus mengutamakan **verified tenant feedback**.

---

# 3. Product Goals

## 3.1 Primary goals

1. Mengurangi waktu dan usaha user dalam menemukan kos yang relevan.
2. Memberikan rekomendasi yang personal dan dapat dijelaskan.
3. Menggabungkan proximity, campus context, fasilitas, harga, availability, dan feedback.
4. Mempertahankan utility setelah user menjadi penghuni.
5. Memberikan operational value kepada pemilik kos.
6. Membuat interaction dataset yang dapat digunakan untuk meningkatkan model recommendation.
7. Menghasilkan artefak Capstone AI yang dapat dijalankan, diuji, dan dipertanggungjawabkan.

## 3.2 Non-goals V1

V1 tidak bertujuan untuk:

- menjadi payment gateway penuh;
- menjalankan background location tracking;
- melakukan dynamic pricing otomatis;
- membuat kredit scoring;
- membuat face recognition;
- membuat chat real-time sebagai core;
- membuat marketplace nasional pada fase Capstone;
- menjamin travel time tanpa routing provider;
- mengklaim skor recommendation sebagai probabilitas keberhasilan.

---

# 4. Stakeholders

## 4.1 Primary stakeholders

### Seeker / Tenant
Mahasiswa atau pengguna lain yang mencari dan kemudian menghuni kos.

### Owner
Pemilik atau pengelola kos.

### Super Admin
Operator platform yang melakukan verifikasi, moderasi, konfigurasi master data, dan monitoring.

## 4.2 Capstone stakeholders

Tim harus mendapatkan stakeholder nyata untuk CP-01, minimal:

- 3-5 pencari/penghuni kos untuk exploratory interview;
- 2-3 pemilik/pengelola kos;
- 1 stakeholder validator yang bersedia memberikan feedback terhadap prototype.

Jumlah ini adalah baseline operasional project, bukan pengganti arahan dosen/pembimbing mengenai jumlah partisipan.

---

# 5. User Roles

## 5.1 Authentication roles

- `super_admin`
- `owner`
- `seeker`

**Tenant bukan role autentikasi terpisah.** Tenant adalah state/lifecycle dari `seeker` yang memiliki tenancy aktif atau historis.

## 5.2 Role transitions

`seeker` → `verified_tenant` melalui record tenancy yang valid.

Owner harus melewati proses verifikasi sebelum listing dapat berstatus publik jika rule platform mengharuskannya.

---

# 6. Primary User Journeys

## 6.1 Seeker onboarding

1. Register/login.
2. Pilih role seeker.
3. Isi profil dasar.
4. Pilih kampus/tujuan utama.
5. Set rentang budget.
6. Pilih preferensi tipe kos.
7. Pilih fasilitas prioritas.
8. Pilih transport mode.
9. Pilih maksimum waktu/jarak yang diterima.
10. Pilih move-in target.
11. Selesai onboarding.
12. Sistem membuat preference profile.
13. User melihat recommendation feed dan Explore Map.

## 6.2 Explore and shortlist

1. User membuka Explore.
2. Aplikasi meminta permission lokasi bila user memilih "Near me".
3. Map menampilkan property markers.
4. User menggeser map lalu menekan "Search this area".
5. User menggunakan filter.
6. User membuka property detail.
7. User menyimpan atau compare.
8. Interaksi dicatat sebagai training/evaluation event sesuai kebijakan privasi.

## 6.3 Request tenancy

1. User memilih room/property.
2. User mengirim request.
3. Owner menerima atau menolak.
4. Bila diterima, tenancy dibuat.
5. User menjadi verified tenant pada property tersebut.
6. Payment schedule diaktifkan.
7. Reminder dikonfigurasi.

## 6.4 Tenant lifecycle

1. Lihat tenancy aktif.
2. Lihat due date.
3. Atur reminder.
4. Lihat payment history.
5. Berikan pulse feedback setelah minimum eligibility.
6. Berikan final review setelah tenancy selesai.
7. Perpanjang atau tutup tenancy.
8. Jika pindah, user kembali ke discovery flow dengan history preference yang dapat digunakan.

## 6.5 Owner listing lifecycle

1. Owner register.
2. Verification.
3. Add property.
4. Pick location on map.
5. Add room types/rooms.
6. Add price, photos, facilities, rules.
7. Submit listing for verification bila diperlukan.
8. Publish.
9. Maintain availability.
10. Receive requests.
11. Activate tenancy.
12. Track payments.
13. Review feedback analytics.

---

# 7. Functional Requirements

## 7.1 Authentication and Profile

### FR-AUTH-01
User dapat register menggunakan mekanisme auth yang disetujui project.

### FR-AUTH-02
User harus memiliki role valid.

### FR-AUTH-03
Session harus dipulihkan secara aman ketika aplikasi dibuka ulang.

### FR-AUTH-04
User dapat logout dari seluruh sesi yang relevan.

### FR-AUTH-05
Secret, service role key, dan privileged token tidak boleh dibundel pada mobile app.

---

# 8. Seeker Features

## 8.1 Home

Home harus menampilkan:

- personalized recommendation;
- continue exploring;
- saved properties;
- nearby from primary campus;
- active tenancy card jika ada.

## 8.2 Search and Filter

Filter minimum:

- rentang harga;
- tipe kos;
- gender policy;
- availability;
- fasilitas;
- tipe kamar;
- rating minimum;
- radius/jarak;
- campus;
- move-in availability.

## 8.3 Explore Map

Explore Map harus:

- menampilkan property marker;
- mendukung current location dengan izin;
- menampilkan campus marker;
- mendukung "Search this area";
- menampilkan quick card/bottom sheet saat marker dipilih;
- sinkron dengan filter;
- tidak melakukan background tracking.

## 8.4 Campus-aware search

User dapat:

- memilih primary campus;
- mengganti campus;
- melihat kos dekat campus;
- memfilter berdasarkan jarak;
- melihat travel time hanya bila routing provider valid tersedia.

## 8.5 Saved

User dapat:

- favorite/unfavorite;
- melihat saved properties;
- mendapatkan status availability terbaru saat membuka ulang.

## 8.6 Compare

User dapat membandingkan maksimal 3 listing V1 berdasarkan:

- harga;
- jarak;
- travel time jika tersedia;
- availability;
- fasilitas;
- verified rating;
- review aspects;
- recommendation score.

Compare tidak perlu disimpan server jika tidak dibutuhkan untuk lifecycle.

---

# 9. Owner Features

## 9.1 Owner verification

Status:

- pending;
- verified;
- rejected;
- suspended.

## 9.2 Property management

Owner dapat:

- add/edit/archive property;
- menentukan nama dan deskripsi;
- set geo point;
- set address;
- set rules;
- set gender policy;
- upload cover dan gallery;
- set facilities;
- set room types;
- set rooms;
- set price;
- set deposit bila ada;
- set availability.

## 9.3 Room management

Room status minimum:

- available;
- reserved;
- occupied;
- maintenance;
- inactive.

## 9.4 Tenant management

Owner dapat:

- menerima/menolak request;
- membuat tenancy;
- melihat active tenant;
- mengakhiri tenancy;
- memperpanjang tenancy.

## 9.5 Payment management

V1 adalah **payment record and reminder system**, bukan full payment processor.

Owner dapat:

- menentukan payment schedule sesuai tenancy;
- mencatat status paid/unpaid;
- melihat due soon;
- melihat overdue;
- mengonfirmasi bukti bila flow ini dipilih tim.

## 9.6 Owner analytics

Minimum:

- total property/rooms;
- occupancy;
- available rooms;
- active tenants;
- payment status;
- listing views;
- saves;
- request count;
- average verified rating;
- aspect summary dari review.

---

# 10. Super Admin Features

Super Admin dapat:

- view platform overview;
- manage user status;
- verify owner;
- verify/moderate listing;
- moderate reports;
- moderate reviews;
- manage facility master;
- manage campus master;
- view interaction/model monitoring summary;
- view audit-sensitive actions;
- suspend malicious accounts/listings;
- manage feature flags yang aman.

Admin tidak boleh mengedit data model atau hasil evaluasi untuk "memperbagus" metrik.

---

# 11. Tenancy and Payment Reminder

## 11.1 Tenancy

Tenancy minimum fields:

- property;
- room;
- seeker;
- owner;
- start date;
- end date optional;
- billing cycle;
- amount;
- due day/date;
- status.

## 11.2 Reminder

User dapat memilih:

- 7 hari sebelum;
- 3 hari sebelum;
- 1 hari sebelum;
- hari H;
- custom offset.

Server schedule dan local device schedule harus konsisten.

Jika due date diubah oleh tenancy agreement, reminder harus diregenerasi.

---

# 12. Verified Feedback System

## 12.1 Eligibility

Review hanya dapat dilakukan bila:

- user memiliki tenancy valid pada property;
- tenure memenuhi minimum eligibility yang ditetapkan;
- review terkait property yang benar;
- user belum melebihi batas review yang diizinkan untuk periode tersebut.

## 12.2 Feedback types

- pulse feedback selama tenancy;
- final review setelah tenancy selesai.

## 12.3 Structured aspects

V1:

- kebersihan;
- keamanan;
- internet;
- air;
- kenyamanan;
- akses;
- pemilik/pengelola;
- value for money.

## 12.4 Free-text review

Free-text review dapat dianalisis NLP, namun:

- data pribadi harus diminimalkan;
- toxic/unsafe content moderation dapat ditambahkan sebagai rule-based P1;
- review analysis tidak mengubah isi asli review;
- summary harus dapat dilacak ke review sumber secara agregat.

---

# 13. Machine Learning Requirements

# 13.1 ML-1 Hybrid Recommendation System

## Objective

Menghasilkan Top-N listing yang relevan untuk user berdasarkan:

- explicit preferences;
- property features;
- spatial features;
- availability;
- verified rating;
- review aspect features;
- interaction history.

## Candidate features

### User features
- budget min/max;
- campus;
- gender preference;
- desired room type;
- facility priorities;
- transport mode;
- max distance/travel preference;
- move-in target;
- interaction history.

### Property features
- price;
- facilities;
- room type;
- gender policy;
- availability;
- geo distance;
- travel time if valid;
- verified rating;
- aspect sentiment scores;
- owner verification;
- property category.

### Interaction events
- impression;
- view;
- save;
- unsave;
- compare;
- contact/request;
- skip;
- tenancy;
- review.

## Baseline models

### Baseline A
Popularity/filtered popularity.

### Baseline B
Content-based similarity.

## Candidate hybrid

- LightFM with user/item metadata; or
- collaborative filtering + content score fusion; or
- learning-to-rank model if dataset memadai.

Pemilihan final harus berdasarkan eksperimen, bukan preferensi teknologi.

## Cold start strategy

Untuk user baru:

1. onboarding preference;
2. content-based ranking;
3. campus/location relevance;
4. verified quality signals;
5. popularity digunakan hanya sebagai tie-breaker atau fallback.

Untuk property baru:

1. metadata;
2. geo;
3. price/facilities;
4. verified status;
5. tidak boleh didiskriminasi hanya karena belum memiliki interaksi.

## Evaluation

Minimum:

- Precision@K;
- Recall@K;
- NDCG@K;
- Hit Rate;
- coverage;
- cold-start evaluation;
- qualitative stakeholder/user evaluation.

Train-validation-test harus dirancang untuk menghindari leakage. Untuk interaction sequence, temporal split lebih tepat dibanding random split jika dataset mendukung.

## Explainability

Aplikasi harus mampu memberi alasan non-menyesatkan seperti:

- sesuai budget;
- dekat kampus;
- fasilitas prioritas cocok;
- rating verified tinggi;
- aspek keamanan mendapat feedback positif.

Jika UI menampilkan `92% Match`, angka tersebut harus didefinisikan sebagai **normalized matching score**, bukan probability.

---

# 13.2 ML-2 Aspect-Based Review Analysis

## Objective

Mengubah review text menjadi sinyal terstruktur per aspek.

Contoh:

`"Kamarnya bersih, aman, tapi WiFi malam lambat."`

Expected:

- cleanliness: positive;
- security: positive;
- internet: negative.

## Target aspects V1

- cleanliness;
- security;
- internet;
- water;
- comfort;
- access;
- owner;
- value.

## Baseline

- aspect keyword/rule extraction + sentiment baseline; atau
- TF-IDF + linear classifier bila label memadai.

## Candidate

Model transformer Bahasa Indonesia bila:

- dataset legal;
- label memadai;
- biaya training/inference feasible.

## Evaluation

- Macro F1;
- per-class precision;
- per-class recall;
- confusion matrix;
- error analysis.

## Guardrails

- jangan mengarang sentiment ketika confidence rendah;
- sediakan `insufficient evidence`;
- jangan menyimpulkan fakta objektif hanya dari opini;
- summary harus menggunakan agregat verified review.

---

# 14. GIS and Location Requirements

## 14.1 Storage

Gunakan PostGIS dan `geography(Point, 4326)` atau representasi geospatial setara yang didukung arsitektur.

## 14.2 Spatial functions

Minimum:

- nearby properties;
- distance from campus;
- distance from current location;
- bounding-box/map viewport search;
- spatial index.

## 14.3 Live/current location

- permission diminta saat dibutuhkan;
- tidak aktif terus menerus;
- tidak menyimpan location history secara default;
- user dapat mencari tanpa memberi precise location dengan menggunakan campus/manual area.

## 14.4 Travel time

Travel time hanya boleh ditampilkan bila:

- ada routing engine/provider;
- response valid;
- attribution dan terms dipenuhi.

Fallback:

`distance only`

Jangan pernah menampilkan ETA yang dibuat-buat.

## 14.5 Isochrone

Isochrone adalah P1, bukan blocker V1.

---

# 15. Data Model Baseline

Tabel minimum:

```text
profiles
owner_profiles
campuses
properties
property_images
rooms
facilities
property_facilities
user_preferences
favorites
interactions
tenancy_requests
tenancies
payment_schedules
payment_records
reminders
reviews
review_aspect_scores
reports
model_versions
recommendation_logs
notification_outbox
audit_logs
```

## 15.1 profiles

```text
id uuid PK -> auth.users.id
role enum
full_name
avatar_url
phone optional
status
created_at
updated_at
```

## 15.2 campuses

```text
id
name
address
location geography(Point,4326)
is_active
```

## 15.3 properties

```text
id
owner_id
name
description
address
location geography(Point,4326)
gender_policy
verification_status
listing_status
created_at
updated_at
```

## 15.4 rooms

```text
id
property_id
code/name
room_type
price
deposit optional
status
size optional
availability_date optional
```

## 15.5 user_preferences

```text
user_id
primary_campus_id
budget_min
budget_max
gender_preference
transport_mode
max_distance_m optional
max_travel_minutes optional
move_in_date optional
updated_at
```

Facility priorities sebaiknya dinormalisasi agar dapat di-query.

## 15.6 interactions

```text
id
user_id
property_id
event_type
event_weight optional
source
session_id optional
occurred_at
metadata jsonb
```

`event_weight` tidak boleh dianggap ground truth tanpa dokumentasi.

## 15.7 reviews

```text
id
tenancy_id
user_id
property_id
review_type
rating_overall
review_text
status
created_at
updated_at
```

Constraint wajib memastikan user/tenancy/property konsisten.

---

# 16. RLS and Security Principles

RLS wajib aktif pada tabel yang memuat data user atau data operasional sensitif.

## Seeker

Boleh:

- read listing public/verified;
- read data publik yang aman;
- read/write preference milik sendiri;
- read/write favorite milik sendiri;
- read tenancy milik sendiri;
- read payment milik sendiri;
- membuat review hanya bila eligible.

## Owner

Boleh:

- manage property miliknya;
- manage room miliknya;
- read tenancy yang terkait property miliknya;
- manage payment record yang terkait tenancy miliknya;
- tidak boleh membaca tenancy property owner lain.

## Super Admin

Akses privileged harus melalui mekanisme admin yang dapat diaudit.

## Rules

- jangan gunakan service role key di Flutter;
- jangan disable RLS untuk "memperbaiki error";
- migrations harus versioned;
- secrets di environment/server;
- audit action penting;
- storage bucket policy harus mengikuti ownership.

---

# 17. Storage

Supabase Storage bucket baseline:

```text
avatars
property-images
verification-documents-private
payment-proofs-private
```

`verification-documents-private` dan `payment-proofs-private` harus private dengan signed access sesuai kebutuhan.

---

# 18. Flutter Architecture

Recommended:

```text
lib/
  app/
  core/
    config/
    errors/
    theme/
    routing/
    utils/
  features/
    auth/
    onboarding/
    discovery/
    map/
    recommendation/
    property/
    favorites/
    compare/
    tenancy/
    payments/
    reviews/
    owner/
    admin/
    profile/
  data/
    models/
    repositories/
    services/
```

Recommended packages/principles:

- Riverpod untuk state management;
- go_router untuk routing;
- freezed/json_serializable bila tim konsisten;
- Supabase Flutter SDK;
- flutter_map atau MapLibre-compatible approach;
- flutter_local_notifications;
- geolocator;
- timezone-aware scheduling;
- image caching.

Package final harus dipilih pada CP-03 dan dikunci setelah review.

---

# 19. Backend Architecture

```text
Flutter App
    |
    +--> Supabase Auth
    +--> Supabase Postgres + PostGIS
    +--> Supabase Storage
    +--> Supabase Realtime where justified
    +--> Edge Functions for trusted server operations
    |
    +--> ML Inference API
             |
             +--> Recommender
             +--> Review NLP
```

ML service tidak boleh menerima raw data lebih banyak dari yang dibutuhkan.

---

# 20. Notifications

Minimum:

- payment due;
- tenancy request status;
- owner verification status;
- listing verification status;
- review eligibility.

Reminder payment dapat menggunakan:

- local scheduled notification untuk personal reminders;
- server-triggered push untuk status lintas device bila diimplementasikan.

Notification tidak boleh menjadi spam. User harus bisa mengatur preference.

---

# 21. Non-Functional Requirements

## Performance

Target awal:

- cold launch reasonable untuk device menengah;
- list memakai pagination;
- map marker clustering jika data padat;
- image compression;
- cached thumbnails;
- avoid N+1 query;
- spatial indexes.

## Reliability

- graceful offline/error state;
- retry yang aman;
- idempotent server action untuk operasi penting;
- payment status tidak berubah karena duplicate request.

## Accessibility

- minimum target size 44-48dp;
- contrast memadai;
- semantic labels;
- jangan mengandalkan warna saja;
- dynamic text sejauh layout memungkinkan.

## Privacy

- location on-demand;
- no location history by default;
- private docs tidak public;
- minimum personal data;
- review identity tidak perlu diekspos publik.

---

# 22. Design Acceptance

UI harus mengikuti `DESIGN.md`.

Non-negotiable:

- mobile-first;
- tidak terlihat seperti dashboard template generik;
- tidak memakai emoji sebagai icon UI;
- map dan bottom sheet terasa native;
- clear visual hierarchy;
- tidak menaruh semua konten dalam kartu;
- loading skeleton untuk content-heavy screen;
- empty/error states lengkap;
- motion ringan dan fungsional.

---

# 23. Analytics Events

Event minimum:

```text
app_open
onboarding_complete
recommendation_impression
property_view
property_save
property_unsave
compare_add
map_search_area
near_me_search
filter_apply
tenancy_request
tenancy_accepted
payment_due_view
review_submit
```

Event logging harus memiliki privacy review.

---

# 24. Acceptance Criteria V1

## Discovery

- user dapat mencari dan memfilter property;
- query location berfungsi;
- map results sinkron dengan filter;
- property detail memuat availability terbaru.

## Recommendation

- baseline dapat direproduksi;
- model candidate dapat dievaluasi;
- model terpilih terintegrasi;
- user mendapat explanation;
- cold-start tidak menghasilkan blank feed.

## Tenancy

- accepted request menghasilkan tenancy yang valid;
- room status berubah konsisten;
- unauthorized user tidak dapat membaca tenancy.

## Payment

- due date akurat;
- custom reminder berfungsi;
- owner dan tenant melihat data yang sesuai hak akses.

## Review

- non-tenant tidak dapat review;
- verified tenant dapat review sesuai eligibility;
- analysis aspect hanya menggunakan review yang valid.

## Admin

- owner/listing verification berfungsi;
- report moderation berfungsi;
- privileged action tercatat.

---

# 25. ML Success Criteria

Tim harus menetapkan target setelah baseline eksperimen awal.

Dilarang menulis target numerik final tanpa data awal.

Success harus mencakup:

1. model melampaui baseline pada metrik yang relevan atau memberikan trade-off yang dapat dibuktikan;
2. model dapat direproduksi;
3. model inference stabil;
4. explainability tersedia;
5. error dan limitasi didokumentasikan;
6. manfaat recommendation divalidasi dengan user/stakeholder.

---

# 26. Research and Validation Questions

## RQ-1
Apakah personalized recommendation yang menggabungkan preferensi, feature property, dan geospatial relevance memberikan ranking yang lebih relevan dibanding popularity-based baseline?

## RQ-2
Bagaimana pengaruh interaction feedback terhadap kualitas recommendation setelah data bertambah?

## RQ-3
Seberapa efektif NLP dalam mengekstraksi sentiment per aspek dari feedback verified tenant?

## RQ-4
Apakah fitur recommendation + map exploration mengurangi effort pencarian dibanding listing/filter tanpa personalisasi?

---

# 27. Test Strategy

## Flutter

- unit test;
- widget test;
- integration test untuk critical journey.

## Supabase

- migration test;
- constraint test;
- RLS test per role;
- storage policy test;
- RPC/spatial query test.

## ML

- reproducible training;
- dataset split test;
- leakage check;
- metric computation;
- error analysis;
- inference contract test.

## End-to-end critical path

1. seeker register;
2. onboarding;
3. recommendation;
4. explore map;
5. view property;
6. request tenancy;
7. owner accepts;
8. tenancy active;
9. payment reminder;
10. verified review;
11. owner sees aggregate feedback.

---

# 28. Capstone Alignment

Dokumen project harus menghasilkan:

- CP-01 project charter dan bukti masalah;
- CP-02 requirement, data plan, acceptance criteria, risk/test plan;
- CP-03 alternatives, architecture, ML baseline, prototype;
- CP-04 working repository, integration, reproducibility, tests;
- CP-05 validation, error analysis, stable demo, manual, report, poster, video.

Artefak akhir minimum:

- working mobile app;
- Supabase schema/migrations;
- RLS policies;
- dataset/data dictionary;
- ML model and model card;
- source repository;
- reproducible training/inference instructions;
- test evidence;
- final report;
- user manual;
- poster;
- demo;
- 3-5 minute video;
- individual contribution evidence.

---

# 29. Risk Register Baseline

| Risk | Impact | Mitigation |
|---|---|---|
| Tidak cukup interaction data | Hybrid CF lemah | Gunakan content-based sebagai strong baseline dan lakukan pilot instrumentation |
| Review text terlalu sedikit | NLP lemah | Fokus structured aspect rating + labeled pilot dataset; dokumentasikan batasan |
| Location permission ditolak | Near-me tidak bekerja | Sediakan campus/manual location search |
| Routing API tidak tersedia | ETA/isocrone gagal | Fallback ke distance; jangan fake ETA |
| Listing palsu | Trust turun | Owner/listing verification dan report flow |
| RLS salah | Data leak | RLS tests wajib sebelum gate PASS |
| Scope terlalu besar | Deadline gagal | V1/P1/V2 discipline |
| AI metrics direkayasa | Integritas akademik gagal | Semua metric harus dapat direproduksi dari experiment artifact |
| Model bias ke listing populer | New listing tidak terlihat | Content metadata + coverage metric + cold-start analysis |

---

# 30. Definition of Done

Sebuah feature hanya Done jika:

- requirement jelas;
- code selesai;
- test relevan lulus;
- loading/error/empty state selesai;
- accessibility basic check;
- RLS/security check jika menyentuh data;
- analytics event bila dibutuhkan;
- dokumentasi diperbarui;
- REVIEW selesai;
- semua blocker diperbaiki;
- VALIDATION gate = PASS.

**"Berfungsi di satu device" bukan Definition of Done.**
