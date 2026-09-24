# PROMPTS.md — KOSTARA AI Agent Execution Prompts

Dokumen ini adalah **prompt execution pack** untuk AI coding agent yang mengerjakan KOSTARA.

Dokumen ini **bukan pengganti** `AGENTS.md`, `PRD.md`, `DESIGN.md`, `SPRINTS.md`, atau `VALIDATION_PROTOCOL.md`. Prompt di sini memaksa agent membaca source of truth, memahami codebase yang benar-benar ada, lalu bekerja menggunakan quality gate:

**THINK → BUILD → REVIEW → FIX → PASS**

Tidak ada sprint yang boleh dianggap selesai hanya karena kode berhasil dibuat.

---

# 0. Project Context Snapshot

KOSTARA adalah aplikasi mobile Flutter untuk pencarian dan manajemen kos dengan lifecycle pengguna yang panjang.

Stack utama:

- Flutter mobile-first;
- Supabase Auth;
- PostgreSQL;
- PostGIS untuk data geospatial;
- Supabase Storage;
- RLS untuk authorization;
- Machine Learning recommendation system;
- NLP untuk analisis feedback penghuni;
- notification/reminder untuk pembayaran;
- service ML yang reproducible, direkomendasikan Python/FastAPI bila dibutuhkan.

Role canonical:

```text
super_admin
owner
seeker
```

`tenant` **bukan role auth baru**, tetapi lifecycle state dari `seeker` yang memiliki tenancy valid.

Core product:

- personalized kos recommendation;
- campus-aware search;
- current-location/nearby search dengan consent;
- Explore Map;
- property dan room management;
- owner verification;
- tenancy management;
- payment schedule dan custom reminder;
- verified resident feedback;
- aspect-based review sentiment analysis;
- owner insight;
- super admin verification dan moderation.

Core ML:

1. **Hybrid Personalized Recommendation System**.
2. **Aspect-Based Review Sentiment Analysis**.

GIS bukan dekorasi. Spatial features harus benar-benar memengaruhi discovery/recommendation.

Capstone track: **PIF683 Proyek dalam Kecerdasan Buatan**.

---

# 1. MANDATORY PRE-FLIGHT — WAJIB DI SETIAP SESSION

Bagian ini adalah aturan paling penting di dokumen ini.

**JANGAN langsung coding setelah menerima prompt sprint.**

Agent wajib melakukan Context Acquisition lebih dahulu.

## 1.1 Read all project documents

Baca **penuh**, jangan hanya judul atau ringkasan:

1. `AGENTS.md`
2. `PRD.md`
3. `DESIGN.md`
4. `SPRINTS.md`
5. `VALIDATION_PROTOCOL.md`
6. `PROMPTS.md`
7. `README.md`

Jika tersedia, baca juga:

- `docs/architecture/*`
- `docs/adr/*`
- `docs/data/*`
- `docs/ml/*`
- `docs/testing/*`
- `docs/capstone/*`
- `CHANGELOG.md`
- `AI_USAGE_LOG.md`
- `DECISIONS.md`
- migration notes;
- data dictionary;
- dataset card;
- model card;
- risk register;
- logbook;
- previous gate report.

Jangan berasumsi isi dokumen berdasarkan nama file.

## 1.2 Read the existing codebase BEFORE planning changes

Agent wajib memperlakukan repository sebagai codebase yang mungkin sudah memiliki implementasi.

Lakukan inspeksi repo sebelum mengubah file apa pun.

Minimal periksa:

```text
repository root
current branch
git status
recent commits
folder structure
pubspec.yaml
Flutter entry point
routing/navigation
state management
feature modules
data/repository layer
models/entities
shared/core utilities
theme/design tokens
Supabase client setup
environment/config strategy
migrations
RLS policies
RPC/database functions
PostGIS usage
storage buckets/policies
Edge Functions jika ada
analytics event pipeline
tests
ML service
ML training/evaluation scripts
model artifacts metadata
CI configuration
README/run instructions
```

Gunakan pencarian codebase untuk menemukan implementasi aktual, bukan menebak lokasi file.

Contoh hal yang harus dicari:

```text
Supabase.initialize
GoRouter / AutoRoute
Riverpod providers
current user / role resolver
property repository
location permission
map widget
PostGIS RPC
recommendation endpoint
review eligibility
payment schedule
RLS migrations
service_role
TODO / FIXME / HACK
```

## 1.3 Determine whether project is greenfield or existing

Agent harus menyatakan salah satu:

```text
CODEBASE STATE: GREENFIELD
```

atau:

```text
CODEBASE STATE: EXISTING IMPLEMENTATION
```

Jika existing implementation, agent harus menjaga kompatibilitas dan menghindari rewrite tanpa alasan kuat.

## 1.4 Produce Context Acquisition Report BEFORE BUILD

Sebelum coding, tampilkan laporan ringkas:

```text
CONTEXT ACQUISITION REPORT

1. Documents read:
   - ...

2. Current codebase:
   - architecture:
   - navigation:
   - state management:
   - backend integration:
   - database/migrations:
   - RLS:
   - GIS:
   - ML:
   - tests:

3. Current sprint/gate:
   - Sprint:
   - CP stage:
   - Previous gate status:

4. Existing implementation relevant to this task:
   - ...

5. Gaps/risks discovered:
   - ...

6. Files likely affected:
   - ...

7. Database/security impact:
   - ...

8. Test strategy:
   - ...

9. Decision:
   READY TO THINK / NOT READY
```

