# SPRINTS.md — KOSTARA 16-Week Capstone Plan

Roadmap ini disejajarkan dengan stage-gate Capstone:

```text
CP-00 → CP-01 → CP-02 → CP-03 → CP-04 → CP-05
Setup    Problem   Requirement  Design   Build   Validate
```

Setiap fase mengikuti:

**THINK → BUILD → REVIEW → FIX → PASS**

Tidak boleh melanjutkan gate akademik bila fase belum PASS.

---

# Sprint 0 — Pre-Semester / Week 1
## CP-00: Project Foundation

### THINK

Validasi:

- anggota tim;
- peran;
- topik;
- pembimbing;
- stakeholder;
- repository;
- toolchain;
- data access hypothesis.

### BUILD

Deliverables:

- repository;
- branch strategy;
- README;
- docs folder;
- initial AGENTS/PRD/DESIGN/SPRINTS/VALIDATION;
- AI usage log;
- project logbook;
- risk register;
- environment bootstrap.

### REVIEW

Checklist:

- repo dapat di-clone;
- Flutter bootstrap berjalan;
- Supabase project boundary jelas;
- no secret committed;
- roles tim jelas;
- topik tidak sekadar "membuat aplikasi kos".

### FIX

Perbaiki semua gap.

### PASS Gate

CP-00 PASS bila:

- project charter draft siap;
- repo siap;
- stakeholder target jelas;
- toolchain dapat dijalankan.

---

# Sprint 1 — Weeks 1-2
## CP-01: Problem and Stakeholder Validation

### THINK

Hipotesis:

- mahasiswa sulit menemukan kos yang cocok secara multi-kriteria;
- pemilik kos kesulitan mengelola availability/tenant/payment/feedback;
- review yang tidak verified menurunkan trust;
- aplikasi pencarian kehilangan lifecycle setelah user mendapat kos.

### BUILD

Aktivitas:

- interview seeker/tenant;
- interview owner;
- map current process;
- identify pain points;
- collect example listing/payment/review flow;
- define stakeholder;
- define benefit metrics.

Dokumen:

- Project Charter;
- Problem Statement;
- Stakeholder Map;
- Current Journey;
- Evidence Log;
- Initial Risk Register.

### REVIEW

Pertanyaan gate:

- apakah masalah benar terjadi?
- siapa pemilik masalah?
- apakah ML benar-benar dibutuhkan untuk recommendation?
- apakah mobile platform justified?
- apakah data dan mitra realistis?

### FIX

Jika ML belum justified, jangan paksakan. Refine problem dan decision use-case.

### PASS Gate

- problem evidence valid;
- stakeholder dapat diidentifikasi;
- problem tidak berorientasi teknologi;
- benefit indicator tersedia.

---

# Sprint 2 — Weeks 3-4
## CP-02: Requirements, Data, Acceptance Criteria

### THINK

Tentukan:

- V1/P1/V2;
- data requirement;
- role permission;
- analytics event;
- review eligibility;
- tenancy rule;
- map/routing feasibility;
- ML dataset strategy.

### BUILD

Deliverables:

- PRD locked V1;
- functional requirements;
- non-functional requirements;
- acceptance criteria;
- user stories;
- data dictionary v0;
- schema draft;
- RLS matrix draft;
- ML data plan;
- test plan;
- privacy analysis;
- risk update.

Prototype:

- low fidelity flows only;
- no full implementation required.

### REVIEW

Requirement Review:

- setiap feature punya user dan problem;
- ML memiliki target dan baseline;
- GIS memiliki fungsi nyata;
- critical data punya owner;
- location privacy jelas;
- RLS matrix complete.

### FIX

Scope cut jika terlalu besar.

### PASS Gate

Tidak boleh lanjut CP-03 jika:

- requirement ambigu;
- data source tidak realistis;
- role access tidak jelas;
- acceptance criteria belum terukur.

---

# Sprint 3 — Weeks 5-6
## CP-03A: Alternative Design and Architecture

