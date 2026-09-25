-- ML Price Intelligence: observasi harga + estimasi (PRD FR-PRICE-*, ML spec §21–§24)
-- Ikhtisar:
--   * room_price_observations — histori harga per kamar. Ditulis OTOMATIS oleh
--     trigger (owner_edit / room_create / seed_backfill); immutable seperti
--     interactions (tanpa policy insert/update/delete untuk client).
--     1 record = 1 tipe kamar pada 1 titik waktu observasi (spec §3.2).
--   * price_estimates — hasil inferensi. TULIS hanya service/server (service
--     role); client tidak punya policy insert/update. Baca: owner sendiri +
--     super_admin. Seeker TIDAK baca tabel ini — hanya lewat view bawah
--     (label posisi saja, tanpa angka).
--   * price_insight_public — view publik: listing verified+active, kolom
--     posisi/quality saja (price tetap keputusan owner; tanpa angka estimasi).
--   * snapshot fitur dihitung saat observasi: fasilitas, jarak kampus terdekat
--     (geography <-> ), district, koordinat — sesuai feature contract §7.
--     subdistrict = null (gap V1, dicatat di gate report).
--
-- DEVISI vs THINK: price_estimates memakai nomor migrasi 010018 (010017 =
-- padang_districts, prasyarat kolom district). Non-destruktif, aditif semua.

-- kind model_versions bertambah 'pricer' (check constraint lama diganti,
-- data existing tidak terpengaruh)
alter table public.model_versions
  drop constraint model_versions_kind_check,
  add constraint model_versions_kind_check
    check (kind in ('recommender', 'review_nlp', 'pricer'));

-- kamar: kunci komposit (id, property_id) agar estimasi tidak bisa menunjuk
-- pasangan room×property yang tidak konsisten (AGENTS §10.2)
alter table public.rooms
  add constraint rooms_id_property_key unique (id, property_id);

create table public.room_price_observations (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  observed_at timestamptz not null default now(),
  monthly_price integer not null check (monthly_price > 0),
  district text references public.districts(nama),
  verification_status text not null
    check (verification_status in ('pending','verified','rejected','suspended')),
  source_type text not null
    check (source_type in ('owner_edit','room_create','seed_backfill','system')),
  feature_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (room_id, observed_at)
);
create index rpo_room_time_idx
  on public.room_price_observations (room_id, observed_at desc);
create index rpo_property_idx
  on public.room_price_observations (property_id);
create index rpo_district_price_idx
  on public.room_price_observations (district, monthly_price);

-- snapshot fitur bersama (dipakai trigger + backfill)
create or replace function public.room_price_feature_snapshot(p_room_id uuid)
returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'room_type', r.room_type,
    'room_status', r.status,
    'size_sqm', r.size_sqm,
    'deposit', r.deposit,
    'gender_policy', p.gender_policy,
    'district', p.district,
    'address', p.address,
    'lat', st_y(p.location::geometry),
    'lng', st_x(p.location::geometry),
    'facility_slugs', (
      select coalesce(jsonb_agg(f.slug order by f.slug), '[]'::jsonb)
      from public.property_facilities pf
      join public.facilities f on f.id = pf.facility_id
      where pf.property_id = p.id and f.is_active),
    'nearest_campus_name', (
      select c.name from public.campuses c
      where c.is_active
      order by c.location <-> p.location
      limit 1),
    'nearest_campus_km', (
      select round(((c.location <-> p.location) / 1000.0)::numeric, 3)
      from public.campuses c
      where c.is_active
      order by c.location <-> p.location
      limit 1)
  )
  from public.rooms r
  join public.properties p on p.id = r.property_id
  where r.id = p_room_id;
$$;
revoke all on function public.room_price_feature_snapshot(uuid) from public;
grant execute on function public.room_price_feature_snapshot(uuid) to service_role;

-- trigger: rekam observasi saat harga kamar dibuat/berubah
create or replace function public.rooms_price_observation_fn()
returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_room public.rooms%rowtype;
  v_prop public.properties%rowtype;
