-- CP-03B SEED — DATA SINTETIS HANYA UNTUK DEV/TEST (bukan data nyata).
-- Idempotent: id tetap (fixed uuid) + ON CONFLICT DO NOTHING.
-- Koordinat kampus = titik perkiraan publik untuk dev (BUKAN data survey/geo akurat).
-- Property/room/review/interactions = karangan, jelas synthetic, dipakai untuk
-- pengujian RLS/spatial/ML di environment dev.

-- super_admin tidak pernah lahir dari signup (trigger memaksa seeker)
update public.profiles set role = 'super_admin' where id = '{{ADMIN}}';

-- owner terverifikasi (seed fixture; production lewat admin_verify_owner RPC)
update public.owner_profiles
  set verification_status = 'verified',
      submitted_at = now(), reviewed_at = now(), reviewer_id = '{{ADMIN}}'
  where user_id in ('{{OWNER1}}', '{{OWNER2}}');

-- ===== master: campuses (5) =====
insert into public.campuses (id, name, address, location) values
  ('c0000000-0000-4000-8000-000000000001', 'Universitas Andalas (Unand)',
   'Limau Manis, Koto Tangah, Padang',
   st_setsrid(st_makepoint(100.4865, -0.9210), 4326)::geography),
  ('c0000000-0000-4000-8000-000000000002', 'Institut Teknologi Padang (ITP)',
   'Banda Bata, Koto Tangah, Padang',
   st_setsrid(st_makepoint(100.3680, -0.9425), 4326)::geography),
  ('c0000000-0000-4000-8000-000000000003', 'Universitas Negeri Padang (UNP)',
   'Air Tawar, Padang Utara, Padang',
   st_setsrid(st_makepoint(100.4185, -0.9365), 4326)::geography),
  ('c0000000-0000-4000-8000-000000000004', 'Universitas Bung Hatta (UBH)',
   'Gunung Pangilun, Padang Timur, Padang',
   st_setsrid(st_makepoint(100.4640, -0.9180), 4326)::geography),
  ('c0000000-0000-4000-8000-000000000005', 'Politeknik Negeri Padang (PNP)',
   'Padang, Koto Tangah, Padang',
   st_setsrid(st_makepoint(100.4210, -0.9300), 4326)::geography)
on conflict (id) do nothing;

-- ===== master: facilities (10) =====
insert into public.facilities (id, slug, name, category) values
  ('f0000000-0000-4000-8000-000000000001', 'wifi', 'Wi-Fi', 'internet'),
  ('f0000000-0000-4000-8000-000000000002', 'ac', 'AC', 'kamar'),
  ('f0000000-0000-4000-8000-000000000003', 'kamar-mandi-dalam', 'Kamar Mandi Dalam', 'kamar'),
  ('f0000000-0000-4000-8000-000000000004', 'dapur', 'Dapur Bersama', 'fasilitas'),
  ('f0000000-0000-4000-8000-000000000005', 'parkir-motor', 'Parkir Motor', 'transport'),
  ('f0000000-0000-4000-8000-000000000006', 'parkir-mobil', 'Parkir Mobil', 'transport'),
  ('f0000000-0000-4000-8000-000000000007', 'laundry', 'Laundry', 'layanan'),
  ('f0000000-0000-4000-8000-000000000008', 'cctv', 'CCTV', 'keamanan'),
  ('f0000000-0000-4000-8000-000000000009', 'air-panas', 'Air Panas', 'kamar'),
  ('f0000000-0000-4000-8000-000000000010', 'security-24-jam', 'Security 24 Jam', 'keamanan')
on conflict (id) do nothing;

-- ===== properties (12: 10 aktif verified, 1 draft, 1 pending) =====
insert into public.properties
  (id, owner_id, name, description, address, location, gender_policy,
   verification_status, listing_status)
