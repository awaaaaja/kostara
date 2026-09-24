# CP-02 — Geospatial Data Plan

Date: 2026-09-25
Status: LOCKED V1 — **distance-only** (A-09: routing provider belum diverifikasi).

## 1. Data spasial

| Data | Sumber | Simpan di | Format |
|---|---|---|---|
| Titik property | input owner via pin peta (CP-03B) | `properties.location` | `geography(Point,4326)`, wajib non-null |
| Titik kampus | seed resmi (koordinat kampus terdaftar) | `campuses.location` | sama |
| Lokasi user saat "Near me" | geolocator sesaat | **tidak disimpan** — hanya argumen RPC | transient |
| Bbox viewport map | gesture peta | hanya sebagai argumen query + metadata event (bukan koordinat user) | transient |

SRID: **4326** (WGS84). Tipe `geography` agar jarak meter euklidis-correct
pada permukaan bumi. Extension `postgis` aktif.

## 2. Query minimum (semua server-side, diindex)

| Kebutuhan | Mekanisme | Index |
|---|---|---|
| Bbox / viewport ("search this area") | `location && ST_MakeEnvelope(minLng,minLat,maxLng,maxLat,4326)` | GIST(location) |
| Nearby (radius) | `ST_DWithin(location, ST_SetSRID(ST_MakePoint(lng,lat),4326)::geography, radius_m)` | GIST |
| Jarak ke kampus/peta | `ST_Distance(location, campus.location)::int` | turunan per query |
| Filter radius user | digabung dlm `search_properties(...)` | GIST + btree status |

Aturan (AGENTS §10.5): **jangan** menarik semua koordinat ke device lalu
menghitung di Flutter; agregasi jarak/ranking dilakukan di Postgres/RPC.

## 3. Izin lokasi (consent behavior)

```text
Buka Explore Map
 ├─ default: TANPA permission — peta terpusat ke kampus/area terakhir user (manual)
 ├─ tekan "Near me" → just-in-time dialog sistem (sekali penjelasan pre-prompt)
 │    ├─ granted → query nearby radius default (2 km / preferensi user)
 │    │            koordinat DIPAKAI SESAAT lalu dibuang (tidak persist — FR-PRIV-01)
 │    └─ denied  → TIDAK ada dialog ulang otomatis; tombol jadi state nonaktif
 │                 + hint "Cari via kampus/area manual"; pencarian tetap penuh
 └─ TIDAK ADA: foreground/background service, geofence, riwayat trail,
               permission check saat app resume otomatis (AC-LOC-01/02)
```

Fallback setara (tanpa GPS): cari per kampus, cari per nama kecamatan/area
(seed area Padang), atau geser peta manual. **Semua fitur pencarian tetap
berfungsi tanpa izin lokasi** (VALIDATION_PROTOCOL §17).

## 4. Travel time & isochrone (P1 — batasan keras)

- V1 menampilkan **jarak (m/km) saja**. Label UI: "± X km dari kampus Y".
- ETA/travel time hanya ditambahkan bila (semuanya terpenuhi):
  1. ADR-xxx memilih routing provider dengan lisensi yang jelas;
  2. response provider valid (kode 200 + route terbentuk);
  3. atribusi/attribution ditampilkan sesuai ketentuan provider.
- Jika tidak → tampil `distance only`; **dilarang** menghitung ETA dari
  kecepatan asumsi/dispatch garis lurus (AGENTS §4.5, PRD §14.4).
- Isochrone = P1, tidak mempengaruhi V1 gate.

## 5. Eksplorasi & clustering

- Marker > 100 per viewport → clustering (NFR-PERF-04).
- Query viewport memakai debounce 300 ms (NFR-PERF-07) dan hanya berjalan
  setelah gesture selesai (AC-MAP-02).
- Sinkronisasi list ↔ map: satu filter state bersama; jumlah marker ==
  jumlah hasil list (AC-MAP-01).

## 6. Uji spasial (ringkas — detail di test plan)

| ID | Kasus | Ekspektasi |
|---|---|---|
| TP-GIS-01 | fixture 3 point dengan jarak diketahui (±0,01%) | `ST_DWithin` radius 1000 m hanya mengembalikan yang benar-benar dalam radius |
| TP-GIS-02 | bbox query di luar semua point | 0 row; bbox miring/renderan viewport ≠ query (pakai envelope axis-aligned) |
| TP-GIS-03 | `EXPLAIN ANALYZE` pada 1000 fixture | index scan GIST, bukan seq scan |
| TP-GIS-04 | flow tanpa permission (AC-LOC-01) | 0 permintaan izin lokasi |
| TP-GIS-05 | audit skema | 0 kolom lokasi user (AC-LOC-02) |

## 7. Keputusan terkait

- Radius default near me: **2000 m** (dapat diubah user ≤ 20.000 m lewat filter).
- Koordinat default peta tanpa GPS: primary campus user → lalu pusat kota Padang.
- Geocoding alamat teks → point: dilakukan saat owner mem-pin (client kirim
  koordinat hasil pin, bukan server geocode) — menghindari API key eksternal di V1.