Jika `NOT READY`, cari konteks yang hilang terlebih dahulu. Jangan coding.

---

# 2. SOURCE OF TRUTH AND CONFLICT RULES

Jika ada konflik:

1. instruksi eksplisit terbaru dari project owner;
2. `VALIDATION_PROTOCOL.md` untuk quality gate;
3. `PRD.md` untuk requirement dan scope;
4. `DESIGN.md` untuk UI/UX;
5. `SPRINTS.md` untuk sequencing;
6. `AGENTS.md` untuk engineering/agent contract;
7. `PROMPTS.md` untuk execution template;
8. existing implementation jika tidak bertentangan dengan source of truth.

Jangan diam-diam memilih salah satu bila konflik substantif ditemukan. Catat konflik dalam THINK dan pilih tindakan yang paling aman atau minta keputusan bila benar-benar blocking.

---

# 3. UNIVERSAL EXECUTION CONTRACT

Setiap prompt sprint di bawah mengikuti kontrak ini.

## THINK

Sebelum build, agent wajib menjelaskan:

```text
Goal
User/role
Problem being solved
Requirement IDs / acceptance criteria
Current behavior
Desired behavior
Files/modules affected
Architecture impact
Database/schema impact
RLS/storage impact
GIS impact
ML impact
Privacy/security impact
UX impact
Failure states
Migration/rollback strategy
Test plan
Known risks
Scope exclusions
```

## BUILD

Implementasi harus:

- incremental;
- mengikuti existing convention bila sehat;
- tidak membuat duplicate architecture;
- tidak bypass RLS;
- tidak memasukkan service role key ke Flutter;
- tidak membuat fake ML metric;
- tidak membuat fake routing/ETA/isochrone;
- tidak mengganti UI contract tanpa alasan;
- tidak meninggalkan hardcoded production data;
- memiliki loading/error/empty/permission state;
- menambahkan test yang relevan;
- memperbarui dokumentasi bila contract berubah.

## REVIEW

Agent harus melakukan self-review terhadap:

```text
functional correctness
acceptance criteria
Flutter analyze/lint
unit/widget/integration tests
role isolation
RLS/storage policies
schema constraints
privacy/location permission
map/geospatial correctness
ML reproducibility
baseline comparison
fallback behavior
error handling
small-screen UI
accessibility
performance
security
regression
```

## FIX

Semua P0/P1 wajib diperbaiki sebelum PASS.

P2 hanya dapat ditunda bila:

- tidak merusak acceptance criteria;
- dicatat sebagai backlog;
- memiliki rationale.

Setelah FIX, ulang REVIEW.

## PASS

Agent hanya boleh menyatakan PASS jika evidence tersedia.

Format wajib:

```text
GATE REPORT

Sprint:
CP Stage:
Status: PASS / REVIEW FAILED

Implemented:
- ...

Validation executed:
- command/test:
- result:

Security/RLS evidence:
- ...

ML evidence:
- ...

UX evidence:
- ...

Known limitations:
- ...

Deferred P2/P3:
- ...

Next allowed step:
- ...
```

Jika status bukan PASS, tulis:

```text
NEXT SPRINT IS NOT AUTHORIZED.
```

---

# 4. MASTER SESSION PROMPT

Gunakan prompt ini saat memulai session baru AI agent, sebelum prompt sprint spesifik.

```text
You are the implementation agent for KOSTARA, a Flutter + Supabase Capstone project.

DO NOT START CODING YET.

Your first responsibility is to recover full project context from the repository itself.

MANDATORY CONTEXT ACQUISITION:
1. Read AGENTS.md completely.
2. Read PRD.md completely.
3. Read DESIGN.md completely.
4. Read SPRINTS.md completely.
5. Read VALIDATION_PROTOCOL.md completely.
6. Read PROMPTS.md completely.
7. Read README.md completely.
8. Read relevant architecture, ADR, migration, data, ML, testing, Capstone, logbook, changelog, dataset-card, model-card, and AI usage log files if they exist.
9. Inspect the entire repository structure before modifying anything.
10. Inspect the existing Flutter codebase, pubspec, app entry point, routing, state management, features, repositories, models, theme, Supabase setup, migrations, RLS, RPC/functions, PostGIS, storage policies, tests, ML service, scripts, and CI.
11. Check git status and do not overwrite unrelated uncommitted work.
12. Search for TODO/FIXME/HACK, duplicated implementations, temporary bypasses, hardcoded secrets, service_role usage, and disabled RLS.

Never assume this is a greenfield project. Determine whether the repository is greenfield or an existing implementation.

Before any BUILD action, output a CONTEXT ACQUISITION REPORT containing:
- documents read;
- current architecture;
- codebase state;
- current sprint/CP gate;
- implemented features relevant to the task;
- current database/RLS/GIS/ML state;
- tests currently available;
- gaps and risks;
- likely files affected;
- readiness decision.

Then follow strictly:
THINK → BUILD → REVIEW → FIX → PASS.

Do not proceed to another sprint unless the current gate is PASS with evidence.
Do not fabricate test results or ML metrics.
Do not bypass RLS.
Do not place Supabase service role credentials in Flutter.
Do not fake geospatial travel time or isochrones.
Do not redesign product scope outside PRD without documenting the change.
Do not make a large rewrite merely because you prefer another architecture.

If existing code conflicts with project docs, document the conflict first and resolve it using the source-of-truth precedence defined in AGENTS.md/PROMPTS.md.

At the end, produce a GATE REPORT with evidence and explicitly state whether the next sprint is authorized.
```

