# AI Usage Log — KOSTARA

Catat setiap penggunaan AI yang berdampak pada artefak project (lihat AGENTS.md §5).
Jangan masukkan data pribadi tenant, dokumen verifikasi, credentials, atau kode mitra rahasia.

## Template

```markdown
### Entry — <YYYY-MM-DD>
- Tool/model:
- Tujuan:
- Bagian yang dibantu:
- File/artefak terdampak:
- Cara verifikasi:
- Perubahan manual setelah output AI:
- Risiko/keterbatasan:
```

---

## Entries

### Entry — 2026-09-25
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: Context acquisition + Sprint 0 / CP-00 project foundation
- Bagian yang dibantu: repo bootstrap, docs scaffolding, guarded Supabase config, test/CI baseline
- File/artefak terdampak: .gitignore, pubspec.yaml, lib/, test/, docs/, supabase/, README.md, .github/workflows/
- Cara verifikasi: flutter analyze (No issues) + flutter test (1/1) + secret scan + fresh clone — CP-00 GATE REPORT: docs/logs/CP-00-gate-report.md (PASS)
- Perubahan manual setelah output AI: deprecated `anonKey` → `publishableKey`, import/annotation dibersihkan saat REVIEW
- Risiko/keterbatasan: foundation only — belum ada fitur produk, schema, atau RLS; stakeholder belum divalidasi (CP-01)

### Entry — 2026-09-25 (Sprint 1 / CP-01)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: CP-01 problem & stakeholder validation (dokumen & instrumen; NOL data fabrikasi)
- Bagian yang dibantu: charter, problem statement hipotesis, stakeholder map, interview script, evidence log template, journey/pain hypothesis, benefit indicators, assumptions register, risk update, gate report
- File/artefak terdampak: docs/capstone/cp01-*.md, RISK_REGISTER.md, LOGBOOK.md, docs/logs/CP-01-gate-report.md
- Cara verifikasi: evidence log = 0 entri (sengaja); semua H-xx/A-xx berstatus hipotesis/unknown; gate NOT PASS
- Perubahan manual setelah output AI: REVIEW checklist PROMPTS §6 dijalankan; tidak ada PRD diubah (belum ada findings)
- Risiko/keterbatasan: gate terblokir sampai wawancara nyata dijalankan pemilik project (R-011)

### Entry — 2026-09-25 (CP-01 evaluasi ulang setelah evidence)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: memproses evidence proxy/sekunder dari owner + verifikasi sumber + evaluasi ulang gate CP-01
- Bagian yang dibantu: evidence log (E-001/E-002 dengan provenance), assumptions 6/0/3, problem statement diperkuat, journey/pains terdukung, benefit indicators directional, gate report PASS dgn limitasi, risk register update
- File/artefak terdampak: docs/capstone/cp01-*.md, RISK_REGISTER.md, LOGBOOK.md, docs/logs/CP-01-gate-report.md
- Cara verifikasi: 3 websearch agent (Mamikos help center resmi; OpenKOS GitHub; KostEZ/SuperKos/kospay) mengonfirmasi klaim inti; angka anekdit Reddit ditandai tak-terverifikasi; flutter analyze/test PASS
- Perubahan manual setelah output AI: label sekunder konsisten di semua artefak; larangan klaim "hasil wawancara primer" ditulis di gate report & logbook
- Risiko/keterbatasan: A-07/A-08/A-09 unknown; evidence primer Padang belum ada (R-011/R-016)

### Entry — 2026-09-25 (Sprint 2 / CP-02)
- Tool/model: opencode / mimo-v2.6-flash-free
- Tujuan: CP-02 requirements/data/acceptance — mengunci V1 yang terlacak dari bukti CP-01
- Bagian yang dibantu: scope lock V1/P1/P2, 48 FR + 66 AC + traceability matrix, NFR terukur, data dictionary & schema draft (constraint), RLS matrix + storage policy, rencana geospatial (distance-only), rencana dataset/evaluasi ML-1 & ML-2 (termasuk taxonomy & strategi labeling), taxonomy event + bobot interaksi, privacy/consent (tutup A-07), test plan, lo-fi flow, lock header PRD + §31, risk update, gate report
- File/artefak terdampak: docs/capstone/cp02-*.md (12), PRD.md, RISK_REGISTER.md, LOGBOOK.md, docs/logs/CP-02-gate-report.md
- Cara verifikasi: audit otomatis REVIEW (traceability FR→AC→TP, kata vague di AC, kepatuhan data path ML, keterbacaan lokasi-bounded, matrix coverage) + flutter analyze/test regression + secret scan — hasil di gate report
- Perubahan manual setelah output AI: keputusan scope (P1: pulse/push/bukti bayar/travel time) direkonsiliasi ke PRD §31; bobot interaction tetap ditandai hipotesis
- Risiko/keterbatasan: draft schema/RLS belum dieksekusi (migration = CP-03B/04A); ToS v1.0 lisensi UGC masih task (R-017); jumlah data train/label NLP belum diketahui (R-001/R-002)