values
  ('a0000000-0000-4000-8000-000000000001', '{{OWNER1}}',
   'Kos Putri Melati Unand',
   'Kos putri dekat gerbang Unand, bersih dan tenang.',
   'Jl. Raya Unand, Limau Manis',
   st_setsrid(st_makepoint(100.4878, -0.9198), 4326)::geography,
   'female_only', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000002', '{{OWNER1}}',
   'Kos Putri Anggrek Sejahtera',
   'Dekat pasar dan minimarket, akses mudah ke Unand.',
   'Jl. Baru Unand, Padang',
   st_setsrid(st_makepoint(100.4831, -0.9247), 4326)::geography,
   'female_only', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000003', '{{OWNER1}}',
   'Kos Putra Banda Indah',
   'Kos putra dekat ITP, cocok mahasiswa teknik.',
   'Jl. Banda Bata, Padang',
   st_setsrid(st_makepoint(100.3695, -0.9437), 4326)::geography,
   'male_only', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000004', '{{OWNER1}}',
   'Kost Campur Rinjani',
   'Kost campur dilengkapi dapur bersama.',
   'Jl. Rimbo Kaluang, Padang Barat',
   st_setsrid(st_makepoint(100.4150, -0.9310), 4326)::geography,
   'any', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000005', '{{OWNER1}}',
   'Kos Eksklusif Minang Residence',
   'Kos eksklusif ber-AC dengan keamanan 24 jam.',
   'Jl. Kampus Unand, Padang',
   st_setsrid(st_makepoint(100.4895, -0.9225), 4326)::geography,
   'any', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000006', '{{OWNER2}}',
   'Kos Putra Eltis Homestay',
   'Kos putra dekat ITP dengan parkir luas.',
   'Jl. By Pass ITP, Padang',
   st_setsrid(st_makepoint(100.3655, -0.9402), 4326)::geography,
   'male_only', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000007', '{{OWNER2}}',
   'Kost Putri Sinar Padang',
   'Kos putri dekat UNP, akses ke kampus 5 menit.',
   'Jl. Air Tawar, Padang Utara',
   st_setsrid(st_makepoint(100.4212, -0.9380), 4326)::geography,
   'female_only', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000008', '{{OWNER2}}',
   'Kost Tengah Kota Hubungan',
   'Kost strategis di tengah kota, dekat UBH.',
   'Jl. Gajah Mada, Padang Tengah',
   st_setsrid(st_makepoint(100.4610, -0.9165), 4326)::geography,
   'any', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000009', '{{OWNER2}}',
   'Kos Putra PNP Sport',
   'Kos putra dekat PNP, cocok olahragawan.',
   'Jl. PNP, Koto Tangah',
   st_setsrid(st_makepoint(100.4235, -0.9318), 4326)::geography,
   'male_only', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000010', '{{OWNER1}}',
   'Kos Murah Meriah Unand',
   'Kos terjangkau untuk mahasiswa baru.',
   'Jl. Raya Limau Manis, Padang',
   st_setsrid(st_makepoint(100.4845, -0.9185), 4326)::geography,
   'any', 'verified', 'active'),
  ('a0000000-0000-4000-8000-000000000011', '{{OWNER1}}',
   'Kos Putri Baru Unand',
   'Kos baru, belum terverifikasi.',
   'Jl. Raya Unand, Padang',
   st_setsrid(st_makepoint(100.4855, -0.9175), 4326)::geography,
   'female_only', 'pending', 'draft'),
  ('a0000000-0000-4000-8000-000000000012', '{{OWNER2}}',
   'Kos ITP Family',
   'Kos keluarga dekat ITP, menunggu verifikasi.',
   'Jl. ITP, Padang',
   st_setsrid(st_makepoint(100.3670, -0.9450), 4326)::geography,
   'any', 'pending', 'draft')
on conflict (id) do nothing;

-- ===== rooms (3–4 per property; status di-set saat INSERT utk hindari
--      transisi machine state yang tidak sah) =====
insert into public.rooms (id, property_id, code, room_type, price, deposit, status, size_sqm)
select
  md5('kostara-room-' || p.n || '-' || r.n)::uuid,
  p.pid::uuid,
  'R' || r.n,
  case r.n % 3 when 0 then 'single' when 1 then 'shared' else 'studio' end,
  p.base_price + (r.n * 50000),
  case when r.n = 1 then 500000 else 0 end,
  case
    when p.n = 1 and r.n = 1 then 'occupied'  -- t1 aktif
    when r.n = 4 then 'maintenance'
    else 'available'
  end,
  case when r.n % 2 = 0 then 12 else 18 end