---

# 5. SPRINT 0 PROMPT — CP-00 PROJECT FOUNDATION

```text
Execute KOSTARA Sprint 0 / CP-00: Project Foundation.

FIRST: run the full Mandatory Context Acquisition from PROMPTS.md. Read every source-of-truth document and inspect the existing codebase before changing anything. Do not assume the repository is empty.

GOAL:
Create a reproducible, secure, auditable project foundation for KOSTARA without prematurely implementing product features.

THINK:
- Confirm team/project scope and Capstone track PIF683.
- Determine current repository maturity.
- Confirm Flutter and Supabase boundaries.
- Confirm whether Supabase project/config already exists.
- Inspect current environment and secret management.
- Inspect git strategy and uncommitted work.
- Identify initial architectural risks.
- Identify stakeholder/data access assumptions that are not yet validated.
- Confirm that KOSTARA is not framed merely as a listing marketplace.

BUILD only what is appropriate for CP-00:
- Flutter project bootstrap if not already present.
- Environment/config structure without committing secrets.
- Supabase client initialization architecture, if appropriate.
- repository structure aligned with AGENTS.md.
- docs directories.
- project README/run instructions.
- AI_USAGE_LOG template.
- project logbook template.
- risk register template.
- ADR directory/template.
- code formatting/lint baseline.
- initial test harness.
- optional CI baseline if feasible.

DO NOT:
- implement full listing/search/ML flows;
- invent stakeholder evidence;
- create fake dataset/model metrics;
- disable RLS to make connectivity easy.

REVIEW:
- fresh clone/run reproducibility;
- flutter analyze;
- baseline tests;
- secret scan;
- git status;
- dependency sanity;
- documentation consistency.

PASS CRITERIA:
- repo boots reproducibly;
- no secret committed;
- project structure is coherent;
- source-of-truth docs exist and are linked;
- stakeholder/problem hypothesis is explicit but not falsely claimed as validated;
- risk/log/evidence mechanism exists.

Produce CP-00 GATE REPORT.
If any critical foundation issue remains, status is REVIEW FAILED and Sprint 1 is NOT authorized.
```

---

# 6. SPRINT 1 PROMPT — CP-01 PROBLEM & STAKEHOLDER VALIDATION

```text
Execute KOSTARA Sprint 1 / CP-01: Problem and Stakeholder Validation.

FIRST: run Mandatory Context Acquisition. Read all project documents and inspect the current codebase, even though this sprint is research-heavy. Verify what Sprint 0 actually produced instead of trusting previous claims.

GOAL:
Validate that KOSTARA solves a real problem for seekers/tenants and owners, and justify why mobile + recommendation intelligence are needed.

DO NOT jump into feature development.

THINK:
- Identify unvalidated assumptions in PRD.
- Separate evidence from hypotheses.
- Define seeker/tenant stakeholders.
- Define owner stakeholders.
- Define super admin/operator need.
- Determine what decisions recommendation ML will support.
- Determine why plain filters are insufficient or where ML adds measurable value.
- Determine why verified feedback matters.
- Determine why mobile is appropriate.
- Determine what data can realistically be collected legally.

BUILD documentation/evidence artifacts:
- Project Charter;
- Problem Statement;
- stakeholder map;
- interview plan/script;
- interview evidence log;
- current journey;
- pain-point synthesis;
- opportunity statements;
- measurable benefit indicators;
- updated risk register;
- assumptions list with status: validated / rejected / unknown.

If actual stakeholder interviews/data are not available in the repository, DO NOT fabricate them. Create the instruments and mark evidence as pending.

REVIEW:
- Is the problem stated without leading with technology?
- Is each stakeholder real and identifiable?
- Is the primary user decision clear?
- Does ML have a justified task?
- Is GIS useful rather than decorative?
- Is lifecycle after finding a kos validated as a meaningful need?
- Are owner workflows supported by evidence?

FIX:
Refine scope and problem framing based on evidence.
Update PRD only when findings justify the change, with change log/decision note.

PASS CRITERIA:
- real problem evidence exists OR the sprint is correctly marked not ready;
- stakeholder is identifiable;
- measurable benefit indicators exist;
- ML role is justified;
- scope remains feasible in one semester.

Produce CP-01 GATE REPORT and list evidence references.
Do not authorize Sprint 2 unless CP-01 is PASS.
```

---

# 7. SPRINT 2 PROMPT — CP-02 REQUIREMENTS, DATA, ACCEPTANCE CRITERIA

