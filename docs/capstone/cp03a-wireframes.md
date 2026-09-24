# CP-03A — High-Fidelity Core Wireframes

Date: 2026-09-25
Status: referensi implementasi — **DESIGN.md tetap sumber visual utama**; wireframe
ini menerjemahkan §11–§32 ke layout + token. Anotasi memakai token DESIGN §4–§7:
`[P]` Primary #176B52 · `[PD]` Primary Dark #0F4F3C · `[PS]` Primary Soft #DDEAE4 ·
`[ACC]` Accent #D9A447 · `[BG]` #F7F6F2 · `[SF]` Surface #FFFFFF ·
`[T1]` Text #18221E · `[T2]` #66736D · `[LN]` #DDE2DE · `[DGR]` #B94343 ·
`[WRN]` #B07822 · `[SUC]` #25785D · `[INF]` #326B91. Tipografi Plus Jakarta Sans;
radius: button/input 12, card 16, sheet 20-top, chip 10–12. Ikon = ikon (emoji dilarang).

---

## W1 — Register (FR-AUTH-01/06, DESIGN §40 bahasa)

```text
┌────────────────────────────────────┐
│  (back)                            │  h-padding 20dp [BG]
│                                    │
│  Buat akun KOSTARA                 │  H1 26/32 700 [T1]
│  Cari, bandingkan, dan kelola kos  │  Body 14 [T2]
│                                    │
│  ┌──────────────────────────────┐  │
│  │ Email                        │  │  Input h48 r12 [SF] border [LN]
│  └──────────────────────────────┘  │  error: teks 12 [DGR] di bawah field
│  ┌──────────────────────────────┐  │
│  │ Password            (eye)    │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │ Saya adalah:                 │  │  segmented r12: [Pencari kos][Pemilik]
│  │  ( ● Pencari kos ○ Pemilik ) │  │  selected: fill [PS], teks [PD] 650
│  └──────────────────────────────┘  │
│                                    │
│  ☑ Saya menerima Syarat & Ketentuan │  Checkbox 20dp; link [P] underline
│     v1.0 dan Kebijakan Data        │  wajib dicentang → tombol aktif
│                                    │
│  ┌──────────────────────────────┐  │
│  │         Daftar                │  │  Button h52 r12 [P], teks [SF] Body L
│  └──────────────────────────────┘  │  disabled: [LN]/[T2]
│  Sudah punya akun?  Masuk          │  Body [T2] + label [P]
└────────────────────────────────────┘
States: submit → button spinner; gagal → banner [DGR] dekat field, input TIDAK
direset (AC-AUTH-03). Tidak ada opsi role super_admin (AC-AUTH-04).
```

## W2 — Onboarding preferensi (FR-ONB-01)

```text
┌────────────────────────────────────┐
│ ←   Langkah 2 dari 6         ████░ │  progress bar 4dp [P] / [LN]
│                                    │
│  Budget per bulan                  │  H2 22/28 700 [T1]
│  Pilih rentang agar hasil relevan  │  Body [T2]
│                                    │
│  Rp 800.000  ─────●──────●  Rp 1.500.000   │  dual slider, thumb 24dp [P]
│  [Rp800.000] – [Rp1.500.000]       │  value chip [SF] border [LN] Body 650
│                                    │
│  Kampus utama                      │  Label 12/16 650 [T1]
│  ┌──────────────────────────────┐  │
│  │ (ikon kampus) Unand ...      ▾   │  │  select r12 → bottom sheet pilihan
│  └──────────────────────────────┘  │
│  Fasilitas prioritas (maks 4)      │  chip r10: selected [PS]/[PD] 650
│  [WiFi] [KM dalam] [Parkir] [AC]   │  unselected [SF] border [LN] [T2]
│                                    │
│  Transportasi:  (● Jalan kaki)     │
│                 (○ Motor) (○ Mobil)│
│  ──────────────────────────────    │
│  [Lewati]            [Lanjut → ]   │  primary kanan; Lewati teks [T2]
└────────────────────────────────────┘
Catatan: setiap langkah punya validasi inline; jawaban TIDAK hilang saat back.
```

## W3 — Seeker Home (DESIGN §14)