### THINK

Bandingkan alternatif:

## App architecture
- feature-first Riverpod;
- alternatif lain jika ada.

## Map
- flutter_map;
- MapLibre-compatible.

## Recommendation
- popularity baseline;
- content-based;
- hybrid candidate.

## NLP
- rule/TF-IDF baseline;
- transformer candidate.

## Notification
- local scheduling;
- server push.

### BUILD

Deliverables:

- architecture diagram;
- ERD;
- RLS policy design;
- screen flow;
- high fidelity core wireframe;
- ML experiment plan;
- dataset schema;
- ADRs;
- prototype API contracts.

### REVIEW

Mid design review internal:

- reason for choices documented;
- no unnecessary infra;
- Supabase boundaries safe;
- service role not in mobile;
- ML reproducibility plan exists;
- map provider terms understood.

### FIX

Resolve architecture debt before large implementation.

### PASS Gate

Architecture and alternative decision documented.

---

# Sprint 4 — Weeks 7-8
## CP-03B: Prototype and ML Baselines

### THINK

Prioritize uncertainty:

1. spatial search;
2. auth/RLS;
3. recommendation baseline;
4. review data pipeline;
5. map interaction.

### BUILD

Prototype:

- auth;
- seeker onboarding prototype;
- property seed;
- property list;
- map;
- campus query;
- property detail;
- owner basic add property;
- Supabase schema v1;
- RLS baseline.

ML:

- popularity baseline;
- content-based baseline;
- metric pipeline;
- first dataset card;
- review aspect taxonomy;
- NLP labeling guideline.

### REVIEW

CP-03 Midterm Design Review:

- demo prototype;
- baseline metric reproducible;
- architecture matches PRD;
- no RLS bypass;
- test evidence;
- backlog locked for CP-04.

### FIX

Fix critical design issues.

### PASS Gate

CP-03 PASS bila:

- prototype berjalan;
- baseline ada;
- backlog implementasi jelas;
- major risk reduced.

---

# Sprint 5 — Weeks 9-10
## CP-04A: Core Product Implementation

### THINK

Critical journey:

```text
Register
→ Onboarding
→ Discover
→ Map
→ Detail
→ Save
→ Request
→ Owner accept
→ Tenancy
```

### BUILD

Flutter:

- production auth flow;
- onboarding;
- home;
- search;
- filter;
- Explore Map;
- property detail;
- favorites;
- compare;
- tenancy request.

Owner:

- dashboard baseline;
- property CRUD;
- room management;
- availability;
- request handling.

Backend:

- migrations;
- constraints;
- storage;
- RLS;
- spatial RPC;
- analytics interaction events.

Tests:

- unit;
- widget;
- RLS;
- integration critical path partial.

### REVIEW

- Flutter analyze;
- tests;
- role isolation;
- slow network;
- denied location;
- map performance;
- image upload.

### FIX

No critical issue carried to integration sprint.

### PASS Gate

Release `alpha-1` runnable.

---

# Sprint 6 — Weeks 11-12
## CP-04B: ML + Tenancy + Payment + Review Integration

### THINK

Pastikan ML integration contract stabil.

### BUILD

Recommendation:

- candidate hybrid experiment;
- compare baseline;
- select model based on results;
- inference endpoint;
- fallback ranking;
- explanation.

Tenancy:

- active tenancy;
- payment schedule;
- reminder settings;
- payment history.

Feedback:

- review eligibility;
- structured aspect ratings;
- free text;
- NLP baseline/candidate;
- owner feedback insight.

Admin:

- owner verification;
- listing moderation;
- report queue;
- model version display/basic monitoring.

### REVIEW

Implementation Review:

- model reproducibility;
- model card;
- dataset card;
- inference latency;
- fallback works;
- RLS full matrix;
- payment consistency;
- review eligibility cannot be bypassed.

### FIX

All P0/P1 issues.

### PASS Gate

CP-04 PASS:

- function utama berjalan;
- integration stable;
- reproducibility documented;
- security review passed.

---

# Sprint 7 — Weeks 13-14
## CP-05A: Verification, Validation, Error Analysis

### THINK

Freeze feature scope.

Tidak ada feature baru kecuali diperlukan untuk memperbaiki acceptance criteria.

### BUILD

Execute test plan:

- functional acceptance;
- UX test;
- stakeholder validation;
- ML evaluation;
- cold-start evaluation;
- error analysis;
- robustness checks;
- RLS/security tests;
- performance tests;
- map edge cases.

Collect:

- test evidence;
- user feedback;
- failed cases;
- model errors;
- screenshots/logs.

### REVIEW

Bandingkan:

- recommendation candidate vs baseline;
- NLP candidate vs baseline;
- target vs actual;
- stakeholder need vs delivered behavior.

### FIX

Perbaiki:

- critical UX;
- incorrect recommendation handling;
- security bugs;
- data integrity;
- inference failure;
- map/data inconsistency.

### PASS Gate

Validation evidence lengkap dan dapat diaudit.

---

# Sprint 8 — Weeks 15-16
## CP-05B: Release Candidate, Documentation, Demo, Expo

### THINK

No unnecessary refactor.

Fokus stabilitas dan evidence.

### BUILD

Release:

- final Android build;
- stable demo data;
- production-like Supabase setup;
- tagged release;
- backup/restore plan;
- runbook.

Documentation:

- final report;
- user manual;
- technical README;
- architecture;
- data dictionary;
- dataset card;
- model card;
- API/inference contract;
- AI usage log;
- changelog;
- contribution report;
- poster;
- 3-5 minute video;
- presentation;
- demo script.

### REVIEW

Final smoke test:

```text
new seeker
→ recommendation
→ map
→ request
→ owner acceptance
→ tenancy
→ reminder
→ review
→ owner insight
```

Admin flow also tested.

### FIX

Only release blockers and validated fixes.

### PASS Gate

Final Review ready:

- product stable;
- demo repeatable;
- report aligned with actual artifact;
- model metrics reproducible;
- known limitations disclosed;
- individual contribution evidence available.

---

# Backlog Priority

## P0 — Must Have

- auth;
- role;
- onboarding;
- property/room;
- owner verification;
- search/filter;
- Explore Map;
- campus/nearby;
- recommendation baseline + selected model;
- favorite;
- request tenancy;
- tenancy;
- payment reminder;
- verified feedback;
- review analysis;
- RLS;
- tests;
- admin moderation.

## P1 — Should Have

- travel time;
- isochrone;
- advanced owner analytics;
- monthly pulse feedback;
- server push across devices;
- model monitoring dashboard.

## P2 — Later

- payment gateway;
- chat;
- dynamic pricing;
- web owner dashboard;
- multi-city ops;
- smart contract;
- advanced fraud detection.

---

# Sprint Task Rule

Setiap task pada sprint harus punya:

```text
ID:
User:
Problem:
Requirement:
Acceptance Criteria:
Dependency:
Data Impact:
RLS Impact:
ML Impact:
Test:
Owner:
Status:
Gate:
```

---

# Academic Deliverables Mapping

| Capstone | KOSTARA evidence |
|---|---|
| CP-00 | repo, team, scope, stakeholder plan |
| CP-01 | charter, interviews, evidence, benefit metrics |
| CP-02 | PRD, data plan, acceptance criteria, test plan, risk |
| CP-03 | alternatives, architecture, ERD, design, baseline ML, prototype |
| CP-04 | working app, Supabase, RLS, model integration, tests |
| CP-05 | evaluation, error analysis, validation, manual, report, poster/video, demo |

---

# Rule of Progress

`Sprint calendar` tidak mengalahkan `quality gate`.

Jika Week 8 sudah tiba tetapi CP-03 belum PASS, tim tidak berpura-pura sudah masuk CP-04. Buat recovery plan, perbaiki blocker, dan dokumentasikan deviasi.
