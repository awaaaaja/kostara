# ADR-002 — Flutter: feature-first + Riverpod + go_router

Status: Accepted
Date: 2026-09-25

## Context
CP-00 hanya menyiapkan foundation (`main.dart` placeholder + `AppConfig` guard);
belum ada state management/navigation untuk dipertahankan. PRD §18 merekomendasikan
Riverpod + go_router. AGENTS §9 mewajibkan feature-first, state lengkap
(loading/success/empty/error), dan guard role di routing.

## Options
1. **Feature-first + Riverpod + go_router redirect guards.**
2. Pertahankan MaterialApp + setState tanpa state mgmt.
3. Bloc/Cubit (event-driven).
4. Full clean architecture (UseCase/Domain layer penuh + get_it).

## Decision
Opsi 1. Struktur `lib/core/*` + `lib/features/*` (kontrak di
`cp03a-architecture.md` §2); repository = satu-satunya lapisan yang menyentuh
Supabase; `AsyncValue` menjadi state baku tiap layar data; satu
`redirect` terpusat (session → onboarding → role shell) — guard klien untuk UX,
guard sesungguhnya tetap RLS/RPC.

## Consequences
- (+) sesuai rekomendasi PRD/AGENTS; komunitas besar; testable tanpa mock berat;
  tanpa dependency ekstra selain yang sudah direkomendasikan.
- (−) Riverpod mudah "bocor" ke widget bila tidak disiplin → review melarang
  bisnis logic kompleks di widget (AGENTS §9.2).
- Ditolak: Bloc (ceremony tanpa gain di skala ini), clean-architecture penuh
  (berat utk 16 minggu).

## Validation
- Alternatif dibandingkan dengan kriteria di `cp03a-alternatives.md` §1–2.
- Diverifikasi saat gate CP-03B: analyze/test lulus, route guard diuji
  TP-AUTH-*, state kosong/error tiap layar.