from (values
  (1, 'a0000000-0000-4000-8000-000000000001', 4, 1200000),
  (2, 'a0000000-0000-4000-8000-000000000002', 4, 900000),
  (3, 'a0000000-0000-4000-8000-000000000003', 3, 800000),
  (4, 'a0000000-0000-4000-8000-000000000004', 4, 1000000),
  (5, 'a0000000-0000-4000-8000-000000000005', 3, 1800000),
  (6, 'a0000000-0000-4000-8000-000000000006', 4, 750000),
  (7, 'a0000000-0000-4000-8000-000000000007', 3, 1100000),
  (8, 'a0000000-0000-4000-8000-000000000008', 4, 950000),
  (9, 'a0000000-0000-4000-8000-000000000009', 3, 850000),
  (10, 'a0000000-0000-4000-8000-000000000010', 4, 600000),
  (11, 'a0000000-0000-4000-8000-000000000011', 2, 1000000),
  (12, 'a0000000-0000-4000-8000-000000000012', 2, 1200000)
) as p(n, pid, cnt, base_price)
cross join lateral generate_series(1, p.cnt) r(n)
on conflict (id) do nothing;

-- ===== property_facilities =====
insert into public.property_facilities (property_id, facility_id)
select p.pid::uuid, f.fid
from (values
  ('a0000000-0000-4000-8000-000000000001', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000002,f0000000-0000-4000-8000-000000000003,f0000000-0000-4000-8000-000000000005}'),
  ('a0000000-0000-4000-8000-000000000002', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000003,f0000000-0000-4000-8000-000000000005,f0000000-0000-4000-8000-000000000007}'),
  ('a0000000-0000-4000-8000-000000000003', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000002,f0000000-0000-4000-8000-000000000005,f0000000-0000-4000-8000-000000000006}'),
  ('a0000000-0000-4000-8000-000000000004', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000004,f0000000-0000-4000-8000-000000000005}'),
  ('a0000000-0000-4000-8000-000000000005', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000002,f0000000-0000-4000-8000-000000000003,f0000000-0000-4000-8000-000000000008,f0000000-0000-4000-8000-000000000010}'),
  ('a0000000-0000-4000-8000-000000000006', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000005,f0000000-0000-4000-8000-000000000006,f0000000-0000-4000-8000-000000000008}'),
  ('a0000000-0000-4000-8000-000000000007', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000003,f0000000-0000-4000-8000-000000000005,f0000000-0000-4000-8000-000000000010}'),
  ('a0000000-0000-4000-8000-000000000008', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000004,f0000000-0000-4000-8000-000000000005,f0000000-0000-4000-8000-000000000009}'),
  ('a0000000-0000-4000-8000-000000000009', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000005,f0000000-0000-4000-8000-000000000006}'),
  ('a0000000-0000-4000-8000-000000000010', '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000005}')
) as p(pid, fids)
cross join lateral unnest(p.fids::uuid[]) as f(fid)
on conflict do nothing;

-- ===== user_preferences (4 seeker; seeker4 tanpa consent) =====
insert into public.user_preferences
  (user_id, primary_campus_id, budget_min, budget_max, gender_preference,
   transport_mode, max_distance_m, facility_priority)
values
  ('{{SEEKER1}}', 'c0000000-0000-4000-8000-000000000001',
   800000, 1800000, 'female_only', 'walk', 2500,
   '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000002,f0000000-0000-4000-8000-000000000003}'),
  ('{{SEEKER2}}', 'c0000000-0000-4000-8000-000000000002',
   700000, 1500000, 'male_only', 'motorcycle', 5000,
   '{f0000000-0000-4000-8000-000000000001,f0000000-0000-4000-8000-000000000005}'),
  ('{{SEEKER3}}', 'c0000000-0000-4000-8000-000000000003',
   900000, 2000000, 'any', 'walk', 3000,
   '{f0000000-0000-4000-8000-000000000001}'),
  ('{{SEEKER4}}', 'c0000000-0000-4000-8000-000000000001',
   1000000, 2200000, 'female_only', 'bike', 2000, null)
on conflict (user_id) do nothing;

-- ===== favorites =====
insert into public.favorites (user_id, property_id) values
  ('{{SEEKER1}}', 'a0000000-0000-4000-8000-000000000001'),
  ('{{SEEKER1}}', 'a0000000-0000-4000-8000-000000000002'),
  ('{{SEEKER2}}', 'a0000000-0000-4000-8000-000000000006')
on conflict do nothing;

-- ===== tenancies (1 aktif, 3 ended) =====
insert into public.tenancies
  (id, property_id, room_id, seeker_id, owner_id, start_date, end_date,
   amount, due_day, status, ended_at)
