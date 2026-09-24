-- CP-03B: helper baris/konteks (security definer — gate RLS & policy engine)
-- Semua helper self-guard / hanya membaca agregat non-privat.
-- Jalur trusted (service role / Management API / psql) = auth.uid() IS NULL.

create or replace function public.app_current_role()
returns text
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(
    (select role from public.profiles where id = auth.uid()),
    'anonymous'
  );
$$;

create or replace function public.app_is_admin()
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(
    (select role from public.profiles where id = auth.uid()) = 'super_admin',
    false
  );
$$;

create or replace function public.fn_owns_property(p_property_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.properties
    where id = p_property_id and owner_id = auth.uid()
  );
$$;

create or replace function public.fn_property_listable(p_property_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.properties
    where id = p_property_id
      and ((verification_status = 'verified' and listing_status = 'active')
           or owner_id = auth.uid())
  );
$$;

create or replace function public.fn_has_consent()
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(
    (select data_consent_at is not null from public.profiles where id = auth.uid()),
    false
  );
$$;

create or replace function public.fn_is_tenancy_party(p_tenancy_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.tenancies
    where id = p_tenancy_id
      and (seeker_id = auth.uid() or owner_id = auth.uid())
  );
$$;

create or replace function public.fn_is_tenancy_owner(p_tenancy_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.tenancies
    where id = p_tenancy_id and owner_id = auth.uid()
  );
$$;

create or replace function public.fn_can_review(p_tenancy_id uuid, p_review_type text)
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.tenancies
    where id = p_tenancy_id
      and seeker_id = auth.uid()
      and (p_review_type = 'pulse'
           or (p_review_type = 'final' and status = 'ended'))
  );
$$;

create or replace function public.fn_review_listable(p_review_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.reviews
    where id = p_review_id
      and (status = 'approved' or user_id = auth.uid())
  );
$$;

-- agregat popularitas non-privat (di-read feed/sort; RLS-agnostic)
create or replace function public.fn_property_popularity(p_property_id uuid)
returns bigint
language sql stable security definer set search_path = public, pg_temp as $$
  select count(*)::bigint
  from public.interactions
  where property_id = p_property_id;
$$;

-- model aktif; fallback = row 'baseline-fallback' bila tidak ada aktif (AC-REC-03)
create or replace function public.fn_active_recommender()
returns table (model_id uuid, model_name text, params jsonb)
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(a.id, f.id), coalesce(a.name, f.name), a.params
  from (select 1 as x) one
  left join lateral (
    select mv.id, mv.name, mp.params
    from public.model_versions mv
    join public.model_params mp on mp.model_version_id = mv.id
    where mv.kind = 'recommender' and mv.status = 'active'
    limit 1
  ) a on true
  left join lateral (
    select mv.id, mv.name
    from public.model_versions mv
    where mv.kind = 'recommender' and mv.name = 'baseline-fallback'
    limit 1
  ) f on true;
$$;

create or replace function public.audit_log_write(
  p_action text,
  p_target_type text default null,
  p_target_id uuid default null,
  p_detail jsonb default null
)
returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_id uuid;
begin
  if not public.app_is_admin() then
    raise exception 'audit_log_write:admin_saja';
  end if;
  insert into public.audit_logs
    (actor_id, actor_role, action, target_type, target_id, detail)
  values
    (auth.uid(), public.app_current_role(), p_action,
     p_target_type, p_target_id, p_detail)
  returning id into v_id;
  return v_id;
end;
$$;
