# CP-03A — Screen Flow & Navigation Architecture

Date: 2026-09-25
Status: mengikat — route table + guards jadi dasar `core/router` (CP-03B).
Alur kasar per jalur kritis = `cp02-flows.md`; visual = `cp03a-wireframes.md`;
spesifikasi layar = DESIGN.md §11–§35.

---

## 1. Route table (go_router)

### 1.1 Public / pre-shell

| Path | Layar | Guard |
|---|---|---|
| `/login`, `/register` | auth (ToS+consent inline, FR-AUTH-01/06) | sudah sesi → redirect ke shell role |
| `/onboarding/seeker` | wizard preferensi (FR-ONB-01) | sesi seeker tanpa `user_preferences` wajib lewat sini |
| `/onboarding/owner` | info status pending + upload dokumen | sesi role owner |

### 1.2 Seeker/Tenant shell (bottom nav DESIGN §11)

| Path | Layar | Catatan |
|---|---|---|
| `/home` | feed rekomendasi + near campus + tenancy card (jika ada) | recommendation fallback state (DESIGN §35) |
| `/explore` | tab list ⇄ map (satu state filter) | debounce, near-me JIT |
| `/saved` | favorites tergroup | refresh availability saat dibuka |
| `/tenancy` | status request / kartu tenancy / empty informatif | derived status, tanpa inbox (FR-NOT-02) |
| `/profile` | profil, settings, consent | `/profile/settings`, `/profile/privacy` |
| `/property/:id` | property detail (di luar shell, ada back) | sticky CTA |
| `/compare` | compare ≤3 | dari saved/explore |
| `/property/:id/request` | form tenancy request | butuh sesi seeker |
| `/tenancy/:id/payment` | riwayat pembayaran | RLS participation |
| `/tenancy/:id/reminder` | setup reminder (offsets) | local notif |
| `/tenancy/:id/review` | final review (8 aspek) | eligibility server-side |

### 1.3 Owner shell (DESIGN §12)

| Path | Layar |
|---|---|
| `/owner/home` | dashboard ringkas (okupansi, due soon, requests) |
| `/owner/properties` | daftar property + FAB add (hanya di sini) |
| `/owner/property/new` · `/owner/property/:id` | wizard 7 langkah (DESIGN §29): basic → location (pin) → rooms → facilities → photos → rules → publication |
| `/owner/tenants` | requests (terima/tolak) + tenant aktif |
| `/owner/payments` | due list + tandai paid |
| `/owner/profile` | profil + status verifikasi |

### 1.4 Super admin shell (DESIGN §13)

| Path | Layar |
|---|---|
| `/admin/overview` | counters + antrian |
| `/admin/verification` · `/admin/verification/:id` | antrian owner+listing; detail: evidence, approve/reject(+reason), audit |
| `/admin/reports` | reports & review moderasi |
| `/admin/models` | ringkasan event/model_versions (read-only) |
| `/admin/profile` | profil admin |

## 2. Redirect algorithm (satu tempat — `router/redirect.dart`)

```text
onNavigation(location):
  session? ─ no ─→ /login  (kecuali tujuan publik)
      │ yes
      ▼
  profile loaded? ─ no ─→ /splash (tunggu probe roles dari DB)
      │ yes
      ▼
  status = 'suspended'? ─ yes ─→ /suspended
      │ no
      ▼
  role:
    seeker  → belum ada user_preferences? → /onboarding/seeker
              sedang di rute owner/admin?  → /home
    owner   → di rute seeker-only?         → /owner/home
              (verification pending TIDAK memblokir app; listing publish
               ditolak server-side → banner status di owner home)
    super_admin → shell /admin/* (boleh juga akses shell lain? TIDAK —
               admin adalah role tunggal, tanpa dual-use di V1)
```

Prinsip: guard klien = UX (cegah layar salah); **guard sesungguhnya = RLS/RPC**
( server selalu menganggap klien hostile ). Route review/tenancy divalidasi
server saat data di-load (403 → state error yang sopan, bukan crash).

## 3. Screen-flow diagram per momen kritis

```text
A. First run
/register(ToS+consent) → auth ok → role seeker → /onboarding/seeker (9 langkah
  ringkas, bisa dilewati? TIDAK utk field wajib) → save prefs → /home (feed
  loading skeleton → success | empty rekomendasi → ajakan Explore)

B. Discovery → keputusan
/home → ketuk search → /explore?focus=search → filter sheet (sticky "Tampilkan N")
  → list ⇄ map (state sama) → [Near me: pre-prompt → sistem dialog →
  granted: nearby RPC; denied: tombol nonaktif + hint kampus] →
  /property/:id → (favorit ♥) → compare ≤3 → /property/:id/request →
  status pending muncul di /tenancy

C. Owner siklus
/owner/home → banner "Perlu verifikasi" → /onboarding/owner upload →
  (admin verify) → /owner/property/new (pin peta) → submit pending →
  admin verify listing → publik → /owner/tenants: activate_tenancy (atomik) →
  /owner/payments: mark paid → tenant melihat status sama (AC-PAY-06)

D. Reminder → review → loop
tenancy aktif → /tenancy/:id/reminder (offset 7/3/1/0) → local notif saat jatuh
  tempo → owner mark paid → … → owner end_tenancy → /tenancy/:id/review
  (8 aspek, teks ≤1000) → pending → /admin/reviews approve → publik
  "Penghuni terverifikasi • Mon YYYY" → NLP batch → aspect_scores →
  owner dashboard ringkasan aspek → (loop discovery utk pencari berikutnya)

E. Privasi
/profile/privacy → tarik consent (konfirmasi) → data_consent_at=NULL →
  event berhenti; ajukan hapus akun → guard: tenancy aktif → ditolak dgn pesan
```

## 4. State contract per layar data

Semua layar data memakai pola provider yang sama (AGENTS §9.3):

```text
AsyncValue → loading: skeleton (DESIGN §33)
           → data: success | empty (ajakan aksi, DESIGN §34)
           → error: kategori error + retry (DESIGN §35); input form TIDAK hilang
offline: banner + cache terakhir (AC-OFF-01)
```

Map state terpisah dari filter state namun sinkron (AGENTS §9.6): satu
`DiscoveryFilterController`; `MapViewportController` hanya memegang kamera +
marker hasil query terakhir.

## 5. Aksesibilitas & breakpoint (wajib saat implementasi)

touch target 44–48dp; label semantic; tanpa state warna-saja; uji 360×800 /
390×844 / 430×932 + text-scale 200% (DESIGN §37–§39) — masuk Definition of Done
`cp03a-backlog.md`.