```text
┌────────────────────────────────────┐
│ Halo, Rina                (ikon)  │  Greeting Body L 500 [T1]; avatar = ikon
│                                    │  profil 36dp, BUKAN emoji
│ ┌────────────────────────────────┐ │
│ │ (ikon cari) Kos dekat kampus…  │ │  search field h48 r12 [SF] border [LN]
│ └────────────────────────────────┘ │
│ (chip) Unand ⌄   (chip) ±2 km  [Ubah] │ chip r10 [PS]/[PD]; konteks utama
│                                    │
│ Rekomendasi untukmu         Lihat  │  H3 18/24 650 [T1]  ·  aksi [P] Body
│ ┌─────────┐ ┌─────────┐ ┌──── →    │  kartu horizontal w220 r16 [SF]
│ │ [foto]  │ │ [foto]  │ │          │  ┌ cover 4:3 r14 (atas), badian [SF]
│ │ ♥       │ │ ♥       │ │          │  │ badge "Skor kecocokan 92/100" chip
│ │ Kos Melati│ │ Griya C   │ │        │  │   [PS] [PD] 650 12/16 (AC-REC-04)
│ │ Rp950.000/bln│ │Rp1,2jt/bln│   │  │ · nama H3 2 baris max · harga 650
│ │ ±1,2 km dari Unand │ ...    │    │  │ · "Kenapa cocok ⌄" teks [P] 12
│ │ ⭐4,8 (21) · Tersedia  │        │  │ · fasilitas maks 3 chip kecil [T2]
│ └─────────┘ └─────────┘ └──── →    │
│                                    │
│ Dekat kampus kamu                  │  section kedua: list compact 2 kolom
│ ┌──────┐ ┌──────┐                  │  atau card lebar h96
│ │[img] │ │[img] │                  │
│ └──────┘ └──────┘                  │
│ ┌────────────────────────────┐     │
│ │ Sewa aktif · Kamar A2      │     │  kartu tenancy (hanya bila ada) [PS]
│ │ Jatuh tempo 17 Okt · Rp950k│     │  aksi "Lihat" [P]
│ └────────────────────────────┘     │
├────────────────────────────────────┤
│  [Beranda][Jelajah][Tersimpan][Sewa][Profil] │ bottom nav h64+safe [SF],
└────────────────────────────────────┘  ikon 24dp + label 12; aktif [P]
States: skeleton shimmer utk 2 section atas; rec gagal → card fallback dgn
banner [INF] "Rekomendasi personal sedang tidak tersedia" (DESIGN §35);
empty (tanpa listing) → empty state + [Jelajah].
```

## W4 — Explore Map (DESIGN §17, full-screen canvas)

```text
┌────────────────────────────────────┐
│ ┌────────────────────┐ ┌────────┐  │  overlay top: search pill h44 r12 [SF]
│ │ (cari) area/kampus │ │ Filter │  │  tombol Filter chip [SF]+ikon; badge
│ └────────────────────┘ └────┬───┘  │  jumlah filter [ACC]
│         [ peta — tile raster, penuh ] │  marker harga: pill r10 [SF] border
│       ⌖(campus lain)  [Rp950k] [Rp1,2jt] │  selected: [P] fill, teks [SF]
│              [Rp850k]                 │  marker kampus: ikon beda [INF]
│    ⌖(kampus)        ● lokasi saya     │  current location: standar biru
│                                    │
│ ┌────────────────────────────────┐ │
│ │  ◀ ┌──────┐ Kos Melati         │ │  bottom sheet drag 20-top r [SF]
│ │    │[foto]│ Rp950.000/bln      │ │  preview card: img 72dp r14 + info
│ │    └──────┘ ±1,2 km · ★4,8     │ │  swipe horizontal ⇄ sinkron marker
│ │  ●○○   [Lihat detail →]        │ │  indicator dot [LN]/[P]
│ └────────────────────────────────┘ │
│         [ Gunakan area ini ]        │  tombol "Search this area" muncul
├────────────────────────────────────┤  SETELAH gesture berhenti ≥300ms
│  nav bawah dlm keadaan tersembunyi │  (hanya tampil saat sheet collapse)
└────────────────────────────────────┘
Near me (JIT): tap → pre-prompt sheet [SF] r20-top:
  "Temukan kos di sekitarmu / Lokasi hanya dipakai saat kamu minta 'dekat saya'.
   KOSTARA tidak melacak lokasi di background."  [Nyalakan lokasi][Nanti saja]
Denied → tombol Near me jadi disabled [LN] + hint "Cari via kampus/area".
```

## W5 — Filter Sheet (DESIGN §19)

