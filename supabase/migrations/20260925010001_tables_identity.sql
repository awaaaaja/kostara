-- CP-03B: identitas, master, listing (kontrak: cp02-schema-draft §1–2)

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('seeker','owner','super_admin')),
  full_name text not null check (char_length(full_name) between 1 and 120),
  avatar_url text,
  phone text,
  status text not null default 'active' check (status in ('active','suspended')),
  tos_version text not null,
  tos_accepted_at timestamptz not null,
  data_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.owner_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  verification_status text not null default 'pending'
    check (verification_status in ('pending','verified','rejected','suspended')),
  doc_path text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewer_id uuid references public.profiles(id),
  reject_reason text
);

create table public.campuses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) >= 3),
  address text,
  location geography(point, 4326) not null,
  is_active boolean not null default true
);
create index campuses_location_gist on public.campuses using gist (location);

create table public.facilities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  category text,
  is_active boolean not null default true
);

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  name text not null check (char_length(name) between 3 and 120),
  description text,
  address text not null,
  location geography(point, 4326) not null,
  gender_policy text not null check (gender_policy in ('male_only','female_only','any')),
  verification_status text not null default 'pending'
    check (verification_status in ('pending','verified','rejected','suspended')),
  listing_status text not null default 'draft'
    check (listing_status in ('draft','active','archived')),
  rules text,
  last_availability_update_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index properties_location_gist on public.properties using gist (location);
create index properties_owner_idx on public.properties (owner_id);
create index properties_listing_idx on public.properties (listing_status, verification_status);

create table public.property_images (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0,
  is_cover boolean not null default false,
  created_at timestamptz not null default now(),
  unique (property_id, storage_path)
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  code text not null,
  room_type text not null check (room_type in ('single','shared','studio')),
  price integer not null check (price >= 0),
  deposit integer not null default 0 check (deposit >= 0),
  status text not null default 'available'
    check (status in ('available','reserved','occupied','maintenance','inactive')),
  size_sqm numeric check (size_sqm is null or size_sqm > 0),
  availability_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, code)
);
create index rooms_property_status_idx on public.rooms (property_id, status);

create table public.property_facilities (
  property_id uuid not null references public.properties(id) on delete cascade,
  facility_id uuid not null references public.facilities(id),
  primary key (property_id, facility_id)
);

-- trigger: signup auth → profiles (+owner_profiles)
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_role text := coalesce(new.raw_user_meta_data->>'role', 'seeker');
  v_full text := nullif(trim(coalesce(new.raw_user_meta_data->>'full_name', '')), '');
  v_tos text := new.raw_user_meta_data->>'tos_version';
  v_tos_at text := new.raw_user_meta_data->>'tos_accepted_at';
begin
  if v_role not in ('seeker', 'owner') then
    v_role := 'seeker'; -- super_admin tidak pernah lahir dari signup client
  end if;
  if v_full is null then
    raise exception 'full_name_required';
  end if;
  if v_tos is null or v_tos_at is null then
    raise exception 'tos_required';
  end if;
  insert into public.profiles (id, role, full_name, tos_version, tos_accepted_at, data_consent_at)
  values (
    new.id, v_role, v_full, v_tos, v_tos_at::timestamptz,
    case when coalesce(new.raw_user_meta_data->>'data_consent', '') in ('true', '1')
         then now() end
  );
  if v_role = 'owner' then
    insert into public.owner_profiles (user_id) values (new.id);
  end if;
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- trigger: kolom terlindungi profiles (role/status/tos) hanya admin
create or replace function public.profiles_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' and auth.uid() is not null and not public.app_is_admin() then
    if new.id is distinct from old.id
       or new.role is distinct from old.role
       or new.status is distinct from old.status
       or new.tos_version is distinct from old.tos_version
       or new.tos_accepted_at is distinct from old.tos_accepted_at
       or new.created_at is distinct from old.created_at then
      raise exception 'profiles_guard:kolom_terlindungi';
    end if;
  end if;
  return new;
end;
$$;
create trigger profiles_guard before update on public.profiles
  for each row execute function public.profiles_guard();
create trigger profiles_touch before update on public.profiles
  for each row execute function public.set_updated_at();

-- trigger: listing — active wajib verified; ubah verifikasi hanya admin/trusted
create or replace function public.properties_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    if new.verification_status <> 'pending'
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'properties_guard:verifikasi_ditolak';
    end if;
  else
    if auth.uid() is not null and not public.app_is_admin()
       and new.verification_status is distinct from old.verification_status then
      raise exception 'properties_guard:verifikasi_ditolak';
    end if;
  end if;
  if new.listing_status = 'active' and new.verification_status <> 'verified' then
    raise exception 'properties_guard:active_butuh_verified';
  end if;
  return new;
end;
$$;
create trigger properties_guard before insert or update on public.properties
  for each row execute function public.properties_guard();
create trigger properties_touch before update on public.properties
  for each row execute function public.set_updated_at();

-- trigger: machine state room + sentuh availability parent
create or replace function public.rooms_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
declare
  v_allowed text[][] := array[
    ['available','reserved'], ['available','maintenance'], ['available','inactive'],
    ['reserved','occupied'], ['reserved','available'],
    ['occupied','available'], ['occupied','maintenance'],
    ['maintenance','available'], ['maintenance','inactive']
  ];
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not exists (
      select 1 from unnest(v_allowed) as t(frm, to_)
      where t.frm = old.status and t.to_ = new.status
    ) then
      raise exception 'rooms_guard:transisi_tidak_valid:%->%', old.status, new.status;
    end if;
  end if;
  update public.properties
    set last_availability_update_at = now()
    where id = new.property_id;
  return new;
end;
$$;
create trigger rooms_guard before insert or update on public.rooms
  for each row execute function public.rooms_guard();
create trigger rooms_touch before update on public.rooms
  for each row execute function public.set_updated_at();