```text
Execute KOSTARA Sprint 2 / CP-02: Requirements, Data, and Acceptance Criteria.

FIRST: perform Mandatory Context Acquisition. Read all docs and inspect existing implementation/schema before drafting new requirements. Do not duplicate or contradict working contracts silently.

GOAL:
Lock a feasible V1 with traceable requirements, role permissions, data strategy, privacy controls, and measurable acceptance criteria.

THINK:
- Reconcile CP-01 evidence with current PRD.
- Identify V1 vs P1 vs V2.
- Map every feature to a user problem.
- Define seeker → tenant lifecycle transition.
- Define owner and super_admin permissions.
- Define review eligibility.
- Define payment reminder behavior.
- Define map/location consent behavior.
- Define recommendation data requirements.
- Define interaction event schema.
- Define NLP review-label taxonomy.
- Define cold-start strategy.
- Define RLS and Storage policy matrix.
- Define offline/slow-network expectations.

BUILD artifacts:
- updated/locked PRD V1;
- functional requirement IDs;
- non-functional requirements;
- user stories;
- acceptance criteria;
- data dictionary v0;
- logical schema draft;
- RLS matrix draft;
- Storage policy plan;
- geospatial data plan;
- ML dataset plan;
- analytics event taxonomy;
- privacy/data-retention notes;
- test plan;
- updated risk register;
- low-fidelity user flows if needed.

Do not implement large production features in this sprint unless necessary to resolve feasibility uncertainty.

REVIEW:
- Every P0 feature must have an owner/user and acceptance criterion.
- No ambiguous role access.
- No unbounded location collection.
- No recommendation requirement without data path.
- No review ML without verified/legally usable training or labeling strategy.
- No acceptance criterion written as vague terms such as "fast", "good", or "accurate" without measurable operational definition.

FIX:
Cut scope if needed. Prefer a complete V1 over too many half-built features.

PASS CRITERIA:
- requirement traceability complete;
- data and permissions feasible;
- RLS matrix coherent;
- ML target/baseline/evaluation plan defined;
- acceptance criteria measurable;
- test plan exists.

Produce CP-02 Requirement Review GATE REPORT.
Sprint 3 is not authorized without PASS.
```

---

# 8. SPRINT 3 PROMPT — CP-03A ALTERNATIVES & ARCHITECTURE

```text
Execute KOSTARA Sprint 3 / CP-03A: Alternative Design and Architecture.

FIRST: perform Mandatory Context Acquisition. Read all source-of-truth files and inspect the real codebase, migrations, RLS, and dependencies. Do not design a second architecture beside an already healthy implementation.

GOAL:
Compare meaningful alternatives, document decisions, and establish a buildable architecture for Flutter, Supabase/PostGIS, ML, map, and notifications.

THINK and compare at least meaningful alternatives for:

1. Flutter architecture/state
- preserve current architecture if justified;
- evaluate feature-first + Riverpod or current alternative;
- avoid rewrite for preference only.

2. Navigation
- inspect existing router;
- define role/lifecycle guards.

3. Supabase
- table/schema boundaries;
- RLS pattern;
- RPC/Edge Function boundaries;
- Storage.

4. GIS/map
- flutter_map / MapLibre-compatible strategy / current library;
- PostGIS query design;
- route/ETA provider only if valid.

5. Recommendation
- popularity/rule baseline;
- content-based baseline;
- hybrid candidate;
- cold-start fallback.

6. Review NLP
- TF-IDF + linear baseline;
- transformer candidate when dataset permits.

7. Notifications
- local scheduled reminders;
- push/server strategy if necessary.

BUILD artifacts:
- architecture diagram;
- module boundaries;
- ERD;
- data-flow diagram;
- RLS design;
- Storage design;
- PostGIS/spatial query design;
- ML training/inference architecture;
- API/inference contracts;
- screen flow;
- high-fidelity core wireframes aligned with DESIGN.md;
- ADRs for important decisions;
- backlog and Definition of Done.

REVIEW:
- Are alternatives actually different and compared using criteria?
- Does chosen architecture fit the 16-week constraint?
- Is service_role isolated server-side?
- Is location data minimized?
- Is ML inference failure handled?
- Is fallback ranking defined?
- Is the mobile app decoupled from model training?
- Are RLS and tenancy transitions enforceable?

FIX architecture debt now, before large implementation.

PASS CRITERIA:
- architecture decisions documented;
- schema/RLS design coherent;
- model/data flow reproducible in principle;
- UI flows align PRD/DESIGN;
- backlog is implementation-ready.

Produce CP-03A GATE REPORT.
```

---

# 9. SPRINT 4 PROMPT — CP-03B PROTOTYPE & ML BASELINES

```text
Execute KOSTARA Sprint 4 / CP-03B: Prototype and ML Baselines.

FIRST: perform full Mandatory Context Acquisition and inspect Sprint 3 artifacts plus actual codebase. Do not rebuild working components simply to match a personal preference.

GOAL:
Reduce the highest technical uncertainty before full CP-04 implementation.

UNCERTAINTIES TO PROVE:
1. auth + role resolution + RLS;
2. spatial storage/query;
3. mobile Explore Map integration;
4. recommendation baseline pipeline;
5. review dataset/label pipeline;
6. end-to-end Flutter ↔ Supabase contract.

THINK:
- identify smallest vertical slices that prove each risk;
- define test/measurement before implementation;
- verify seed data is clearly synthetic/dev-only;
- define reproducible ML experiment config.

BUILD prototype:
- auth baseline;
- seeker onboarding prototype;
- property seed/data pipeline;
- property list/detail;
- campus selection/query;
- Explore Map;
- owner basic add/edit property;
- Supabase schema v1 via migration;
- RLS baseline;
- PostGIS spatial index/query/RPC if used;
- interaction-event capture foundation.

BUILD ML baseline:
- popularity/rule baseline;
- content-based recommendation baseline;
- repeatable train/evaluate script;
- dataset version metadata;
- baseline metrics from REAL experiment only;
- first dataset card;
- review aspect taxonomy;
- labeling guideline;
- NLP baseline only if dataset exists; otherwise document pending data collection without fabricating metrics.

REVIEW:
- execute flutter analyze/tests;
- execute RLS tests across roles;
- validate map coordinates/spatial query;
- reproduce ML metric from clean run;
- inspect leakage/cold-start;
- confirm baseline is integrated or integratable via clear contract.

FIX every P0/P1.

PASS CRITERIA:
- prototype critical slice runs;
- RLS is not bypassed;
- spatial query is demonstrably correct;
- recommendation baseline is reproducible;
- dataset card exists;
- backlog for implementation is locked.

Produce CP-03 Midterm Design Review GATE REPORT with commands/results.
No CP-04 work until PASS.
```