begin
  -- PG melarang OLD di WHEN trigger INSERT → guard di-body
  if tg_op = 'UPDATE' and new.price = old.price then
    return coalesce(new, old);
  end if;
  select * into v_room from public.rooms
  where id = coalesce(new.id, old.id);
  if not found or v_room.price <= 0 then
    return coalesce(new, old);
  end if;
  select * into v_prop from public.properties where id = v_room.property_id;
  if not found then
    return coalesce(new, old);
  end if;
  insert into public.room_price_observations
    (property_id, room_id, observed_at, monthly_price, district,
     verification_status, source_type, feature_snapshot)
  values (
    v_prop.id,
    v_room.id,
    now(),
    v_room.price,
    v_prop.district,
    v_prop.verification_status,
    case when tg_op = 'INSERT' then 'room_create' else 'owner_edit' end,
    public.room_price_feature_snapshot(v_room.id)
  );
  return coalesce(new, old);
end;
$$;
create trigger rooms_price_observation
  after insert or update of price on public.rooms
  for each row
  execute function public.rooms_price_observation_fn();

-- backfill: 1 observasi awal per kamar berharga (source seed_backfill)
insert into public.room_price_observations
  (property_id, room_id, observed_at, monthly_price, district,
   verification_status, source_type, feature_snapshot)
select r.property_id, r.id, r.created_at, r.price, p.district,
       p.verification_status, 'seed_backfill',
       public.room_price_feature_snapshot(r.id)
from public.rooms r
join public.properties p on p.id = r.property_id
where r.price > 0
on conflict (room_id, observed_at) do nothing;

create table public.price_estimates (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null,
  property_id uuid not null,
  status text not null default 'failed'
    check (status in ('ok','insufficient_data','failed')),
  model_version_id uuid references public.model_versions(id),
  model_version text,
  actual_price integer not null check (actual_price > 0),
  estimated_lower numeric check (estimated_lower is null or estimated_lower > 0),
  estimated_point numeric check (estimated_point is null or estimated_point > 0),
  estimated_upper numeric check (estimated_upper is null or estimated_upper > 0),
  check (estimated_lower is null or estimated_point is null or estimated_upper is null
         or (estimated_lower <= estimated_point
             and estimated_point <= estimated_upper)),
  check (status <> 'ok'
         or (estimated_lower is not null
             and estimated_point is not null
             and estimated_upper is not null)),
  interval_target_coverage numeric not null default 0.8
    check (interval_target_coverage > 0 and interval_target_coverage < 1),
  quality_status text not null default 'INSUFFICIENT_DATA'
    check (quality_status in ('SUFFICIENT_DATA','INSUFFICIENT_DATA')),
  price_position text not null default 'UNAVAILABLE'
    check (price_position in ('BELOW_RANGE','WITHIN_COMPARABLE_RANGE',
                              'ABOVE_RANGE','UNAVAILABLE')),
  explain jsonb,
  generated_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (room_id, property_id)
    references public.rooms (id, property_id) on delete cascade
);
create index price_estimates_room_time_idx
  on public.price_estimates (room_id, generated_at desc);
create index price_estimates_property_idx
  on public.price_estimates (property_id);

-- RLS: baca owner sendiri + admin; TANPA policy insert/update/delete (server only)
alter table public.room_price_observations enable row level security;
create policy rpo_select_owner on public.room_price_observations
  for select to authenticated
  using (exists (select 1 from public.properties p
                 where p.id = room_price_observations.property_id
                   and p.owner_id = auth.uid())
         or public.app_is_admin());

alter table public.price_estimates enable row level security;
create policy price_estimates_select_owner on public.price_estimates
  for select to authenticated
  using (exists (select 1 from public.properties p
                 where p.id = price_estimates.property_id
                   and p.owner_id = auth.uid())
         or public.app_is_admin());

-- view publik: label posisi saja (tanpa angka estimasi), listing publik saja,
-- estimasi terakhir per kamar yang belum kedaluwarsa.
-- View dimiliki postgres (definer) → kontrol rilis kolom; guard = join WHERE.
create view public.price_insight_public as
select distinct on (pe.room_id)
  pe.room_id,
  pe.price_position,
  pe.quality_status,
  pe.generated_at
from public.price_estimates pe
join public.rooms r on r.id = pe.room_id
join public.properties p on p.id = r.property_id
where p.listing_status = 'active'
  and p.verification_status = 'verified'
  and (pe.expires_at is null or pe.expires_at > now())
order by pe.room_id, pe.generated_at desc;

grant select on public.price_insight_public to anon, authenticated;