```text
┌────────────────────────────────────┐  full-height sheet r20-top [SF]
│ ─── (handle 36×4 [LN])             │
│ Filter                       Reset  │  H2 + aksi teks [DGR] (reset)
│ ─ Harga ──────────────────────────  │  Label 12/16 650; dual slider (W2)
│   Rp500rb ──●──● Rp2jt             │
│ ─ Tipe kos ───────────────────────  │  chip r10 multi-select
│   [Putra] [Putri] [Campur]          │
│ ─ Kamar ──  ( −  1  + )            │  stepper h40 [LN] border r12
│ ─ Fasilitas ──────────────────────  │  checklist baris h44 (bukan 20 chip)
│   ☑ WiFi        ☐ AC               │
│   ☑ KM dalam    ☐ Parkir           │
│ ─ Rating minimal ── ★★★★☆  4+      │
│ ─ Ketersediaan ─── ☑ Hanya tersedia│
│ ─ Jarak dari kampus ──  ●───●  3 km │
├────────────────────────────────────┤  sticky footer h72 [SF] border-top [LN]
│  Reset              Tampilkan 42 kos│  primary button flex [P]
└────────────────────────────────────┘  angka = hasil live query (bukan janji
                                        kosong — bila error: "Tampilkan hasil")
```

## W6 — Property Detail (DESIGN §20)

```text
┌────────────────────────────────────┐
│ [═══ galeri immersif 300dp, full-bleed ═══] │ dot indicator; tombol back
│                              ♥      │  circle 40dp [SF] transparan
│ Kos Melati Unand            ✓Terverifikasi│ H2 22/28 700 + badge [SUC]/[PS]
│ ★ 4,8 (21 ulasan) · Putra           │  Body [T2]
│ ──────────────────────────────────  │
│ Rp950.000 / bulan     Tersedia 3 kamar│ H2 harga 700 [T1]; status chip [SUC]
│ Diperbarui 2 hari lalu              │  Caption 12 [T2] (FR-SEARCH-03)
│ ┌────────────────────────────────┐  │
│ │ Skor kecocokan 92/100          │  │  card [PS] r16; alasan expandable:
│ │ ⌄ Kenapa cocok: budget · dekat  │  │  "✓ Masuk budget kamu / ✓ 1,2 km
│ └────────────────────────────────┘  │   dari kampus / ✓ WiFi + KM dalam"
│ ±1,2 km dari Unand (jarak, bukan ETA)│  label jujur distance-only (ADR-003)
│ ┌ Kamar tersedia ────────────────┐  │  room row: kode, harga, status chip
│ │ A2 · single · Rp950rb  Tersedia│  │  [SUC]/[WRN]/[T2]
│ │ B1 · shared  · Rp750rb  Tersedia│ │
│ └────────────────────────────────┘  │
│ Fasilitas  [WiFi] [KM dalam] [Parkir]│ chip r10 [SF]/[LN]
│ Lokasi     [ mini map 160dp r16 ]   │  marker property + kampus, tanpa pin GPS user
│ Aturan     Ketentuan sewa ▾         │  expand/collapse
│ Ulasan terverifikasi                │  "Penghuni terverifikasi • Jun 2026"
│  ★★★★★ "Bersih, WiFi stabil…"  ▾    │  tanpa nama/nomor (AC-REV-06)
├────────────────────────────────────┤
│  [ ♥ ]   [ Pilih kamar / Ajukan ]   │  sticky bottom h72 [SF] border-top
└────────────────────────────────────┘  primary flex [P] h52 r12
States: room habis → CTA disabled [LN] + "Kamar penuh"; offline → banner cache.
```

## W7 — Tenancy Home + Payment (DESIGN §24–25)

```text
┌────────────────────────────────────┐
│ Sewa saya                          │  H2 [T1]
│ ┌────────────────────────────────┐ │  card [SF] r16 border [LN]
│ │ Kos Melati · Kamar A2          │ │  nama property Body L 650
│ │ Jun 2026 – Jun 2027 · bulanan  │ │  period Caption [T2]
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │  kartu pembayaran [SF]
│ │ Jatuh tempo berikutnya         │ │  Label 12 650 [T2]
│ │ 17 Oktober 2026                │ │  H2 700 [T1]
│ │ Rp950.000        Due in 6 days │ │  amount H1 700 · sisa hari chip
│ │ status chip: Segera jatuh tempo │ │  [WRN]/[SUC]/[DGR] (upcoming/due/paid/
│ │ [ Atur pengingat ] [ Riwayat ] │ │  overdue — tanpa wording menakutkan)
│ └────────────────────────────────┘ │
│ Pengingat aktif · 7, 3, 1, 0 hari  │  row + switch [P] on / [LN] off
│ Riwayat pembayaran                 │
│  ● Okt 2026  Rp950.000   Lunas     │  row h56; ikon centang [SUC]
│  ● Sep 2026  Rp950.000   Lunas     │
│ Ulasan kamu (muncul setelah selesai)│  disabled row [T2]
├────────────────────────────────────┤
│ nav: [Beranda][Jelajah][Tersimpan][Sewa][Profil] tab Sewa aktif
└────────────────────────────────────┘
Empty (tanpa tenancy): "Belum ada sewa aktif" + penjelasan + [Cari kos] (DESIGN §34).
```