---

# 10. SPRINT 5 PROMPT — CP-04A CORE PRODUCT IMPLEMENTATION

```text
Execute KOSTARA Sprint 5 / CP-04A: Core Product Implementation.

FIRST: perform Mandatory Context Acquisition. Read docs and inspect all existing feature modules, migrations, RLS, tests, and prototype code before changing anything. Preserve validated Sprint 4 contracts unless an ADR justifies change.

GOAL:
Implement the core production journey as a stable vertical product slice.

PRIMARY JOURNEY:
Register
→ Onboarding
→ Discover
→ Explore Map
→ Property Detail
→ Save/Compare
→ Request Tenancy
→ Owner Accept
→ Active Tenancy

THINK:
- map every journey step to existing code and requirement IDs;
- identify incomplete vs missing functionality;
- verify schema before adding tables/columns;
- define transactional consistency for room availability/tenancy;
- define role isolation tests;
- define permission denied/location denied behavior.

BUILD seeker/mobile:
- production auth flow;
- onboarding/preferences;
- home/discovery;
- search/filter;
- current-location nearby with consent;
- campus-aware search;
- Explore Map synchronized with list/filter;
- property detail;
- room detail/availability;
- favorites;
- compare;
- tenancy request.

BUILD owner:
- owner profile/verification state;
- owner dashboard baseline;
- property CRUD;
- room management;
- availability management;
- tenancy request handling.

BUILD backend:
- migration-first schema changes;
- constraints/indexes;
- RLS/storage policies;
- spatial RPC/query;
- analytics interaction events;
- secure image upload.

TEST:
- unit tests;
- widget tests for critical states;
- RLS policy tests;
- integration tests for partial critical journey;
- map permission/slow-network/error state;
- owner vs seeker isolation.

UI must follow DESIGN.md:
- mobile-first;
- no emoji icons;
- no AI-slop dashboard;
- proper loading/empty/error states;
- map controls accessible;
- compact, useful property cards.

REVIEW:
- flutter analyze;
- test suites;
- schema/migration diff;
- RLS matrix;
- storage access;
- map performance;
- image upload behavior;
- regression against prototype contracts.

FIX all P0/P1. Do not carry critical debt into Sprint 6.

PASS CRITERIA:
- `alpha-1` runnable;
- critical journey works through owner acceptance/tenancy creation boundary;
- RLS/role isolation passes;
- map/search stable;
- no secret/service_role in mobile;
- tests and docs updated.

Produce CP-04A GATE REPORT.
```

---

# 11. SPRINT 6 PROMPT — CP-04B ML + TENANCY + PAYMENT + REVIEW INTEGRATION

```text
Execute KOSTARA Sprint 6 / CP-04B: ML, Tenancy, Payment Reminder, Feedback, and Admin Integration.

FIRST: perform Mandatory Context Acquisition. Re-read all docs and inspect current alpha-1 implementation, database, RLS, interaction events, ML experiments, dataset card, model card, and open issues. Do not trust previous summaries without checking the repository.

GOAL:
Complete the product intelligence and long-lifecycle tenant experience while maintaining security and reproducibility.

THINK:
- verify interaction data actually exists and is usable;
- determine whether hybrid recommendation is justified by current data volume;
- if not, retain content-based baseline/fallback and document limitation;
- define inference contract and timeout/failure behavior;
- verify tenancy state transitions;
- verify payment schedule semantics;
- verify review eligibility cannot be forged client-side;
- define how aspect analysis feeds owner insight/recommendation features without leaking private data.

BUILD recommendation:
- run candidate experiment(s);
- compare against baseline using actual metrics;
- select model based on evidence, not novelty;
- version model artifact/config;
- implement inference service/API if needed;
- implement app integration;
- implement fallback ranking;
- implement human-readable recommendation explanation that does not falsely claim probability.

BUILD tenancy/payment:
- active tenancy state;
- room/tenant consistency;
- payment schedule;
- user-selectable reminder timing;
- local/server notification strategy according to architecture;
- payment history/status;
- owner payment visibility constrained by RLS.

BUILD feedback:
- verified tenant eligibility;
- structured aspect ratings;
- free-text review;
- moderation/report path;
- NLP baseline/candidate if dataset supports it;
- aspect sentiment output;
- owner aggregate insight;
- seeker-facing aggregate insight with privacy safeguards.

BUILD super admin:
- owner verification;
- listing moderation;
- report queue;
- platform-level safe model/version visibility if required.

REVIEW ML:
- dataset version;
- train/validation/test split;
- leakage check;
- baseline comparison;
- Precision@K / Recall@K / NDCG@K / Hit Rate as applicable;
- cold-start evaluation;
- coverage;
- NLP Macro F1/Precision/Recall if model exists;
- error analysis;
- inference latency;
- fallback behavior;
- model/dataset card.

REVIEW product/security:
- full RLS matrix;
- tenancy transition integrity;
- review eligibility server-side;
- payment status consistency;
- notification behavior;
- privacy of location/reviews/payment metadata.

FIX every P0/P1 and rerun targeted + regression tests.

PASS CRITERIA:
- function utama integrated;
- selected model or justified baseline integrated;
- no fabricated metric;
- fallback works;
- tenancy/payment/review flows stable;
- verified review cannot be bypassed;
- RLS complete;
- model/dataset reproducibility documented.

Produce CP-04 Implementation Review GATE REPORT.
Sprint 7 is not authorized without PASS.
```

