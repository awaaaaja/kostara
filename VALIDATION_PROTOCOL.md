# VALIDATION_PROTOCOL.md — KOSTARA

Protocol ini wajib untuk setiap phase, sprint, feature besar, database migration, ML experiment, dan release.

Core loop:

# THINK → BUILD → REVIEW → FIX → PASS

**Hanya status PASS yang mengizinkan langkah berikutnya.**

---

# 1. Why This Exists

Capstone KOSTARA tidak boleh berkembang dengan pola:

```text
prompt AI
→ kode banyak
→ kelihatan jalan
→ lanjut feature berikut
```

Pola wajib:

```text
Pahami masalah
→ rancang perubahan
→ implementasi
→ audit hasil
→ temukan masalah
→ perbaiki
→ ulang audit
→ PASS
→ lanjut
```

---

# 2. Gate Status

Hanya ada:

## NOT READY
THINK belum lengkap.

## BUILDING
Implementasi berlangsung.

## REVIEW FAILED
Ada issue yang membuat acceptance tidak terpenuhi.

## FIXING
Issue sedang diperbaiki.

## PASS
Semua exit criteria wajib terpenuhi.

Tidak ada status "cukup lah" atau "sementara dianggap beres".

---

# 3. Severity

## P0 — Critical

Contoh:

- data leak;
- auth bypass;
- service role leak;
- destructive data corruption;
- app crash pada critical path;
- fabricated ML result.

Gate otomatis FAIL.

## P1 — Major

Contoh:

- main acceptance criteria gagal;
- wrong recommendation contract;
- invalid tenancy transition;
- RLS salah;
- payment state inconsistent;
- map result salah.

Gate FAIL.

## P2 — Moderate

Contoh:

- secondary UI defect;
- non-critical performance issue;
- minor accessibility gap.

Boleh deferred hanya jika dicatat dan tidak memengaruhi gate akademik/core acceptance.

## P3 — Cosmetic

Contoh:

- spacing minor;
- microcopy.

Dapat masuk polish backlog.

---

# 4. Universal THINK Checklist

Sebelum BUILD:

- [ ] masalah/goal dijelaskan
- [ ] user/role diketahui
- [ ] requirement ID diketahui
- [ ] acceptance criteria diketahui
- [ ] current behavior diinspeksi
- [ ] dependency diinspeksi
- [ ] data impact dianalisis
- [ ] RLS impact dianalisis
- [ ] privacy impact dianalisis
- [ ] ML impact dianalisis
- [ ] UX impact dianalisis
- [ ] failure states dipikirkan
- [ ] test plan dibuat
- [ ] rollback plan tersedia jika berisiko

Jika salah satu kritis belum jelas → NOT READY.

---

# 5. Universal BUILD Checklist

- [ ] perubahan minimal dan fokus
- [ ] no secret
- [ ] schema via migration
- [ ] RLS dibuat bersama feature
- [ ] loading/error/empty state
- [ ] logging aman
- [ ] test ditambahkan
- [ ] docs diperbarui bila contract berubah
- [ ] no fake data pada final production path
- [ ] no bypass sementara tersisa

---

# 6. Universal REVIEW Checklist

## Code

- [ ] format
- [ ] analyze/lint
- [ ] unit test
- [ ] widget/integration test sesuai scope
- [ ] dead code check
- [ ] dependency review

## Product

- [ ] acceptance criteria
- [ ] correct role
- [ ] no unexpected scope change

## UX

- [ ] small screen
- [ ] loading
- [ ] empty
- [ ] error
- [ ] permission
- [ ] accessibility
- [ ] keyboard
- [ ] long content

## Backend

- [ ] migration review
- [ ] constraint
- [ ] RLS matrix
- [ ] storage policy
- [ ] idempotency bila dibutuhkan

## ML

- [ ] real dataset version
- [ ] valid split
- [ ] metric from actual run
- [ ] baseline comparison
- [ ] error analysis
- [ ] model artifact version
- [ ] fallback behavior

---

# 7. FIX Rules

Saat REVIEW gagal:

1. catat issue;
2. assign severity;
3. cari root cause;
4. perbaiki;
5. jalankan targeted tests;
6. jalankan regression yang relevan;
7. kembali ke REVIEW.

Jangan hanya menutupi gejala.

---

# 8. PASS Evidence

Setiap PASS harus memiliki evidence.

Contoh:

```text
Gate: Discovery Map V1
Commit: abc123
Tests:
- flutter analyze PASS
- flutter test PASS
- spatial RPC tests PASS
- permission denied flow PASS

Manual:
- Android 360dp PASS
- Android 430dp PASS

Known P2:
- marker cluster animation jitter

Decision:
PASS
```

---

# 9. Phase Gate — CP-00

THINK:

- siapa tim?
- apa masalah hipotesis?
- siapa stakeholder?
- apa jalur Capstone?
- apa repository?

PASS jika:

- repo siap;
- team/role siap;
- project boundaries siap;
- stakeholder outreach siap;
- no critical unknown about project feasibility.

---

# 10. Phase Gate — CP-01

PASS jika:

- masalah dibuktikan;
- stakeholder jelas;
- owner pain dibuktikan;
- seeker pain dibuktikan;
- ML use-case justified;
- benefit metrics ada;
- scope awal feasible.

FAIL jika satu-satunya alasan adalah:

`kami ingin membuat aplikasi kos dengan AI`.

---

# 11. Phase Gate — CP-02

PASS jika:

- V1 jelas;
- requirement traceable ke problem;
- data requirement jelas;
- legal/permission data dipikirkan;
- acceptance criteria;
- test plan;
- privacy;
- RLS matrix;
- risk register.

---

# 12. Phase Gate — CP-03

PASS jika:

- minimal dua alternative solution bermakna dibandingkan;
- architecture documented;
- prototype mengurangi risiko teknis;
- recommender baseline berjalan;
- metric pipeline berjalan;
- data card draft ada;
- UX flow validated;
- backlog implementasi locked.

---

# 13. Phase Gate — CP-04

PASS jika:

- main app works;
- core repository clean;
- environment reproducible;
- model integrated;
- fallback works;
- RLS complete;
- unit/integration tests;
- no P0/P1;
- security review.

---

# 14. Phase Gate — CP-05

PASS jika:

- setiap acceptance criterion punya evidence;
- baseline vs selected model compared;
- error analysis;
- limitation;
- stakeholder validation;
- stable demo;
- manual;
- release;
- report matches actual product;
- poster/video/demo ready.

---

# 15. Flutter Feature Gate

Untuk feature UI:

THINK:

- screen state;
- source data;
- actions;
- failure.

BUILD:

- page/component;
- state management;
- repository integration;
- states.

REVIEW:

- 360dp;
- 430dp;
- loading;
- empty;
- error;
- accessibility;
- test.

FIX until PASS.

---

# 16. Supabase Feature Gate

THINK:

- table;
- ownership;
- relationship;
- RLS;
- constraint.

BUILD:

- migration;
- index;
- policy;
- function/RPC if needed.

REVIEW matrix:

| Actor | Select | Insert | Update | Delete |
|---|---:|---:|---:|---:|
| Anonymous | test | test | test | test |
| Seeker own | test | test | test | test |
| Seeker other | test | test | test | test |
| Owner own | test | test | test | test |
| Owner other | test | test | test | test |
| Admin | test | test | test | test |

PASS hanya jika akses sesuai requirement.

---

# 17. GIS Gate

PASS jika:

- point stored correctly;
- SRID correct;
- index exists;
- near query validated;
- map viewport query validated;
- permission denied fallback;
- location not tracked in background;
- travel time source valid or hidden;
- attribution displayed according to provider terms.

---

# 18. Recommendation ML Gate

## THINK

- target user decision;
- features;
- event meaning;
- baseline;
- split;
- metrics.

## BUILD

- dataset pipeline;
- baseline;
- candidate;
- experiment tracking.

## REVIEW

- no leakage;
- baseline metric;
- candidate metric;
- cold-start;
- coverage;
- error cases;
- bias to popularity;
- inference.

## FIX

Iterate only on demonstrated errors.

## PASS

Model selected based on evidence, not complexity.

---

# 19. NLP Review Gate

PASS jika:

- aspect taxonomy fixed;
- label guideline exists;
- dataset source and permission known;
- class distribution inspected;
- baseline evaluated;
- candidate evaluated;
- low confidence handling;
- insufficient evidence handling;
- output integrated without altering original review.

---

# 20. Tenancy Gate

PASS if:

- only legitimate owner can accept;
- accepted request creates valid tenancy;
- room occupancy consistent;
- tenant can read own data;
- other seeker cannot read it;
- owner other cannot read it;
- end tenancy works;
- repeat request edge cases handled.

---

# 21. Payment Reminder Gate

PASS if:

- due date derives from tenancy;
- timezone correct;
- custom reminder correct;
- schedule update regenerates reminders;
- duplicate reminder avoided;
- no false "paid";
- owner/tenant state consistent.

---

# 22. Review Gate

PASS if:

- non-tenant blocked;
- tenant eligibility enforced server-side;
- review link to tenancy;
- public identity minimized;
- owner cannot edit tenant review content;
- moderation does not silently rewrite review.

---

# 23. Admin Gate

PASS if:

- admin authentication strong;
- privileged access audited;
- reject requires reason where relevant;
- owner/listing state transitions valid;
- no admin-only secret exposed to app client.

---

# 24. Release Gate

Before final release:

```text
flutter analyze
flutter test
integration test
RLS test
migration from clean DB
migration from previous DB
ML inference smoke test
map smoke test
notification smoke test
Android release build
```

Manual demo:

```text
Seeker flow
Owner flow
Admin flow
Offline/error flow
ML fallback flow
```

---

# 25. Stop Conditions

Stop immediately if:

- P0 security issue;
- data loss risk;
- unapproved private data exposure;
- fabricated metric;
- model result cannot be reproduced;
- RLS disabled;
- repository contains secret;
- final report differs materially from running artifact.

---

# 26. Review Report Template

```markdown
# Review — <Feature/Phase>

Date:
Reviewer:
Commit:

## Requirement
...

## Evidence
...

## Tests
- [ ] ...

## Issues
| ID | Severity | Issue | Status |
|---|---|---|---|

## Fixes
...

## Known Limitations
...

## Decision
PASS / NOT PASS

## Next Step
...
```

---

# 27. Final Rule

Jika AI agent menulis:

`Sudah selesai`

tetapi tidak dapat menunjukkan evidence REVIEW dan PASS, maka task **belum selesai**.
