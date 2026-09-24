# AGENTS.md — KOSTARA

Dokumen ini adalah operating contract untuk AI coding agent yang mengerjakan KOSTARA.

**Baca seluruh file ini sebelum melakukan perubahan apa pun.**

---

# 1. Project Identity

Nama produk: **KOSTARA**

Tujuan:

Membangun aplikasi mobile Flutter untuk pencarian dan manajemen kos dengan:

- Supabase sebagai backend utama;
- PostgreSQL/PostGIS untuk data geospatial;
- personalized recommendation berbasis Machine Learning;
- Explore Map dan campus-aware search;
- tenant lifecycle;
- payment reminder;
- verified resident feedback;
- NLP review analysis;
- owner management;
- super admin moderation.

Target awal: mahasiswa/pencari kos dan pemilik kos, pilot awal Kota Padang.

Capstone track: **PIF683 Proyek dalam Kecerdasan Buatan**.

---

# 2. Read Order

Sebelum coding:

1. `AGENTS.md`
2. `PRD.md`
3. `DESIGN.md`
4. `SPRINTS.md`
5. `VALIDATION_PROTOCOL.md`
6. `PROMPTS.md`
7. `README.md`

Sebelum membuat rencana perubahan, agent juga wajib membaca codebase aktual: struktur repo, `pubspec.yaml`, entry point, routing, state management, feature modules, Supabase setup, migrations, RLS, storage policies, PostGIS/RPC, tests, dan ML service bila ada. Jangan pernah mengasumsikan project masih greenfield.

Jika task menyentuh data/model, baca juga artefak berikut bila sudah ada:

- data dictionary;
- model card;
- dataset card;
- migration history;
- ADR/decision log;
- changelog.

---

# 3. Source of Truth Precedence

Jika ada konflik:

1. Instruksi eksplisit terbaru dari project owner.
2. `VALIDATION_PROTOCOL.md`
3. `PRD.md`
4. `DESIGN.md`
5. `SPRINTS.md`
6. existing implementation, hanya jika tidak bertentangan dengan dokumen di atas.

Existing code bukan alasan untuk mempertahankan arsitektur yang salah, tetapi perubahan besar harus melalui review dan migration plan.

---

# 4. Non-Negotiable Rules

## 4.1 Jangan coding sebelum THINK

Setiap task harus dimulai dengan:

```text
THINK
- tujuan
- requirement
- file terdampak
- data/schema impact
- security impact
- UX impact
- test plan
- risk
```

Jika konteks belum cukup, agent harus mencari konteks di repo/dokumen lebih dulu.

## 4.2 Gunakan loop wajib

Setiap task/phase:

**THINK → BUILD → REVIEW → FIX → PASS**

Tidak boleh lanjut ke task/fase berikut bila status belum `PASS`.

## 4.3 Jangan disable RLS

Dilarang:

- mematikan RLS untuk menghilangkan error;
- memakai service role key di Flutter;
- membuat policy `true` untuk semua operasi tanpa analisis;
- membuat storage bucket private menjadi public karena implementasi sulit.

## 4.4 Jangan mengarang ML

Dilarang:

- membuat metrik dummy;
- mengarang confusion matrix;
- mengklaim model "lebih akurat" tanpa hasil eksperimen;
- menggunakan angka recommendation score sebagai probability jika bukan probability;
- menulis "AI-powered" untuk fitur rule-based tanpa penjelasan.

## 4.5 Jangan fake GIS

Dilarang:

- membuat ETA perjalanan dari jarak lurus tanpa penjelasan;
- menampilkan isochrone palsu;
- menyimpan lokasi background tanpa requirement dan consent;
- membuat titik koordinat perkiraan seolah data exact.

## 4.6 Jangan merusak sistem demi UI

UI refactor tidak boleh:

- mengubah schema tanpa kebutuhan;
- menghapus policy;
- mengubah contract API;
- menghapus state penting;
- mematahkan role flow.

## 4.7 Jangan lakukan destructive migration tanpa approval

Untuk drop column/table, rewrite data besar, atau breaking migration:

1. jelaskan alasan;
2. jelaskan data yang terdampak;
3. buat backup/migration path;
4. tunggu approval project owner bila berisiko;
5. lakukan validation.

## 4.8 Tidak ada secret di repository

Termasuk:

- Supabase service role key;
- FCM server key;
- routing provider secret;
- ML server private credentials;
- private dataset URL.

## 4.9 Product UI tidak menggunakan emoji sebagai icon

Gunakan icon library yang konsisten.

## 4.10 Hindari "AI slop"

UI tidak boleh berupa:

- gradient berlebihan;
- glass cards di semua tempat;
- semua section jadi rounded card;
- giant marketing heading di aplikasi operasional;
- random glow;
- excessive chips;
- empty dashboard tile;
- decorative animation tanpa fungsi.

---

# 5. Capstone Integrity Rules

Panduan Capstone meminta AI generatif hanya sebagai alat bantu, bukan pengganti pertanggungjawaban mahasiswa.

Agent harus membantu membuat jejak bukti.

Setiap penggunaan AI yang berdampak pada artefak harus dapat dicatat dengan:

```text
Tanggal:
Tool/model:
Tujuan:
Bagian yang dibantu:
File/artefak terdampak:
Cara verifikasi:
Perubahan manual setelah output AI:
Risiko/keterbatasan:
```

Jangan memasukkan ke AI publik:

- data pribadi tenant;
- dokumen verifikasi;
- kode atau data mitra yang bersifat rahasia;
- credentials.

---

# 6. Canonical Product Scope

Role auth:

```text
super_admin
owner
seeker
```

Tenant adalah lifecycle state dari seeker.

Core V1:

- auth;
- onboarding;
- owner verification;
- property/room listing;
- search/filter;
- Explore Map;
- current location on demand;
- campus-aware search;
- favorite;
- compare;
- personalized recommendation;
- request tenancy;
- active tenancy;
- payment schedule/reminder;
- verified review;
- aspect review analysis;
- owner dashboard;
- super admin moderation.

Out of core V1:

- payment gateway;
- real-time chat;
- dynamic pricing;
- face recognition;
- background tracking;
- nationwide launch;
- AI-generated review;
- credit scoring.

---

# 7. Recommended Technical Stack

## Flutter

- Flutter stable;
- Dart stable compatible;
- Riverpod;
- go_router;
- Supabase Flutter SDK;
- geolocator;
- flutter_map or MapLibre-compatible stack;
- flutter_local_notifications;
- cached_network_image;
- timezone handling.

Do not add packages without checking:

- maintenance status;
- license;
- platform support;
- existing equivalent in repo;
- binary size impact.

## Supabase

- Auth;
- PostgreSQL;
- PostGIS;
- Storage;
- Edge Functions when trusted server logic is needed;
- Realtime only for features that truly need it.

## ML

- Python environment;
- deterministic seed where possible;
- training script;
- versioned dependency file;
- FastAPI or equivalent inference service;
- model artifact versioning.

---

# 8. Repository Structure

Target baseline:

```text
/
  apps/
    mobile/
  services/
    ml/
  supabase/
    migrations/
    functions/
    seed/
  docs/
    PRD.md
    DESIGN.md
    SPRINTS.md
    VALIDATION_PROTOCOL.md
    decisions/
    logs/
  data/
    README.md
    schemas/
  experiments/
    recommendation/
    review_nlp/
```

Jika repository sudah memiliki struktur lain yang baik, jangan memindahkan semua file hanya demi mengikuti contoh ini. Buat ADR jika perubahan struktur diperlukan.

---

# 9. Flutter Engineering Rules

## 9.1 Feature-first

Gunakan feature modular.

Jangan membuat:

```text
screens/
widgets/
services/
```

yang menjadi folder global raksasa tanpa domain ownership.

Prefer:

```text
features/discovery/
features/tenancy/
features/owner/
```

## 9.2 Business logic

Jangan taruh business logic kompleks di Widget.

Pisahkan:

- UI;
- state;
- repository;
- service;
- model/domain logic.

## 9.3 State

- loading;
- success;
- empty;
- error;
- stale/offline bila relevan.

Tidak boleh hanya menangani happy path.

## 9.4 Navigation

Route harus mempertimbangkan role dan auth guard.

## 9.5 Forms

- validation jelas;
- error dekat field;
- preserve user input;
- jangan menghapus input ketika request gagal.

## 9.6 Map

Map state terpisah dari filter state namun sinkron.

Debounce viewport query.

Jangan reload semua marker pada setiap pixel movement.

## 9.7 Images