---

# 12. SPRINT 7 PROMPT — CP-05A VERIFICATION, VALIDATION & ERROR ANALYSIS

```text
Execute KOSTARA Sprint 7 / CP-05A: Verification, Validation, and Error Analysis.

FIRST: perform Mandatory Context Acquisition. Read the source-of-truth docs, inspect the actual release state, open issues, migrations, model artifacts, test suite, and prior gate reports.

FEATURE FREEZE IS ACTIVE.
No new feature may be added unless required to satisfy an acceptance criterion or fix a validated defect.

GOAL:
Prove whether KOSTARA meets its requirements and whether the intelligent features improve the intended user decision/support task.

THINK:
- map every P0 requirement to a test/evidence item;
- identify stakeholder validation plan;
- identify ML baseline vs candidate tests;
- define cold-start and sparse-data scenarios;
- define map edge cases;
- define role/security abuse cases;
- define low-end/slow-network mobile cases where feasible.

BUILD/EXECUTE validation:
- functional acceptance tests;
- critical end-to-end flows;
- UX/usability validation;
- stakeholder validation;
- RLS/security tests;
- storage policy tests;
- data integrity tests;
- migration/reproducibility test;
- map/current-location permission edge cases;
- spatial query boundary cases;
- recommendation baseline vs candidate evaluation;
- cold-start evaluation;
- coverage/robustness analysis;
- NLP baseline vs candidate evaluation where applicable;
- confusion/error analysis;
- inference failure/fallback tests;
- performance measurements relevant to acceptance criteria.

Collect evidence:
- commands;
- logs;
- screenshots when useful;
- test output;
- stakeholder feedback;
- failed cases;
- model errors;
- known limitations.

REVIEW:
Compare actual results with PRD acceptance criteria. Do not reinterpret target after seeing weak results without documenting a formal change.

FIX:
Only validated defects and critical usability/security/data/model issues.
After each fix, rerun targeted tests and relevant regressions.

PASS CRITERIA:
- acceptance evidence is traceable;
- all P0/P1 failures resolved or the gate remains failed;
- baseline comparisons are reproducible;
- limitations and negative results are disclosed;
- stakeholder validation evidence exists when feasible;
- security/RLS test evidence exists.

Produce CP-05A Validation GATE REPORT plus an acceptance traceability matrix.
```

---

# 13. SPRINT 8 PROMPT — CP-05B RELEASE, DOCUMENTATION, DEMO & EXPO

```text
Execute KOSTARA Sprint 8 / CP-05B: Release Candidate, Documentation, Demo, and Expo.

FIRST: perform Mandatory Context Acquisition. Re-read all docs, inspect release branch/state, git status, open issues, final migrations, model versions, test evidence, and prior CP-05A report.

NO UNNECESSARY REFACTOR.
Focus on stability, reproducibility, documentation, and evidence.

GOAL:
Produce a final artifact that can be installed, demonstrated repeatedly, audited, and defended academically.

THINK:
- identify release blockers only;
- verify versioning/tag strategy;
- verify demo data does not expose private user data;
- verify model artifacts and metrics match final report;
- verify database migrations can reproduce environment;
- verify backup/restore/runbook;
- verify known limitations.

BUILD final release artifacts:
- final Android build;
- reproducible environment instructions;
- tagged release;
- final Supabase migrations;
- backup/restore plan;
- runbook;
- demo-safe seed/sample data where permitted;
- technical README;
- user manual;
- architecture documentation;
- data dictionary;
- dataset card;
- model card;
- API/inference contract;
- AI usage log;
- changelog;
- contribution report;
- final report inputs;
- poster inputs;
- 3–5 minute video script/material;
- presentation material;
- demo script.

FINAL SMOKE FLOW:
new seeker
→ onboarding
→ personalized recommendation
→ search/explore map
→ property detail
→ save/compare
→ request tenancy
→ owner accepts
→ active tenancy
→ payment reminder
→ verified feedback
→ owner feedback insight

Also validate super_admin moderation/verification flow.

REVIEW:
- clean build/install;
- flutter analyze/tests;
- end-to-end smoke;
- migrations reproduce database;
- RLS still enabled and passing;
- no secret in repository/build artifacts;
- recommendation fallback works;
- model metrics in docs match actual artifact;
- final report does not claim untested functionality;
- demo can be repeated without manual database patching.

FIX:
Only release blockers and validated defects.
No late experimental feature.

PASS CRITERIA:
- product stable;
- demo repeatable;
- build reproducible;
- metrics reproducible;
- documentation matches final implementation;
- known limitations disclosed;
- Capstone evidence complete;
- individual contribution evidence available.

Produce FINAL CP-05 GATE REPORT and explicitly state RELEASE CANDIDATE PASS or REVIEW FAILED.
```

---

# 14. CONTINUATION / RESUME PROMPT

Gunakan saat AI agent berhenti di tengah sprint dan session baru dimulai.