values
  ('e0000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000001',
   md5('kostara-room-1-1')::uuid, '{{SEEKER1}}', '{{OWNER1}}',
   '2026-08-01', null, 1250000, 1, 'active', null),
  ('e0000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000003',
   md5('kostara-room-3-1')::uuid, '{{SEEKER2}}', '{{OWNER1}}',
   '2026-03-01', '2026-08-01', 850000, 5, 'ended', '2026-08-01T10:00:00+07'),
  ('e0000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000005',
   md5('kostara-room-5-1')::uuid, '{{SEEKER3}}', '{{OWNER1}}',
   '2026-02-01', '2026-07-01', 1850000, 1, 'ended', '2026-07-01T09:00:00+07'),
  ('e0000000-0000-4000-8000-000000000004',
   'a0000000-0000-4000-8000-000000000007',
   md5('kostara-room-7-1')::uuid, '{{SEEKER1}}', '{{OWNER2}}',
   '2026-01-01', '2026-06-01', 1150000, 1, 'ended', '2026-06-01T09:00:00+07')
on conflict (id) do nothing;

-- ===== payment schedule + records (t1 aktif, 12 periode) =====
insert into public.payment_schedules
  (tenancy_id, next_due_date, amount)
values
  ('e0000000-0000-4000-8000-000000000001', '2026-10-01', 1250000)
on conflict (tenancy_id) do nothing;

insert into public.payment_records
  (tenancy_id, due_date, amount, status, paid_at, marked_by)
select
  'e0000000-0000-4000-8000-000000000001',
  ('2026-08-01'::date + make_interval(months => g))::date,
  1250000,
  case when g < 2 then 'paid' else 'unpaid' end,
  case g when 0 then '2026-08-01T09:00:00+07'::timestamptz
         when 1 then '2026-09-01T10:00:00+07'::timestamptz end,
  case when g < 2 then '{{OWNER1}}'::uuid end
from generate_series(0, 11) g
on conflict (tenancy_id, due_date) do nothing;

insert into public.reminders
  (tenancy_id, payment_record_id, offset_days, fire_at)
select
  'e0000000-0000-4000-8000-000000000001', pr.id, o,
  (pr.due_date::timestamp at time zone 'Asia/Jakarta')
    - make_interval(days => o)
from public.payment_records pr
cross join unnest(array[7, 3, 1, 0]) as o
where pr.tenancy_id = 'e0000000-0000-4000-8000-000000000001'
  and pr.due_date = '2026-10-01'
on conflict do nothing;

-- ===== tenancy_requests (1 pending, 1 rejected) =====
insert into public.tenancy_requests
  (id, property_id, room_id, seeker_id, status, message,
   decided_at, decided_by, reject_reason)
values
  ('b0000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000002',
   md5('kostara-room-2-1')::uuid, '{{SEEKER3}}', 'pending',
   'Minat sewa kamar R1, mulai Oktober.', null, null, null),
  ('b0000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000004',
   md5('kostara-room-4-1')::uuid, '{{SEEKER2}}', 'rejected',
   'Minta sewa kamar R1.', '2026-09-10T14:00:00+07', '{{OWNER1}}',
   'Kamar sudah terisi penghuni lain.')
on conflict (id) do nothing;

-- ===== reviews (3 approved + 1 pending) =====
insert into public.reviews
  (id, tenancy_id, property_id, user_id, review_type, rating_overall,
   review_text, status)
values
  ('d0000000-0000-4000-8000-000000000001',
   'e0000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000003', '{{SEEKER2}}', 'final', 4,
   'Kamar bersih, wifi cepat, pemilik ramah. Cocok untuk mahasiswa ITP.',
   'approved'),
  ('d0000000-0000-4000-8000-000000000002',
   'e0000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000005', '{{SEEKER3}}', 'final', 5,
   'Lokasi dekat kampus, keamanan 24 jam, kamar luas.',
   'approved'),
  ('d0000000-0000-4000-8000-000000000003',
   'e0000000-0000-4000-8000-000000000004',
   'a0000000-0000-4000-8000-000000000007', '{{SEEKER1}}', 'final', 3,
   'Air kadang kecil di pagi hari, selain itu nyaman dan tenang.',
   'approved'),
  ('d0000000-0000-4000-8000-000000000004',
   'e0000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000001', '{{SEEKER1}}', 'pulse', 4,
   null, 'pending')
