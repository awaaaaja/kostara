# CP-03A — Alternative Design & Architecture — GATE REPORT

Date: 2026-09-25
Sprint 3 (weeks 5-6) · Prompt: `PROMPTS.md` §8 · Status: **PASS**

---

## 1. Context acquisition (dijalankan sebelum THINK)

- Source of truth: AGENTS, PRD (LOCKED V1 §31), DESIGN (dibaca penuh 956 baris),
  SPRINTS (CP-03A), VALIDATION_PROTOCOL, PROMPTS §8, README.
- Codebase aktual: `lib/` = `main.dart` (foundation placeholder) +
  `core/config/app_config.dart` (guard `assertNoServiceRole`) — **tanpa router,
  tanpa state management, tanpa fitur** → tidak ada arsitektur sehat yang perlu
  dipertahankan; "avoid rewrite for preference" tidak berlaku (belum ada yang
  ditulis). Dependensi: `supabase_flutter` saja.
- Artefak CP-02 dikonsumsi sebagai kontrak masukan: schema draft (22 tabel),
  RLS matrix 6 aktor, geospatial distance-only, ML data plan, requirements
  56 FR · 72 AC, test plan, flows.
- `supabase/migrations/` masih kosong (belum ada schema dieksekusi — wajar);
  ADR-001 (layout) + template ada; `Aman.md` **masih 0 byte** (tidak relevan
  utk gate ini — desain murni; jadi blocker CP-03B, lihat §6).

## 2. BUILD — artefak yang dihasilkan

| Artefak | Isi | Deliverable SPRINTS |
|---|---|---|
| `cp03a-alternatives.md` | 7 topik alternatif (arch/state, nav, Supabase boundary, map+ETA, recommendation serving, NLP, notif) dgn kriteria F/R/B/M/K | THINK |
| `cp03a-architecture.md` | diagram sistem + kontrak modularitas feature-first + 6 data-flow + mapping 16 minggu + non-goals | architecture diagram |
| `cp03a-erd.md` | ERD 23 tabel + justifikasi tiap constraint → AC | ERD |
| `cp03a-backend-design.md` | katalog pola RLS P1–P7 + helper anti-recursion + SQL template; storage policy template; PostGIS query template + indeks + EXPLAIN; boundary RPC/Edge/klien; room state-machine trigger | RLS policy design |
| `cp03a-api-contracts.md` | kontrak RPC discovery/rec/tenancy/payment/admin + repository map + inference contract (training→params→RPC) + NLP batch contract + event contract | prototype API contracts |
| `cp03a-screen-flow.md` | route table 3 shell + redirect algorithm + alur kritis A–E + state contract | screen flow |
| `cp03a-wireframes.md` | 10 wireframe hi-fi (token warna/tipografi/spacing DESIGN) W1–W10 | high fidelity wireframe |
| `cp03a-backlog.md` | backlog CP-03B/04A/04B/05A/05B tiap task bawa FR/AC/TP + Definition of Done | backlog + DoD |
| ADR-002..006 | feature-first+Riverpod+go_router · map distance-only+PostGIS · Supabase boundary · ML training/serving · notifications local-first | ADRs |
| (rujuk) `cp02-ml-data-plan.md` | ML experiment plan + dataset schema sudah terkunci di CP-02 — tidak ditulis ulang (hindari duplikasi sumber kebenaran) | ML plan/dataset schema |

## 3. REVIEW — checklist pertanyaan gate