```text
Resume the current KOSTARA sprint from the repository state, not from memory.

Do not assume the previous agent summary is correct.

1. Read AGENTS.md, PRD.md, DESIGN.md, SPRINTS.md, VALIDATION_PROTOCOL.md, PROMPTS.md, README.md.
2. Inspect git status, current branch, recent commits, changed/untracked files.
3. Inspect the code relevant to the current sprint.
4. Read the latest gate report/logbook/changelog/ADR if present.
5. Run or inspect the last relevant tests.
6. Identify what is DONE, PARTIAL, FAILED, and NOT STARTED from actual evidence.
7. Produce a CONTEXT ACQUISITION REPORT.
8. Continue from the first unresolved item using THINK → BUILD → REVIEW → FIX → PASS.

Do not duplicate finished implementation.
Do not overwrite unrelated uncommitted changes.
Do not mark PASS based solely on previous prose; require current evidence.
```

---

# 15. FEATURE IMPLEMENTATION PROMPT TEMPLATE

```text
Implement KOSTARA feature: <FEATURE NAME>
Sprint: <SPRINT>
Requirement/AC: <IDS>

Before coding:
- read all source-of-truth docs;
- inspect the entire relevant code path in the current repository;
- inspect schema/migrations/RLS/storage/RPC involved;
- inspect tests and existing design components;
- identify whether similar functionality already exists;
- produce Context Acquisition Report.

THINK:
Explain current behavior, desired behavior, affected users, architecture impact, database/RLS/privacy/GIS/ML impact, failure states, test plan, and rollback risk.

BUILD:
Implement the smallest coherent change that satisfies the requirement and follows existing healthy conventions.

REVIEW:
Run static analysis and all targeted tests. Validate role isolation, loading/error/empty states, small-screen UX, and regression risks.

FIX:
Fix all P0/P1 and rerun review.

PASS:
Return evidence and state whether the feature is safe to merge.
```

---

# 16. DATABASE / RLS MIGRATION PROMPT

```text
Work on KOSTARA database/RLS change: <CHANGE>

Do not modify schema before inspecting all existing migrations, constraints, functions, triggers, indexes, policies, and code consumers.

Mandatory:
1. Read source-of-truth docs.
2. Inspect codebase and all relevant migrations.
3. Determine backward compatibility.
4. Produce THINK plan.

Rules:
- migration-first;
- never edit historical applied migration to fake a clean history unless project rules explicitly allow it;
- never disable RLS;
- never use policy USING(true)/WITH CHECK(true) as a shortcut without explicit public-data rationale;
- service_role stays server-side;
- use constraints for invariant enforcement;
- test positive AND negative authorization cases;
- document rollback/recovery for risky changes;
- add spatial indexes for geospatial columns where justified;
- verify query plan/performance where relevant.

Required review matrix:
- anonymous;
- seeker;
- verified tenant state;
- owner of target property;
- other owner;
- super_admin;
- server/service path if applicable.

Return migration files, policy rationale, tests, and PASS/FAIL evidence.
```

---

# 17. ML EXPERIMENT PROMPT — RECOMMENDATION

```text
Execute a KOSTARA recommendation-system experiment.

Before modeling:
- read PRD/AGENTS/SPRINTS/VALIDATION/PROMPTS;
- inspect existing datasets, interaction schema, preprocessing scripts, model artifacts, and previous experiment logs;
- verify data source/permission/version;
- verify train/validation/test strategy;
- check for leakage.

Do not fabricate data volume or metrics.

Experiment contract:
1. Define user decision/task.
2. Define dataset version.
3. Define features.
4. Define baseline.
5. Define candidate model.
6. Define cold-start strategy.
7. Define offline metrics such as Precision@K, Recall@K, NDCG@K, Hit Rate, coverage where appropriate.
8. Define reproducible seed/config/dependencies.
9. Train/evaluate.
10. Perform error analysis.
11. Compare candidate against baseline.
12. Record limitations and fairness/representation risks.
13. Export/version artifact only if justified.
14. Update model card and experiment log.

Do not call a score a probability unless calibrated as one.
Do not force a hybrid/collaborative model when interaction data is insufficient.
Fallback must remain deterministic and useful.

Return evidence, not marketing language.
```

---

# 18. ML EXPERIMENT PROMPT — REVIEW NLP

```text
Execute a KOSTARA aspect-based review analysis experiment.

Before modeling:
- inspect review eligibility and privacy rules;
- inspect actual labeled dataset and aspect taxonomy;
- verify only legally usable data is included;
- inspect prior preprocessing/model scripts;
- verify class distribution and annotation quality.

Required baseline:
- TF-IDF + linear classifier or another documented simple baseline.

Candidate:
- Indonesian transformer only if dataset size/quality and compute make it reasonable.

Evaluate:
- Macro F1;
- per-class Precision/Recall/F1;
- confusion matrix;
- aspect-level error analysis;
- robustness to spelling/slang where relevant.

Do not invent NLP metrics when labeled data is unavailable.
If data is insufficient, produce a labeling/data-collection plan and keep feature in baseline/rule or pending state instead of pretending a trained model exists.

Update dataset/model card and return PASS/FAIL evidence.
```

---

# 19. UI/UX IMPLEMENTATION PROMPT

