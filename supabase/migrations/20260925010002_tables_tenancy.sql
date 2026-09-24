-- CP-03B: preferensi, discovery state, tenancy & payment (cp02-schema-draft §3–4)

create table public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  primary_campus_id uuid references public.campuses(id),
  budget_min integer not null check (budget_min >= 0),
  budget_max integer not null check (budget_max >= budget_min),
  gender_preference text check (gender_preference in ('male_only','female_only','any')),
  transport_mode text check (transport_mode in ('walk','bike','motorcycle','public_transport')),
  max_distance_m integer check (max_distance_m is null or max_distance_m > 0),
  max_travel_minutes integer check (max_travel_minutes is null or max_travel_minutes > 0),
  move_in_date date,
  facility_priority uuid[],
  updated_at timestamptz not null default now()
);
create index user_preferences_facility_priority_gin
  on public.user_preferences using gin (facility_priority);
create trigger user_preferences_touch before update on public.user_preferences
  for each row execute function public.set_updated_at();

create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, property_id)
);

create table public.interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  event_type text not null check (event_type in (
    'app_open','onboarding_complete','recommendation_impression',
    'property_view','property_save','property_unsave','compare_add',
    'map_search_area','near_me_search','filter_apply','tenancy_request',
    'tenancy_accepted','payment_due_view','review_submit')),
  event_weight numeric,
  source text not null,
  session_id text,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index interactions_user_time_idx on public.interactions (user_id, occurred_at);
create index interactions_property_event_idx on public.interactions (property_id, event_type);

create table public.tenancy_requests (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id),
  room_id uuid not null references public.rooms(id),
  seeker_id uuid not null references public.profiles(id),
  status text not null default 'pending'
    check (status in ('pending','accepted','rejected','cancelled')),
  message text,
  decided_at timestamptz,
  decided_by uuid references public.profiles(id),
  reject_reason text,
  created_at timestamptz not null default now(),
  check (status <> 'rejected' or reject_reason is not null)
);
create unique index tenancy_requests_pending_uq
  on public.tenancy_requests (room_id, seeker_id) where status = 'pending';

create table public.tenancies (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id),
  room_id uuid not null references public.rooms(id),
  seeker_id uuid not null references public.profiles(id),
  owner_id uuid not null references public.profiles(id),
  start_date date not null,
  end_date date,
  billing_cycle text not null default 'monthly' check (billing_cycle = 'monthly'),
  amount integer not null check (amount > 0),
  due_day smallint not null check (due_day between 1 and 31),
  status text not null default 'active'
    check (status in ('active','ended','cancelled')),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  check (end_date is null or end_date >= start_date),
  unique (id, property_id)
);
create unique index tenancies_one_active_per_room
  on public.tenancies (room_id) where status = 'active';
create index tenancies_seeker_status_idx on public.tenancies (seeker_id, status);
create index tenancies_owner_status_idx on public.tenancies (owner_id, status);

create table public.payment_schedules (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null unique references public.tenancies(id) on delete cascade,
  next_due_date date not null,
  amount integer not null check (amount > 0),
  reminder_offsets integer[] not null default '{7,3,1,0}',
  timezone text not null default 'Asia/Jakarta',
  updated_at timestamptz not null default now()
);
create trigger payment_schedules_touch before update on public.payment_schedules
  for each row execute function public.set_updated_at();

create table public.payment_records (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references public.tenancies(id) on delete cascade,
  due_date date not null,
  amount integer not null check (amount > 0),
  status text not null default 'unpaid'
    check (status in ('unpaid','paid','overdue')),
  paid_at timestamptz,
  marked_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (tenancy_id, due_date)
);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references public.tenancies(id) on delete cascade,
  payment_record_id uuid references public.payment_records(id) on delete cascade,
  fire_at timestamptz not null,
  offset_days integer not null check (offset_days between 0 and 30),
  status text not null default 'scheduled'
    check (status in ('scheduled','fired','cancelled')),
  local_notification_id text,
  created_at timestamptz not null default now()
);
create unique index reminders_scheduled_uq
  on public.reminders (payment_record_id, offset_days) where status = 'scheduled';

-- trigger: room pada request harus valid & milik property tsb
create or replace function public.tenancy_requests_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
declare
  v_pid uuid;
  v_status text;
begin
  select property_id, status into v_pid, v_status
  from public.rooms where id = new.room_id;
  if v_pid is null then
    raise exception 'tenancy_requests_guard:room_tidak_valid';
  end if;
  if v_pid <> new.property_id then
    raise exception 'tenancy_requests_guard:room_property_tidak_cocok';
  end if;
  if new.status = 'pending' and v_status <> 'available' then
    raise exception 'tenancy_requests_guard:room_tidak_tersedia';
  end if;
  if auth.uid() is not null and new.seeker_id = auth.uid() then
    if exists (select 1 from public.properties where id = new.property_id and owner_id = auth.uid()) then
      raise exception 'tenancy_requests_guard:property_sendiri';
    end if;
  end if;
  return new;
end;
$$;
create trigger tenancy_requests_guard before insert or update on public.tenancy_requests
  for each row execute function public.tenancy_requests_guard();

-- trigger: tandai paid_at/marked_by; mutasi status hanya pemilik property / admin
create or replace function public.payment_records_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' then
    if new.status = 'paid' and old.status is distinct from 'paid' then
      new.paid_at := coalesce(new.paid_at, now());
      new.marked_by := coalesce(new.marked_by, auth.uid());
    end if;
    if new.status is distinct from old.status
       and auth.uid() is not null and not public.app_is_admin() then
      if not public.fn_is_tenancy_owner(old.tenancy_id) then
        raise exception 'payment_records_guard:bukan_pemilik';
      end if;
      if new.status = 'unpaid' and old.status = 'paid' then
        raise exception 'payment_records_guard:batal_bayar_admin_saja';
      end if;
    end if;
  end if;
  return new;
end;
$$;
create trigger payment_records_guard before update on public.payment_records
  for each row execute function public.payment_records_guard();
