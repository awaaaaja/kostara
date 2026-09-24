# Risk Register — KOSTARA

Diperbarui minimal setiap sprint. Kolom: ID, Risk, Impact, Likelihood, Mitigation, Status, Since.

| ID | Risk | Impact | Likelihood | Mitigation | Status | Since |
|---|---|---|---|---|---|---|
| R-001 | Tidak cukup interaction data untuk hybrid CF | High | High | Content-based strong baseline + pilot instrumentation (PRD §29) | Open | 2026-09-25 |
| R-002 | Review text terlalu sedikit untuk NLP | High | High | Structured aspect rating + labeled pilot dataset; dokumentasikan batasan | Open | 2026-09-25 |
| R-003 | Location permission ditolak | Medium | Medium | Campus/manual location search fallback | Open | 2026-09-25 |
| R-004 | Routing API tidak tersedia → ETA gagal | Medium | Medium | Fallback distance-only; jangan fake ETA | Open | 2026-09-25 |
| R-005 | RLS salah → data leak | Critical | Medium | RLS matrix test wajib sebelum gate PASS; tidak pernah disable RLS | Open | 2026-09-25 |
| R-006 | Secret bocor ke repository | Critical | Low | Aman.md + .env di .gitignore; secret scan tiap REVIEW | Open | 2026-09-25 |
| R-007 | Scope terlalu besar → deadline gagal | High | Medium | Disiplin V1/P1/V2; quality gate > sprint calendar | Open | 2026-09-25 |
| R-008 | Metric ML direkayasa → integritas akademik gagal | Critical | Low | Semua metric direproduksi dari experiment artifact; dilarang (AGENTS §4.4) | Open | 2026-09-25 |
| R-009 | Stakeholder tidak tersedia untuk CP-01 | High | Medium | Interview plan dibuat; evidence ditandai pending bila belum ada | Open | 2026-09-25 |
| R-010 | Model bias ke listing populer | High | Medium | Content metadata + coverage metric + cold-start analysis | Open | 2026-09-25 |
| R-011 | Evidence CP-01 tidak terkumpul → gate terblokir, sprint bergeser | Critical | High | Instrumen siap (`docs/capstone/cp01-interview-plan.md`); jadwalkan 3-5 seeker + 2-3 owner; gate hanya dievaluasi ulang dengan evidence nyata | Open | 2026-09-25 |
| R-012 | Rekrutmen partisipan sulit (sukarela, jadwal kuliah) | Medium | Medium | Kanal grup kampus/UKM; sesi 20-40 menit; tawarkan ringkasan hasil anonim | Open | 2026-09-25 |
| R-013 | A-05 ditolak (filter sudah cukup) → scope ML-1 turun | High | Medium | Baseline popularity/content tetap bisa jadi POCP; putuskan di CP-03 berdasarkan evidence, bukan preferensi teknologi | Open | 2026-09-25 |
| R-014 | Bias instrumen interview (leading question) merusak evidence | High | Low | Script netral (`cp01-interview-plan.md` §2-4); larangan menyebut "AI" di pembuka; kutipan dicatat apa adanya | Open | 2026-09-25 |
