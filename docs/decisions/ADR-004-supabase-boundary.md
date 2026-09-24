# ADR-004 — Supabase boundary: RLS-first + SECURITY DEFINER RPC; Edge reserved

Status: Accepted
Date: 2026-09-25

## Context
CP-02 mengunci 22→23 tabel dengan matrix RLS 6 aktor. FR atomik (AC-TEN-01
transaksi accept, AC-TEN-02 idempoten, AC-ADM-06 audit wajib) tidak bisa
dijamin oleh check-then-write dari klien. AGENTS §4.3/§10 melarang RLS
dimatikan & policy `true`.

## Options
1. **Hybrid: CRUD via tabel+RLS; transaksi/invariant/query agregasi via RPC;
   Edge Function hanya utk logika ber-secret; pipeline ML offline.**
2. Client-direct saja (semua lewat tabel) — transaksi mustahil atomik.
3. Semua operasi via Edge Functions (JS) — logika terpisah dari constraint SQL.
4. Backend REST terpisah (FastAPI) sebagai primary — membatalkan nilai Supabase.

## Decision
Opsi 1, dengan aturan tegas (`cp03a-backend-design.md` §1.5):
- **SECURITY DEFINER**: activate/end tenancy, mark paid, regenerate reminders,
  aksi admin + `audit_logs` — cek ownership/role DI DALAM fungsi, satu
  transaksi, `search_path` eksplisit, execute di-revoke dari public.
- **SECURITY INVOKER** (RLS tetap jalan): `search_properties`,
  `feed_recommendations`, `nearby_properties` — agregasi/ranking server-side.
- Helper `app_current_role()` SECURITY DEFINER anti-recursion (wajib; policy
  profiles tidak boleh membaca profiles).
- **Edge Functions: nol pemakaian V1**, direserve utk P1 (push/outbox/webhook).
- `profiles` publik via **view `profiles_public`** (kolom display saja) — policy
  RLS tidak bisa membatasi per kolom.

## Consequences
- (+) invariant di DB (bukan harapan app); testable via TP-RLS/TP-TEN; audit tak
  bisa dipalsukan klien; tanpa infra ekstra di 16 minggu.
- (−) fungsi definer = attack surface lebih luas → wajib review grant/grant +
  test matrix; view profiles harus dijaga kolomnya (migrasi = review otomatis).
- service_role: hanya ENV pipeline/CI — tidak pernah di Flutter
  (`assertNoServiceRole` + TP-SEC-01 scan APK).

## Validation
- Gate CP-03B: RLS matrix 6 aktor × S/I/U/D lulus; TP-TEN-01/02 (rollback +
  idempoten); TP-SEC-01; TP-STOR-01/02.
