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
