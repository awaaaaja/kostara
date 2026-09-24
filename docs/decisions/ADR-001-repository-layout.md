# ADR-001 — Repository layout: single app at repo root

Status: Accepted
Date: 2026-09-25

## Context
AGENTS.md §8 menawarkan baseline `apps/mobile/`, `supabase/`, `docs/`, dll., tetapi juga menyatakan: jangan memindahkan file hanya demi mengikut contoh; buat ADR bila struktur berbeda. Repo ini berisi docs + satu aplikasi mobile Flutter.

## Options
1. Baseline penuh: `apps/mobile/` + root docs — struktur monorepo multi-app.
2. App di root (`lib/`, `pubspec.yaml` di root) + `supabase/`, `docs/`, `data/` — single-app repo.

## Decision
Opsi 2: app di root. Docs source-of-truth tetap di root; `supabase/`, `docs/`, `data/` tetap sesuai baseline AGENTS.md.

## Consequences
- `flutter create/test/analyze` berjalan langsung dari root (reproducible, sederhana).
- Bila kelak ada app kedua (mis. admin web), pertimbangkan migrasi ke `apps/` dengan ADR baru.

## Validation
- CP-00 REVIEW: flutter analyze + flutter test dari root PASS; struktur coherent.