## W8 — Final Review (DESIGN §27)

```text
┌────────────────────────────────────┐
│ ←  Bagikan pengalaman              │
│ ┌────────────────────────────────┐ │  banner [PS] r16
│ │ Kamu sudah tinggal 10 bulan.   │ │  eligibility copy
│ │ Bantu penghuni berikutnya.     │ │
│ └────────────────────────────────┘ │
│ Rating keseluruhan                 │
│  ★ ★ ★ ★ ☆                        │  star 40dp; selected [ACC]
│ ─────────────────────────────────  │
│ Kebersihan     ★★★★☆   (wajib)     │  8 baris aspek; label Body [T1]
│ Keamanan       ★★★★★              │  star 28dp; belum diisi → [DGR] kecil
│ Internet       ★★★☆☆              │  "Pilih rating" saat submit kosong
│ Air            ★★★★☆              │
│ Kenyamanan     ★★★★★              │
│ Akses          ★★★★☆              │
│ Pemilik        ★★★★★              │
│ Nilai (harga)  ★★★★☆              │
│ Ceritakan sedikit (opsional)       │
│ ┌────────────────────────────────┐ │  textarea h120 r12; counter 0/1000
│ │ …                              │ │  >1000 → [DGR] tolak (AC-REV-04)
│ └────────────────────────────────┘ │
│ Review publik tidak menampilkan    │  Caption [T2] (privacy explain)
│ detail tenancy pribadi.            │
├────────────────────────────────────┤
│  [        Kirim review (kirim ke moderasi) ] │  sticky [P]
└────────────────────────────────────┘
Submit → success snackbar [SUC] "Review menunggu moderasi" → /tenancy.
```

## W9 — Owner Home (DESIGN §28)

```text
┌────────────────────────────────────┐
│ Halo, Pak Ujang            [avatar]│
│ ⚠ Banner: Menunggu verifikasi      │  banner [WRN]/[SF] bila pending
│ ────────────────────────────────── │
│ ┌───────┐┌───────┐┌───────┐┌──────┐│  4 stat TANPA kartu boros:
│ │ 12/16 ││  4    ││  2    ││  1   ││  angka H2 700 [T1] + label 12 [T2]
│ │Okupansi││Kosong ││Jatuh  ││Perlu ││  inline, dipisah divider [LN]
│ │      ││      ││ tempo ││ cek  ││
│ └───────┘└───────┘└───────┘└──────┘│
│ Property                            │  H3
│ ┌────────────────────────────────┐ │  row: cover 56 r12, nama, okupansi
│ │[img] Kos Melati    12/16 · Aktif│ │  status chip [SUC]/[LN]
│ │[img] Griya Cendana  6/10 · Draft│ │
│ └────────────────────────────────┘ │
│ Permintaan sewa baru (2)        ▸  │  row aksi; ketuk → /owner/tenants
│ Pembayaran                        ▸  │  overdue count chip [DGR]
│ Feedback penghuni                 ▸  │  ringkasan aspek; sample <5 review →
│ "Belum cukup feedback utk ringkasan"│  empty copy (DESIGN §31)
├────────────────────────────────────┤
│ [Beranda][Properti][Penghuni][Bayar][Profil]
└────────────────────────────────────┘
Action prioritas ≤2 tap (accept request, tandai paid) — tanpa dashboard keuangan.
```

## W10 — Admin Verification detail (DESIGN §32)

```text
┌────────────────────────────────────┐
│ ← Verifikasi pemilik               │  H2
│ Antrian: 12 pemilik · 8 listing    │  Caption counters [T2]
│ ────────────────────────────────── │
│ Pengaju    : Ujang (owner)         │  Body
│ Dokumen    │ ktp-xxx.png ▾         │  preview (signed URL); buka → full
│ (preview area 200dp [BG] r16)      │
│ Listing    : Kos Melati · 16 kamar │  ringkas data penting
│ Status saat ini: pending           │  chip [WRN]
│ Riwayat    : belum pernah ditolak  │
│ ────────────────────────────────── │
│ Alasan penolakan (wajib bila tolak) │  visible hanya saat Tolak
│ ┌────────────────────────────────┐ │
│ │ …                              │ │  [DGR] outline bila kosong saat submit
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│  [ Tolak ]            [ Setujui ]  │  Tolak outline [DGR], Setujui fill [SUC]
└────────────────────────────────────┘
Sukses → pop kembali + row berpindah antrian + audit_logs tercatat (AC-ADM-06).
```

---

Checklist desain (DESIGN §41) berlaku untuk semua wireframe di atas; verifikasi
360×800 / 390×844 / 430×932 + text scale 200% masuk DoD backlog.