| Pertanyaan | Jawaban | Bukti |
|---|---|---|
| Alternatif benar-benar beda & dibandingkan pakai kriteria? | **Ya** — tiap topik ≥3 opsi berbeda material (mis. serving: SQL-RPC vs klien vs FastAPI vs prakomputasi), dinilai 5 kriteria seragam | `cp03a-alternatives.md` |
| Arsitektur fit 16 minggu? | **Ya** — mapping per sprint; V1 = 0 Edge Function, 0 service hosting, 0 dependency ekstra di luar rekomendasi PRD; P1/P2 tidak dibangun "untuk jaga-jaga" | `cp03a-architecture.md` §8–9 |
| service_role terisolasi server-side? | **Ya** — hanya ENV pipeline/CI; app anon key + guard `assertNoServiceRole()`; fungsi definer memakai trust DB, bukan key; TP-SEC-01 scan APK | ADR-004, api-contracts §3b |
| Location data diminimalkan? | **Ya** — 0 kolom lokasi user (jujur di skema); GPS = argumen RPC sesaat; bbox hanya metadata; JIT + tanpa background | backend-design §3, api-contracts §2 |
| Kegagalan inference ML ditangani? | **Ya** — params hilang/error → RPC fallback / client `sort='popularity'` + log `baseline-fallback` + state UI "tidak tersedia" | architecture §4, ADR-005 |
| Fallback ranking terdefinisi? | **Ya** — rantai cold-start preferensi→CB→geo→verified→popularity; feed tak-pernah-kosong (AC-REC-01/03) | api-contracts §3 |
| App decoupled dari training? | **Ya** — app hanya memanggil RPC; training offline menulis `model_versions`+`model_params`; model artifact tak pernah di-ship ke app | ADR-005 |
| RLS & transisi tenancy enforceable? | **Ya** — pola P1–P7 + helper anti-recursion; partial unique (1 tenancy aktif/kamar, 1 pending/room); composite FK reviews; `activate_tenancy` atomik+idempotent; room state-machine trigger | backend-design §1/§4, erd §3 |
| Reason for choices documented? | ADR-001..006 + alternatif | `docs/decisions/` |
| No unnecessary infra? | V1 tanpa Edge/FCM/FastAPI/Realtime | architecture §9 |
| Map provider terms understood? | OSM raster: atribusi wajib + hormati usage policy; komersial = P1 dgn lisensi | ADR-003 |

## 4. FIX — debt arsitektur yang diperbaiki sekarang (sebelum implementasi besar)

1. **Kerentanan rekursi RLS `profiles`** (policy membaca profiles) → helper
   `app_current_role()` SECURITY DEFINER STABLE + grant dikecualikan (backend-design §1.2).
2. **Privasi kolom profil tidak bisa diekspresikan policy** → design view
   `profiles_public` (kolom display saja) di atas base table yang terkunci.
3. **Coupling model↔app** dihindari sejak awal → tabel baru `model_params`
   (delta 22→23, dicatat di ERD) sebagai interface training↔serving.
4. Repo hygiene: `supabase/.temp/` → gitignore; `pubspec.yaml` deskripsi
   placeholder → nama produk; referensi salah `FR-PERF-*` → `NFR-PERF-*`.
5. Audit silang otomatis: 13 TP & seluruh FR/AC/NFR yang dirujuk artefak CP-03A
   **ada** di test plan/requirements/NFR (0 missing).

## 5. Validation (perintah & hasil)

```text
flutter analyze          → No issues found!            PASS
flutter test             → All tests passed (1/1)      PASS
audit referensi TP/FR/AC/NFR (python)                  PASS (0 missing)
secret scan (cp03a + ADR) → tanpa pola rahasia         PASS
emoji scan (wireframe)    → bersih (ikon, bukan emoji) PASS
RLS matrix                → N/A (desain; eksekusi CP-03B)
ML evaluation             → N/A (belum eksperimen)
```

## 6. Remaining risks / catatan

- **`Aman.md` masih 0 byte** → untuk CP-03B butuh kredensial (isi Aman.md)
  atau `supabase login` + `supabase link --project-ref kmlaajbmjarsyjccnvna`.
- R-001/R-002 (volume data/label) → C1–C4 boleh berstatus "pending data",
  dilarang mengarang metrik.
- R-017 ToS v1.0 (A10) blocking legal training ML-2.
- R-019 free tier → wajib EXPLAIN+pagination (B6/B15).
- P2 (tercatat, tidak blocking): upgrade MapLibre bila perf gagal; clustering
  server-side bila payload >500 row; FastAPI bila gate ADR-005 terpenuhi.

## 7. Gate decision

```text
architecture decisions documented ......... PASS (ADR-002..006 + alternatif)
schema/RLS design coherent ................. PASS (23 tabel, pola P1–P7, helper)
model/data flow reproducible in principle .. PASS (export→seed→train→params→RPC, seed/lock)
UI flows align PRD/DESIGN .................. PASS (route table + 10 wireframe vs DESIGN)
backlog implementation-ready ............... PASS (FR/AC/TP per task + DoD)

STATUS: PASS → Sprint 4 / CP-03B (Prototype & ML Baselines) AUTHORIZED.
```

Catatan otorisasi: CP-03B adalah gate pertama yang **menyentuh Supabase nyata**
(migration pertama); kredensial harus tersedia sebelum B1 dijalankan.
