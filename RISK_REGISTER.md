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
| R-010 | Model bias ke listing populer | Medium | Medium | Content metadata + coverage metric + cold-start analysis | Open | 2026-09-25 |
