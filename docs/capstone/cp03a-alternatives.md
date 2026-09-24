# CP-03A — Perbandingan Alternatif Arsitektur

Date: 2026-09-25
Status: input THINK untuk ADR-002..006 (keputusan = ADR; file ini = kriteria & opsi).
Kriteria evaluasi dipakai bersama: **(F)** fit 16 minggu · **(R)** risiko teknis ·
**(B)** biaya/licensi · **(M)** maintenance · **(K)** kesesuaian requirement/PRD.

---

## 1. Flutter architecture & state

| Opsi | Deskripsi | F | R | B | M | K |
|---|---|---|---|---|---|---|
| **A. Feature-first + Riverpod** (PRD §18) | folder per feature; Riverpod `AsyncNotifier` untuk state; repository per feature di atas Supabase | ✅ tinggi | rendah (pola mapan) | 0 (sudah rekomendasi resmi) | sedang | ✅ |
| B. Pertahankan apa adanya (setState, tanpa state mgmt) | lanjuti `main.dart` foundation | ❌ | tinggi (state loading/error per layar jadi ad-hoc) | 0 | cepat rusak | ❌ NFR state wajib (AGENTS §9.3) |
| C. Bloc/Cubit | event-driven, ceremony lebih banyak | ⚠️ mungkin | rendah | paket baru | sedang | ✅ tapi tanpa keunggulan di sini |
| D. Full clean architecture (UseCase/Domain layer penuh) | layer ekstra per feature | ❌ berat utk 16 mgg | rendah | 0 | berat | ✅ berlebihan |

**Catatan penting:** tidak ada implementasi sehat yang boleh di-preserve — codebase baru
punya `main.dart` placeholder + 1 file config (CP-00 foundation only). "Jangan rewrite
untuk selera" tidak berlaku karena belum ada yang ditulis. Opsi A dipilih (ADR-002).

## 2. Navigation

| Opsi | Deskripsi | F | R | B | M | K |
|---|---|---|---|---|---|---|
| **A. go_router + redirect guards** | declarative, cocok dgn auth/role state Riverpod | ✅ | rendah | 0 (rekomendasi PRD) | sedang | ✅ |
| B. Navigator 1.0 manual (`pushNamed`) | imperative | ✅ | sedang — guard tersebar di tiap layar, mudah bolong | 0 | mudah bocor | ⚠️ role guard sulit diuji |
| C. auto_route (codegen) | annotation → router | ✅ | sedang — codegen ekstra | paket baru | OK | ✅ tapi tanpa gain di 16 mgg |

**Keputusan:** A (ADR-002). Guard: session → onboarding → role shell → lifecycle
(route detail tenancy/review divalidasi server, bukan hanya guard klien).

## 3. Supabase boundary (CRUD / RPC / Edge Function)

| Opsi | Deskripsi | F | R | B | M | K |
|---|---|---|---|---|---|---|
| **A. Hybrid: RLS-first + SECURITY DEFINER RPC** | CRUD biasa = tabel + RLS; transaksi/invariant (accept request, bayar, feed) = RPC | ✅ | rendah (invariant di DB) | 0 | sedang | ✅ semua FR atomik terpenuhi |
| B. Client-direct saja (tanpa RPC) | semua lewat tabel + RLS | ✅ | ❌ transaksi multi-tabel (AC-TEN-01) & anti double-booking mustahil atomik dari klien | 0 | mudah salah | ❌ |
| C. Semua lewat Edge Functions | setiap operasi via fungsi server | ⚠️ | rendah | 0 | tinggi (banyak JS logic terpisah dari SQL) | ✅ tapi berlebihan; DB jadi kurang dipercaya |
| D. Backend REST terpisah (FastAPI) sebagai primary | Supabase hanya DB | ❌ | tinggi (hosting, auth bridge, 2 stack) | $ server | tinggi | ✅ tapi membatalkan nilai Supabase |

**Keputusan:** A (ADR-004). Edge Function direserve untuk logika **ber-secret** di masa
depan (mis. webhook push P1); V1 tidak butuh satu pun — pipeline ML jalan offline
dengan key di environment server (bukan repo, bukan app).

## 4. GIS / Map

| Opsi | Deskripsi | F | R | B | M | K |
|---|---|---|---|---|---|---|
| **A. flutter_map + tile raster OSM** | plugin ringan, pure Dart widget | ✅ | rendah | gratis (wajib atribusi + hormati tile usage policy) | rendah | ✅ |
| B. MapLibre native (vector tiles) | performa/clustering lebih baik | ✅ | sedang — setup platform (android/ios) + binary size | tile server sendiri/portal utk production | sedang | ✅ |
| C. Google Maps SDK / Mapbox | fitur matang | ✅ | rendah | ⚠️ API key + billing + terms ketat | sedang | ✅ tapi over budget V1 |
| D. Tanpa peta interaktif (list only) | — | ✅ | 0 | 0 | 0 | ❌ FR-MAP-01..05 wajib |

