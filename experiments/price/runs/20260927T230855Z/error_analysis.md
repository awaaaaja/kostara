# Error analysis — PRICE-EXP-001 (20260927T230855Z)

Model: tuned_catboost (log1p) · seed 42 · data: kostara-padang-v1-ed0ada2321be30cd
Metrik keseluruhan: MAE OOF+holdout = 219,576 IDR (n=40)

## Interval (§17)

- Split conformal 80% · kalibrasi n=9 (group-aware, 3 grup)
- q_hat = 190,878 IDR · lebar rata-rata = 381,757 IDR
- **Coverage empiris holdout = 60%** (6/10 baris) — diukur, bukan diklaim

## Segment (§18)

| segment | value | n | MAE IDR | status |
|---|---|---|---|---|
| district | Padang Timur | 9 | 238,439 | OK |
| district | Pauh | 31 | 214,099 | OK |
| price_band | Q1 | 10 | 304,789 | OK |
| price_band | Q2 | 11 | 127,045 | OK |
| price_band | Q3 | 9 | 99,587 | OK |
| price_band | Q4 | 10 | 344,136 | OK |
| room_size | 11-16 | 18 | 205,377 | OK |
| room_size | 17-25 | 22 | 231,193 | OK |
| facility_completeness | sedang | 14 | 139,122 | OK |
| facility_completeness | banyak | 13 | 331,416 | OK |
| facility_completeness | sangat | 13 | 194,378 | OK |
| gender_type | any | 17 | 296,494 | OK |
| gender_type | female_only | 13 | 145,331 | OK |
| gender_type | male_only | 10 | 185,333 | OK |

## Segmen tidak andal & aturan fallback

- Tidak ada segmen dengan n<5 pada data saat ini.
- `travel_time_band`: N/A di V1 (tidak ada fitur travel time; tanpa routing engine → tanpa ETA, ADR-003).
- Aturan block: bila holdout/observasi segmen < 3 kalibrasi → respons `INSUFFICIENT_DATA`; bila model servis gagal → fallback B0 district median (THINK-01).

Catatan jujur: n=40 sangat kecil — semua angka adalah kondisi data dev saat ini, bukan klaim performa produk (AGENTS §4.4).