- compress upload;
- thumbnail;
- caching;
- placeholder;
- error fallback.

---

# 10. Supabase Engineering Rules

## 10.1 Migration first

Perubahan schema harus melalui versioned migration.

Jangan mengedit production schema manual tanpa migration record.

## 10.2 Constraints

Gunakan DB constraint untuk invariant penting.

Contoh:

- price >= 0;
- one active tenancy per room bila rule tersebut berlaku;
- review property harus match tenancy property;
- owner property ownership konsisten.

## 10.3 RLS tests

Setiap tabel baru harus punya matrix:

```text
anonymous
seeker-own
seeker-other
owner-own
owner-other
super_admin
```

Test:

- SELECT;
- INSERT;
- UPDATE;
- DELETE.

## 10.4 Storage policies

Pisahkan public property images dari private documents.

## 10.5 PostGIS

Spatial query harus memakai index.

Jangan mengambil semua coordinates ke device lalu menghitung semuanya di Flutter bila database bisa melakukan query.

---

# 11. ML Engineering Rules

# 11.1 Dataset before model

Sebelum training, wajib ada:

- data source;
- izin;
- schema;
- data dictionary;
- label definition;
- missing value policy;
- split strategy;
- bias/representativeness note;
- dataset version.

## 11.2 Recommender sequence

Urutan eksperimen:

1. popularity/filter baseline;
2. content-based;
3. hybrid candidate;
4. compare;
5. select;
6. integrate.

Jangan lompat langsung ke deep learning.

## 11.3 Interaction weights

Jika menggunakan implicit weights, dokumentasikan.

Contoh awal hanya hipotesis:

```text
impression = 0
view = 1
save = 3
compare = 2
request = 5
tenancy = 8
```

Angka ini **bukan final**. Harus diperlakukan sebagai design parameter dan diuji.

## 11.4 Avoid leakage

Jangan menggunakan future interaction untuk memprediksi ranking masa lalu.

Prefer temporal split untuk event sequence.

## 11.5 Reproducibility

Setiap eksperimen menyimpan:

- dataset version;
- code commit;
- seed;
- dependencies;
- parameters;
- model artifact;
- metrics;
- timestamp.

## 11.6 Review NLP

Sebelum NLP:

- definisikan aspect taxonomy;
- buat labeling guideline;
- inter-annotator check bila memungkinkan;
- dokumentasikan label distribution;
- lakukan error analysis.

## 11.7 ML fallback

Jika ML service gagal:

- aplikasi tetap usable;
- fallback recommendation ke safe baseline;
- jangan blank screen;
- tampilkan graceful state tanpa mengklaim personalisasi.

---

# 12. Privacy Rules

## Location

- ask permission just-in-time;
- no background collection;
- no permanent history by default;
- allow manual campus search.

## Reviews

- public review tidak perlu menampilkan identitas lengkap;
- verified status boleh tampil;
- private tenancy data tetap private.

## Payment

- jangan simpan data finansial yang tidak dibutuhkan;
- V1 tidak membutuhkan kartu/payment credential.

## Verification docs

- private bucket;
- signed access;
- audit admin access jika memungkinkan.

---

# 13. Design Implementation Rules

Ikuti `DESIGN.md`.

Wajib:

- Plus Jakarta Sans atau font yang telah dikunci desain;
- consistent spacing;
- icons, not emoji;
- no decorative clutter;
- native-feeling bottom navigation;
- map bottom sheet;
- clear permission prompt;
- skeleton loading;
- responsive untuk device kecil;
- accessible touch target.

Sebelum menyebut screen selesai, cek:

- 320-360dp width;
- 390-430dp width;
- long text;
- large font;
- keyboard open;
- slow network;
- empty state;
- failed image;
- permission denied.

---

# 14. THINK Protocol

Sebelum build, tulis internal task brief:

```text
TASK:
GOAL:
RELATED REQUIREMENTS:
CURRENT STATE:
ASSUMPTIONS:
FILES TO INSPECT:
FILES TO CHANGE:
DB IMPACT:
RLS IMPACT:
ML IMPACT:
UX IMPACT:
TEST PLAN:
RISKS:
ROLLBACK:
```

Jika ada assumption kritis, verifikasi sebelum build.

---

# 15. BUILD Protocol

Saat build:

1. lakukan perubahan terkecil yang memenuhi requirement;
2. pertahankan backward compatibility bila feasible;
3. update migration/contract lebih dulu bila backend berubah;
4. implementasikan state lengkap;
5. tulis test bersama feature;
6. tambahkan logging yang aman;
7. update docs bila keputusan berubah.

---

# 16. REVIEW Protocol

Review wajib mencakup:

## Flutter

```bash
dart format .
flutter analyze
flutter test
```

Tambahkan integration test bila critical flow.

## Backend

- inspect migration;
- run schema test;
- run RLS matrix;
- verify constraints;
- verify storage policy.

## ML

- rerun metric script;
- verify split;
- inspect error cases;
- confirm model artifact;
- test inference contract.

## UX

- compare with DESIGN;
- loading;
- empty;
- error;
- permissions;
- accessibility;
- mobile dimensions.

## Product

- acceptance criteria;
- no accidental scope creep;
- no regressions.

---

# 17. FIX Protocol

Semua issue severity P0/P1 wajib diperbaiki.

P2 dapat ditunda hanya jika:

- tidak merusak acceptance criteria;
- dicatat;
- ada alasan;
- ada target sprint.

Setelah fix, ulang REVIEW yang relevan.

Jangan mengubah status menjadi PASS hanya karena deadline.

---

# 18. PASS Criteria

Task PASS hanya jika:

- acceptance criteria lulus;
- tests lulus;
- analyze/lint lulus;
- security/RLS lulus bila relevan;
- no known blocker;
- documentation updated;
- evidence tersedia.

---

# 19. Required Agent Completion Report

Setelah satu task, output agent harus:

```text
## Summary
Apa yang dibuat/diubah.

## Files Changed
- ...

## Database Changes
- migration...
- policy...

## Validation
- flutter analyze: PASS/FAIL
- flutter test: PASS/FAIL
- RLS: PASS/FAIL
- integration: PASS/FAIL
- ML evaluation: PASS/FAIL/N/A

## Issues Found and Fixed
- ...

## Remaining Risks
- ...

## Gate
PASS / NOT PASS

## Next Allowed Step
Hanya jika PASS.
```

Jika `NOT PASS`, jangan lanjut.

---

# 20. Git and Change Discipline

Prefer commit kecil dan jelas:

```text
feat(discovery): add campus-aware property search
feat(map): add viewport spatial query
feat(owner): add room availability management
fix(rls): restrict tenancy access to related owner
test(recommender): add temporal split evaluation
docs(adr): record map provider decision
```

Jangan mencampur:

- design refactor;
- schema migration;
- ML model update;

dalam satu commit besar tanpa alasan.

---

# 21. ADR / Decision Log

Buat ADR untuk keputusan besar:

- map provider;
- routing provider;
- state management;
- ML architecture;
- role strategy;
- recommendation scoring;
- notification architecture.

Template:

```text
# ADR-XXX Title

Status:
Date:

## Context
## Options
## Decision
## Consequences
## Validation
```

---

# 22. Definition of "Do Not Proceed"

Agent harus STOP jika:

- requirement bertentangan;
- migration berpotensi data loss tanpa approval;
- policy/security belum dipahami;
- model metric belum dapat direproduksi;
- stakeholder requirement belum jelas pada gate CP-01/CP-02;
- test utama gagal;
- source data/izin tidak valid.

STOP bukan kegagalan. Itu bagian dari quality control.

---

# 23. Capstone Evidence

Setiap sprint harus menghasilkan bukti:

- commit;
- issue/backlog;
- decision log;
- screenshot/demo;
- test result;
- experiment result;
- meeting note;
- AI usage log;
- changelog.

Tidak cukup hanya mempunyai final APK.

---

# 24. Final Product Principle

KOSTARA harus tetap berguna dalam lifecycle panjang:

```text
SEEKER
  ↓
DISCOVERY
  ↓
RECOMMENDATION
  ↓
TENANCY REQUEST
  ↓
VERIFIED TENANT
  ↓
PAYMENT + REMINDER
  ↓
FEEDBACK
  ↓
RENEW / MOVE
  ↓
DISCOVERY AGAIN
```

Semua feature harus memperkuat loop ini atau operation owner/admin.

Jika sebuah feature tidak memperkuat loop, tidak memenuhi requirement Capstone, dan tidak punya acceptance criteria, jangan dibangun pada V1.