on conflict (id) do nothing;

insert into public.review_aspect_scores
  (review_id, aspect, sentiment, confidence, source)
values
  ('d0000000-0000-4000-8000-000000000001', 'cleanliness', 'positive', 0.9, 'manual'),
  ('d0000000-0000-4000-8000-000000000001', 'internet', 'positive', 0.9, 'manual'),
  ('d0000000-0000-4000-8000-000000000001', 'owner', 'positive', 0.9, 'manual'),
  ('d0000000-0000-4000-8000-000000000002', 'security', 'positive', 0.9, 'manual'),
  ('d0000000-0000-4000-8000-000000000002', 'access', 'positive', 0.9, 'manual'),
  ('d0000000-0000-4000-8000-000000000003', 'water', 'negative', 0.9, 'manual'),
  ('d0000000-0000-4000-8000-000000000003', 'comfort', 'positive', 0.85, 'manual')
on conflict do nothing;

-- ===== interactions: ~1200 event sintetis, 45 hari, seed deterministik =====
-- Catatan: jangan pakai lateral tanpa korelasi berisi random() — planner
-- mengevaluasinya sekali sehingga semua baris bernilai sama. Pakai md5 per g.
insert into public.interactions
  (user_id, property_id, event_type, event_weight, source, session_id,
   occurred_at, metadata)
with gen as (
  select g,
    (('x' || substr(md5('kostara-seed-' || g), 1, 8))::bit(32)::bigint) / 4294967296.0 as r_user,
    (('x' || substr(md5('kostara-prop-' || g), 1, 8))::bit(32)::bigint) / 4294967296.0 as r_prop,
    (('x' || substr(md5('kostara-evt-'  || g), 1, 8))::bit(32)::bigint) / 4294967296.0 as r_evt,
    (('x' || substr(md5('kostara-src-'  || g), 1, 8))::bit(32)::bigint) / 4294967296.0 as r_src,
    (('x' || substr(md5('kostara-ts-'   || g), 1, 8))::bit(32)::bigint) / 4294967296.0 as r_ts
  from generate_series(1, 1200) g
)
select
  (array['{{SEEKER1}}', '{{SEEKER2}}', '{{SEEKER3}}'])[1 + floor(r_user * 3)::int]::uuid,
  (array[
    'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002',
    'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000004',
    'a0000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000006',
    'a0000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000008',
    'a0000000-0000-4000-8000-000000000009', 'a0000000-0000-4000-8000-000000000010'
  ])[1 + floor(r_prop * 10)::int]::uuid,
  case
    when r_evt < 0.50 then 'recommendation_impression'
    when r_evt < 0.80 then 'property_view'
    when r_evt < 0.90 then 'property_save'
    when r_evt < 0.96 then 'compare_add'
    when r_evt < 0.99 then 'tenancy_request'
    else 'tenancy_accepted'
  end,
  case
    when r_evt < 0.50 then 0
    when r_evt < 0.80 then 1
    when r_evt < 0.90 then 3
    when r_evt < 0.96 then 2
    when r_evt < 0.99 then 5
    else 8
  end,
  (array['feed', 'map', 'search', 'detail', 'saved', 'compare'])[1 + floor(r_src * 6)::int],
  'seed-' || g,
  now() - (r_ts * interval '45 days'),
  jsonb_build_object('seed', true)
from gen;

-- ===== registry ML: row fallback tetap tersedia (AC-REC-03) =====
insert into public.model_versions
  (id, kind, name, artifact_uri, metrics, dataset_version, seed, status)
values
  ('d0000000-0000-4000-8000-00000000ff01', 'recommender', 'baseline-fallback',
   'sql://feed_recommendations#baseline-fallback',
   '{"note": "rule-based fallback, tanpa training"}'::jsonb,
   'n/a', null, 'draft')
on conflict (id) do nothing;

-- ===== ringkasan seed =====
select
  (select count(*) from public.campuses) as campuses,
  (select count(*) from public.facilities) as facilities,
  (select count(*) from public.properties) as properties,
  (select count(*) from public.rooms) as rooms,
  (select count(*) from public.interactions) as interactions,
  (select count(*) from public.tenancies) as tenancies,
  (select count(*) from public.reviews) as reviews,
  (select count(*) from public.profiles) as profiles;
