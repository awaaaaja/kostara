# ADR-003 — Map: flutter_map (raster OSM) + query PostGIS server-side; ETA ditunda

Status: Accepted (V1) · Routing/ETA = Deferred P1
Date: 2026-09-25

## Context
FR-MAP-01..05 mewajibkan peta interaktif (marker, cluster, search-this-area,
near-me JIT). A-09 (kelayakan routing provider) masih unknown; AGENTS §4.5
melarang ETA dari jarak/dispatch palsu. PRD §18 mengizinkan flutter_map atau
stack MapLibre-compatible. AGENTS §10.5: query spasial server-side + index.

## Options
1. **flutter_map + tile raster OSM** (widget Dart murni, ringan, setup minimal).
2. MapLibre native/vector tiles (performa & clustering lebih baik; setup
   platform + binary size lebih besar).
3. Google Maps SDK / Mapbox (fitur matang; API key, billing, terms ketat).
4. Tanpa peta (list saja) — ditolak: FR-MAP wajib.

Untuk ETA: (a) **distance-only**; (b) OSRM self-host; (c) Directions API komersial.

## Decision
1. V1 = flutter_map dengan tile raster OSM (atribusi wajib tampil; hormati tile
   usage policy — tile endpoint jangan dipakai untuk prerender/bulk).
2. Semua query spasial di **PostGIS lewat RPC** (GIST + `ST_DWithin`/bbox);
   device hanya mengirim argumen bbox/radius dan menampilkan `distance_m`.
3. ETA/route = **belum valid** → distance-only; syarat mengaktifkan provider
   P1: lisensi jelas + response valid + attribution ditampilkan
   (`cp02-geospatial-plan.md` §4). Isochrone ikut ditunda.
4. Upgrade path: bila uji cluster/perf CP-05A gagal → evaluasi MapLibre
   (ADR baru), tanpa mengubah contract query (server-side tetap).

## Consequences
- (+) tanpa API key/billing di V1; setup cepat; zero risk ETA palsu.
- (−) raster tile = kualitas visual standar + kebijakan pemakaian OSM harus
  ditaati; clustering dilakukan client-side atas hasil viewport (batas 500 row
  → fallback ST_ClusterDBSCAN dicatat).
- Label UI: "± X km dari kampus" — jangan "menit" (AC distance-only).

## Validation
- TP-GIS-01..05 (jarak fixture ±0,01%, EXPLAIN GIST, tanpa permission).
- Atribusi & rendering dicek di Review UX CP-05A.