**Keputusan:** A untuk V1; B dicatat sebagai upgrade path bila clustering/perf
gagal diuji (ADR-003). Query spasial **server-side di PostGIS** — peta hanya
membawa bbox/argumen, bukan data koordinat seluruh kota (AGENTS §10.5).

### 4b. Route/ETA provider

| Opsi | Kelayakan V1 |
|---|---|
| **A. Distance-only (tanpa provider)** | ✅ dipilih — A-09 unknown, tanpa risiko lisensi/ETA palsu (AGENTS §4.5) |
| B. OSRM self-host | ❌ butuh server + maintenance, di luar 16 mgg |
| C. Directions API komersial | ❌ butuh budget + attribution + A-09 belum divalidasi |

P1 hanya bila tiga syarat `cp02-geospatial-plan.md` §4 terpenuhi.

## 5. Recommendation — bagaimana model disajikan ke aplikasi

| Opsi | Deskripsi | F | R | B | M | K |
|---|---|---|---|---|---|---|
| **A. Scoring di SQL RPC + parameter model dari training offline** | `feed_recommendations` menghitung skor deterministik (bobot/fitur dari tabel `model_params`); training Python menulis parameter | ✅ | rendah | 0 (tanpa hosting inferensi) | rendah | ✅ |
| B. Scoring di klien (Dart) | app menghitung ranking dari kandidat | ✅ | sedang — logika scoring bocor + update model = rilis app | 0 | tinggi | ⚠️ |
| C. FastAPI inference service | model ML dijalankan sebagai service | ❌ | tinggi (hosting, cold start, availability) | $ + waktu | tinggi | ✅ tp V1 baseline (popularity/CB) tidak butuh |
| D. Prakomputasi user×property offline | tabel skor per user | ⚠️ | sedang — sparse besar, stale saat listing baru | 0 | tinggi | ⚠️ listing baru = skor basi |

**Model ladder** (dari `cp02-ml-data-plan.md`, tidak diulang): baseline A popularity →
baseline B content-based → hybrid (dipilih di CP-04B berdasar metrik, bukan selera).
Opsi C dibuka kembali hanya bila hybrid terpilih **dan** tidak bisa diekspresikan
sebagai parameter SQL (gate di ADR-005). Cold-start & fallback rantai: preferensi →
content-based → geo → verified → popularity; RPC gagal → client memakai
`search_properties` sort populer + `model_version='baseline-fallback'` (AC-REC-03).

## 6. Review NLP

| Opsi | Deskripsi | F | R | B | M | K |
|---|---|---|---|---|---|---|
| **A. Batch offline: lexicon baseline → TF-IDF + linear (bertahap)** | pipeline Python, output tulis `review_aspect_scores` via key server | ✅ | rendah | 0 | rendah | ✅ |
| B. Transformer (indoBERT sejenis) langsung | akurasi potensial lebih tinggi | ⚠️ | tinggi — label & data belum ada (R-002), biaya komputasi | $ | tinggi | ⚠️ hanya bila data memadai |
| C. NLP realtime saat review disubmit | inference saat submit | ❌ | tinggi (latensi, failure di flow utama) | 0 | tinggi | ❌ FR-ML-02 tidak mensyaratkan realtime |

**Keputusan:** A; B = kandidat ber-gate dataset (ADR-005). Gagal → ringkasan memakai
structured rating saja (AGENTS §11.7). Teks review tidak pernah diubah.

## 7. Notifications

| Opsi | Deskripsi | F | R | B | M | K |
|---|---|---|---|---|---|---|
| **A. Local scheduled (flutter_local_notifications + tz Asia/Jakarta)** | jadwal dibuat saat schedule berubah | ✅ | rendah | 0 | rendah | ✅ FR-NOT-01 |
| B. Server push (FCM) sekarang | lintas device + server outbox | ⚠️ | sedang (setup FCM, background handler, outbox table) | 0 | sedang | ✅ tp P1 per scope lock |
| C. Hybrid: local + outbox sejak V1 | dua mekanisme serentak | ❌ | ganda di 16 mgg | 0 | tinggi | berlebihan |

**Keputusan:** A (ADR-006); B = P1 (`notification_outbox` menyusul). Batasan jujur:
notifikasi lokal hanya berbunyi bila device menerima jadwal — dicatat di UX reminder.

---

## Rekap keputusan → ADR

| Topik | Opsi menang | ADR |
|---|---|---|
| Architecture/state + navigation | Feature-first + Riverpod + go_router guards | ADR-002 |
| Map + spatial query | flutter_map + PostGIS server-side, distance-only | ADR-003 |
| Supabase boundary | RLS-first + SECURITY DEFINER RPC, Edge reserved | ADR-004 |
| Recommendation serving + NLP pipeline | SQL scoring + training offline, batch NLP | ADR-005 |
| Notification | Local scheduled V1, push P1 | ADR-006 |
