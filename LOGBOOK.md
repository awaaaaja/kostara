# Project Logbook — KOSTARA

Log kronologis keputusan, sprint, dan bukti. Ringkas; detail di commit/gate report.

## Template

```markdown
## <YYYY-MM-DD> — <Sprint/aktivitas>
- Status:
- Bukti:
- Catatan/risiko:
```

---

## Entries

## 2026-09-25 — Context Acquisition + Sprint 0 (CP-00)
- Status: **PASS** — gate report: `docs/logs/CP-00-gate-report.md`
- Bukti: commits `6453eb1` (docs) + `d47b15c` (foundation); format/analyze/test PASS;
  fresh clone PASS (Aman.md absent, analyze clean, 1/1 test); secret scan clean;
  Supabase project ada (ref kmlaajbmjarsyjccnvna) — kredensial hanya di Aman.md
- Catatan: stakeholder/data access BELUM divalidasi (menunggu CP-01);
  jangan klaim sebaliknya

## 2026-09-25 — Sprint 1 / CP-01 Problem & Stakeholder Validation
- Status: **NOT PASS awal (evidence 0) → evidence masuk (sekunder/proxy E-001/E-002, diverifikasi agent) → PASS** — gate report: `docs/logs/CP-01-gate-report.md`
- Bukti: H-01..H-05 terdukung; A-01..A-06 validated / A-07..A-09 unknown;
  verifikasi sumber: Mamikos Help Center resmi (iklan stale), OpenKOS/KostEZ/SuperKos/kospay (pain owner);
  risk +R-015/R-016; R-011 mitigasi parsial
- Catatan: evidence = **secondary/proxy, BUKAN wawancara primer** — dilarang
  diklaim lain di laporan. Primer Padang disarankan sebelum CP-03 (R-011/R-016).
  Sprint 2 (CP-02) AUTHORIZED.

## 2026-09-25 — Sprint 2 / CP-02 Requirements, Data, Acceptance Criteria
- Status: **PASS** — gate report: `docs/logs/CP-02-gate-report.md`
- Bukti: 12 artefak `docs/capstone/cp02-*` (scope lock, requirements 56 FR ·
  72 AC · traceability, NFR, data dictionary, schema draft 22 tabel + constraint,
  RLS matrix 6 aktor + 4 storage bucket, geospatial distance-only, ML data plan
  (baseline/split/taxonomy/labeling), events taxonomy, privacy (tutup A-07),
  test plan, lo-fi flows); PRD status → **LOCKED V1** + §31; risk +R-017..R-020,
  R-015 → Mitigated
- Catatan: V1 = P0; pulse/push/bukti-bayar/travel-time/isochrone = P1
  (`cp02-scope-lock.md`). A-09 ditutup dengan keputusan distance-only.
  Review ML-2 bergantung ToS v1.0 lisensi UGC (R-017, task CP-04A).
  Sprint 3 (CP-03A) AUTHORIZED.
