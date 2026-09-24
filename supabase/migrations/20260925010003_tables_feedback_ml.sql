-- CP-03B: feedback, moderasi, ML registry, audit (cp02-schema-draft §5)

create table public.model_versions (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('recommender','review_nlp')),
  name text not null,
  artifact_uri text not null,
  metrics jsonb,
  dataset_version text not null,
  seed integer,
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  created_at timestamptz not null default now()
);
create unique index model_versions_one_active_per_kind
  on public.model_versions (kind) where status = 'active';

create table public.model_params (
  model_version_id uuid primary key references public.model_versions(id) on delete cascade,
  params jsonb not null,
  created_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  tenancy_id uuid not null references public.tenancies(id),
  property_id uuid not null,
  user_id uuid not null references public.profiles(id),
  review_type text not null default 'final'
    check (review_type in ('final','pulse')),
  rating_overall smallint not null check (rating_overall between 1 and 5),
  review_text text check (review_text is null or char_length(review_text) <= 1000),
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','hidden')),
  moderated_by uuid references public.profiles(id),
  moderation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenancy_id, review_type),
  foreign key (tenancy_id, property_id)
    references public.tenancies (id, property_id) on delete restrict
);
create index reviews_property_status_idx on public.reviews (property_id, status);
create trigger reviews_touch before update on public.reviews
  for each row execute function public.set_updated_at();

create table public.review_aspect_scores (
  review_id uuid not null references public.reviews(id) on delete cascade,
  aspect text not null check (aspect in (
    'cleanliness','security','internet','water','comfort','access','owner','value')),
  sentiment text not null check (sentiment in (
    'positive','negative','neutral','insufficient_evidence')),
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  source text not null check (source in ('manual','nlp')),
  model_version_id uuid references public.model_versions(id),
  primary key (review_id, aspect)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id),
  target_type text not null check (target_type in ('property','review','user')),
  target_id uuid not null,
  reason_code text not null,
  detail text,
  status text not null default 'open'
    check (status in ('open','resolved','rejected')),
  resolved_by uuid references public.profiles(id),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now()
);

create table public.recommendation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  model_version_id uuid references public.model_versions(id),
  rank integer not null,
  score numeric not null,
  reason_codes text[] not null default '{}',
  context jsonb,
  requested_at timestamptz not null default now()
);
create index recommendation_logs_user_time_idx
  on public.recommendation_logs (user_id, requested_at);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  actor_role text not null,
  action text not null,
  target_type text,
  target_id uuid,
  detail jsonb,
  created_at timestamptz not null default now()
);

-- trigger: insert status awal; update = moderasi admin saja, konten immutable
create or replace function public.reviews_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending'
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'reviews_guard:status_awal_pending';
    end if;
  else
    if new.tenancy_id is distinct from old.tenancy_id
       or new.property_id is distinct from old.property_id
       or new.user_id is distinct from old.user_id
       or new.review_type is distinct from old.review_type
       or new.rating_overall is distinct from old.rating_overall
       or new.review_text is distinct from old.review_text
       or new.created_at is distinct from old.created_at then
      raise exception 'reviews_guard:konten_immutable';
    end if;
    if (new.status is distinct from old.status
        or new.moderated_by is distinct from old.moderated_by
        or new.moderation_reason is distinct from old.moderation_reason)
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'reviews_guard:moderasi_admin_saja';
    end if;
  end if;
  return new;
end;
$$;
create trigger reviews_guard before insert or update on public.reviews
  for each row execute function public.reviews_guard();

-- trigger: submit verifikasi owner; perubahan status verifikasi = admin/trusted
create or replace function public.owner_profiles_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    if new.verification_status <> 'pending'
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'owner_profiles_guard:submit_pending_saja';
    end if;
  elsif auth.uid() is not null and not public.app_is_admin() then
    if new.verification_status is distinct from old.verification_status
       or new.reviewed_at is distinct from old.reviewed_at
       or new.reviewer_id is distinct from old.reviewer_id
       or new.reject_reason is distinct from old.reject_reason
       or new.user_id is distinct from old.user_id then
      raise exception 'owner_profiles_guard:keputusan_admin_saja';
    end if;
  end if;
  return new;
end;
$$;
create trigger owner_profiles_guard before insert or update on public.owner_profiles
  for each row execute function public.owner_profiles_guard();