```text
Implement/review KOSTARA UI screen or flow: <SCREEN/FLOW>

Before changing UI:
- read DESIGN.md completely;
- read relevant PRD flow/acceptance criteria;
- inspect existing theme, typography, spacing, reusable components, navigation, state, and current screen implementation;
- inspect business logic so the UI refactor does not break system behavior.

Design requirements:
- Flutter mobile-first;
- calm, modern property utility;
- Plus Jakarta Sans if project assets/dependency support it;
- no emoji as icons;
- no excessive gradients/glow/glass;
- not every section is a rounded card;
- useful information hierarchy;
- map/list synchronization when applicable;
- recommendation explanation focused on benefit, not AI jargon;
- verified evidence/trust signals;
- complete loading/empty/error/offline/permission states;
- keyboard-safe forms;
- small-screen responsive behavior;
- accessible tap targets/contrast/semantics.

Do not alter schema/RLS/API contracts merely to simplify UI unless separately justified and reviewed.

Run widget/interaction tests where appropriate and return design-review evidence.
```

---

# 20. REVIEW-ONLY PROMPT

Gunakan bila ingin AI agent mengaudit tanpa mengubah kode dulu.

```text
Perform a REVIEW-ONLY audit of the current KOSTARA repository for <SCOPE>.

Do not modify files yet.

1. Read all source-of-truth docs.
2. Inspect the relevant codebase and dependencies.
3. Check git status.
4. Trace current behavior end-to-end.
5. Inspect tests.
6. Inspect schema/RLS/storage/RPC if relevant.
7. Inspect ML/GIS contracts if relevant.

Report findings by severity:
P0 Critical
P1 Major
P2 Moderate
P3 Cosmetic

For each issue include:
- evidence/file location;
- why it matters;
- requirement/acceptance impact;
- recommended fix;
- regression risk;
- validation required after fix.

Do not invent issues from assumptions.
Do not edit code until explicitly moving into FIX/BUILD.
```

---

# 21. FIX PROMPT

```text
Fix the validated KOSTARA issues from the latest review.

Before modifying:
- re-read the review findings;
- inspect current git diff/status;
- re-open affected code and docs;
- verify no unrelated changes appeared since review.

Fix priority:
1. P0
2. P1
3. gate-blocking P2

For every fix:
- identify root cause;
- make minimal coherent change;
- add/update tests;
- run targeted validation;
- run relevant regression validation.

Do not hide the symptom.
Do not weaken RLS/security to pass tests.
Do not alter acceptance criteria to make the failure disappear.

After fixes, rerun REVIEW and produce updated GATE REPORT.
```

---

# 22. FINAL CAPSTONE AUDIT PROMPT

```text
Perform the final Capstone audit of KOSTARA.

Read every project document and inspect the final codebase from scratch.
Do not rely on previous summaries.

Audit against:
- CP-00 to CP-05 evidence;
- PRD acceptance criteria;
- PIF683 AI requirements;
- repository reproducibility;
- dataset/model versioning;
- baseline and alternative-model evidence;
- ML evaluation and error analysis;
- model integration in application;
- responsible AI/privacy;
- RLS/security;
- geospatial correctness;
- user/owner/admin critical flows;
- deployment/demo readiness;
- user manual;
- technical documentation;
- contribution evidence;
- AI usage log;
- known limitations.

Explicitly detect contradictions between:
- report vs actual implementation;
- claimed metrics vs experiment artifacts;
- schema docs vs migrations;
- UI docs vs app;
- model card vs deployed model;
- claimed features vs demonstrable features.

Return:
1. readiness summary;
2. P0/P1/P2/P3 findings;
3. acceptance traceability gaps;
4. evidence gaps;
5. exact fixes required before final review;
6. final PASS/REVIEW FAILED decision.

Never declare PASS if a claimed critical feature cannot be reproduced or demonstrated.
```

---

# 23. AGENT WORK HABITS — NON-NEGOTIABLE

AI agent harus membiasakan pola berikut setiap kali bekerja:

```text
READ DOCS
↓
READ CODEBASE
↓
TRACE CURRENT BEHAVIOR
↓
CHECK GIT STATUS
↓
THINK
↓
BUILD SMALL COHERENT CHANGE
↓
RUN TESTS
↓
REVIEW
↓
FIX ROOT CAUSE
↓
RERUN TESTS
↓
PASS WITH EVIDENCE
```

Yang dilarang:

```text
Receive prompt
↓
Guess architecture
↓
Generate many files
↓
Ignore existing code
↓
Skip tests
↓
Declare done
```

---

# 24. DEFINITION OF A GOOD AI AGENT SESSION

Session dianggap baik jika agent:

- bisa menjelaskan kondisi codebase sebelum mengubahnya;
- menyebut file nyata yang relevan;
- tidak menduplikasi sistem yang sudah ada;
- tidak merusak migration/RLS;
- tidak membuat scope creep;
- membuktikan hasil dengan test/evidence;
- membuat perubahan yang dapat direview;
- mencatat keputusan penting;
- menjaga alignment dengan Capstone;
- tahu kapan harus berhenti karena gate belum PASS.

Session dianggap buruk jika output hanya berupa banyak kode tanpa inspeksi, alasan, test, atau evidence.

---

# 25. FINAL RULE

**KOSTARA tidak dikerjakan dengan pola “prompt → generate → lanjut”.**

KOSTARA dikerjakan sebagai proyek engineering dan Capstone yang dapat dipertanggungjawabkan:

> **Understand the repository. Understand the problem. Build deliberately. Verify objectively. Fix what fails. Proceed only on PASS.**
