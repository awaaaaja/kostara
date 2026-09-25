-- CP-04B: integrasi feedback, reminder pembayaran, admin, dan hapus akun
-- (cp02-requirements FR-PAY-03/FR-NOT-01/FR-ADM-*/FR-PRIV-02, AC-* terkait).
-- Non-destruktif: tambah kolom, ganti fungsi/policy, RPC baru.

-- ===== 1. reject wajib beralasan (AC-ADM-02/03) =====
alter table public.properties add column if not exists reject_reason text;

-- superseed properties_guard: reject butuh alasan; kolom reject_reason
-- dijaga sama seperti verification_status.
create or replace function public.properties_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    if new.verification_status <> 'pending'
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'properties_guard:verifikasi_ditolak';
    end if;
    if new.reject_reason is not null
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'properties_guard:alasan_hanya_admin';
    end if;
  else
    if auth.uid() is not null and not public.app_is_admin() then
      if new.verification_status is distinct from old.verification_status then
        raise exception 'properties_guard:verifikasi_ditolak';
      end if;
      if new.reject_reason is distinct from old.reject_reason then
        raise exception 'properties_guard:alasan_hanya_admin';
      end if;
    end if;
  end if;
  if new.listing_status = 'active' and new.verification_status <> 'verified' then
    raise exception 'properties_guard:active_butuh_verified';
  end if;
  if new.verification_status = 'rejected'
     and nullif(trim(coalesce(new.reject_reason, '')), '') is null then
    raise exception 'properties_guard:reject_butuh_alasan';
  end if;
  return new;
end;
$$;

-- superseed owner_profiles_guard: reject tanpa alasan ditolak (termasuk admin).
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
  if new.verification_status = 'rejected'
     and nullif(trim(coalesce(new.reject_reason, '')), '') is null then
    raise exception 'owner_profiles_guard:reject_butuh_alasan';
  end if;
  return new;
end;
$$;

-- ===== 2. profiles_guard: buka jalur khusus penghapusan akun =====
-- Flag hanya bisa diset di dalam transaksi RPC (set_config lokal);
-- schema tidak terekspos ke PostgREST sebagai fungsi → bukan backdoor klien.
create or replace function public.profiles_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' and auth.uid() is not null and not public.app_is_admin()
     and coalesce(current_setting('app.allow_profile_write', true), '') <> '1' then
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

-- ===== 3. payment_schedules: tenant boleh atur pengingat saja =====
create or replace function public.payment_schedules_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or public.app_is_admin()
     or public.fn_is_tenancy_owner(new.tenancy_id) then
    return new; -- owner/admin: jadwal tagihan penuh
  end if;
  if not public.fn_is_tenancy_party(new.tenancy_id) then
    raise exception 'payment_schedules_guard:bukan_pihak';
  end if;
  -- tenant: hanya reminder_offsets (+ updated_at) boleh berubah (FR-NOT-01)
  if new.tenancy_id is distinct from old.tenancy_id
     or new.next_due_date is distinct from old.next_due_date
     or new.amount is distinct from old.amount then
    raise exception 'payment_schedules_guard:hanya_reminder_offsets';
  end if;
  if exists (
    select 1 from unnest(new.reminder_offsets) x
    where x < 0 or x > 30
  ) or (
    select count(*) from (
      select distinct unnest(new.reminder_offsets) s
    ) d
  ) <> cardinality(new.reminder_offsets) then
    raise exception 'payment_schedules_guard:offset_tidak_valid';
  end if;
  return new;
end;
$$;
create trigger payment_schedules_guard before insert or update
  on public.payment_schedules
  for each row execute function public.payment_schedules_guard();

drop policy if exists payment_schedules_update on public.payment_schedules;
create policy payment_schedules_update on public.payment_schedules
  for update to authenticated
  using (public.fn_is_tenancy_owner(tenancy_id)
         or public.fn_is_tenancy_party(tenancy_id)
         or public.app_is_admin())
  with check (public.fn_is_tenancy_owner(tenancy_id)
              or public.fn_is_tenancy_party(tenancy_id)
              or public.app_is_admin());

-- ===== 4. reminders: pihak tenancy membuat/memperbarui catatan pengingat =====
alter table public.reminders alter column payment_record_id set not null;

create policy reminders_insert on public.reminders
  for insert to authenticated
  with check (public.fn_is_tenancy_party(tenancy_id)
              and status in ('scheduled', 'cancelled')
              and offset_days between 0 and 30);

drop policy if exists reminders_update on public.reminders;
create policy reminders_update on public.reminders
  for update to authenticated
  using (public.fn_is_tenancy_party(tenancy_id) or public.app_is_admin())
  with check (public.fn_is_tenancy_party(tenancy_id) or public.app_is_admin());

-- ===== 5. master data: CRUD admin (AC-ADM-05) =====
create policy campuses_admin on public.campuses
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

create policy facilities_admin on public.facilities
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

-- ===== 6. storage: super_admin membaca dokumen verifikasi (signed URL) =====
create policy "verification docs admin read" on storage.objects
  for select using (
    bucket_id = 'verification-documents-private' and public.app_is_admin()
  );

-- ===== 7. penghapusan akun (FR-PRIV-02 / AC-PRIV-02) =====
-- Anonimisasi, bukan hard-delete: UGC/moderasi tetap utuh, interaksi
-- dilepas dari identitas (retensi agregat untuk training), login dimatikan.
create or replace function public.delete_my_account()
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'delete_my_account:belum_login';
  end if;
  if exists (
    select 1 from public.tenancies
    where seeker_id = v_uid and status = 'active'
  ) then
    raise exception 'delete_my_account:tenancy_masih_aktif';
  end if;

  update public.tenancy_requests
    set status = 'cancelled'
    where seeker_id = v_uid and status = 'pending';

  delete from public.user_preferences where user_id = v_uid;
  delete from public.favorites where user_id = v_uid;

  update public.interactions set user_id = null where user_id = v_uid;
  update public.recommendation_logs set user_id = null where user_id = v_uid;

  -- dokumen verifikasi: file object dihapus app sebelum RPC (policy izin
  -- pemilik); baris owner_profiles ikut hilang sehingga path tak rujuk.
  delete from public.owner_profiles where user_id = v_uid;

  perform set_config('app.allow_profile_write', '1', true);
  update public.profiles
     set full_name = 'Pengguna Dihapus',
         avatar_url = null,
         phone = null,
         data_consent_at = null,
         status = 'suspended'
   where id = v_uid;

  -- matikan jalur login (email+password diganti; baris auth tetap ada
  -- agar jejak audit moderasi/UGC tidak putus rujuk)
  update auth.users
     set email = 'deleted-' || replace(v_uid::text, '-', '') || '@deleted.invalid',
         encrypted_password = null,
         raw_user_meta_data = '{}'::jsonb,
         phone = null
   where id = v_uid;

  insert into public.audit_logs
    (actor_id, actor_role, action, target_type, target_id, detail)
  values
    (v_uid, 'self', 'account_delete', 'profile', v_uid,
     jsonb_build_object('mode', 'anonymize', 'interactions_retained', true));

  return jsonb_build_object('deleted', true, 'interactions_retained', true);
end;
$$;
revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;


-- ===== supersede: filter facilities.is_active (AC-ADM-05) =====
-- search: daftar fasilitas tampil & filter hanya memakai fasilitas aktif.
create or replace function public.search_properties(
  p_filters jsonb default '{}'::jsonb,
  p_sort text default 'relevansi',
  p_page integer default 1,
  p_page_size integer default 20,
  p_bbox numeric[] default null,
  p_near_lat double precision default null,
  p_near_lng double precision default null,
  p_near_radius_m integer default null
)
returns jsonb
language plpgsql stable security invoker
set search_path = public, extensions, pg_temp
as $$
declare
  v_sort text := coalesce(p_sort, 'relevansi');
  v_page integer := coalesce(p_page, 1);
  v_size integer := coalesce(p_page_size, 20);
  f jsonb := coalesce(p_filters, '{}'::jsonb);
  v_price_min integer;
  v_price_max integer;
  v_gender text;
  v_room_types text[];
  v_facility_ids uuid[];
  v_rating_min numeric;
  v_available boolean;
  v_campus_id uuid;
  v_max_dist integer;
  v_move_in date;
  v_q text;
  v_items jsonb;
  v_has_more boolean := false;
begin
  if v_sort not in ('relevansi', 'harga', 'jarak', 'popularity') then
    raise exception 'search_properties:sort_tidak_valid: %', v_sort
      using errcode = '22023';
  end if;
  if v_page < 1 then
    raise exception 'search_properties:page_tidak_valid' using errcode = '22023';
  end if;
  if v_size < 1 or v_size > 20 then
    raise exception 'search_properties:page_size_dalam_1_20' using errcode = '22023';
  end if;
  if p_bbox is not null and cardinality(p_bbox) <> 4 then
    raise exception 'search_properties:bbox_tidak_valid' using errcode = '22023';
  end if;
  if (p_near_lat is null) <> (p_near_lng is null) then
    raise exception 'search_properties:near_lat_lng_paired' using errcode = '22023';
  end if;
  if p_near_radius_m is not null and p_near_lat is null then
    raise exception 'search_properties:radius_tanpa_near' using errcode = '22023';
  end if;
  if p_near_radius_m is not null
     and (p_near_radius_m < 1 or p_near_radius_m > 20000) then
    raise exception 'search_properties:radius_dalam_1_20000' using errcode = '22023';
  end if;

  -- allow-list filter (cp03a-api-contracts §2)
  v_price_min := nullif(f->>'price_min', '')::integer;
  v_price_max := nullif(f->>'price_max', '')::integer;
  if v_price_min is not null and v_price_min < 0 then
    raise exception 'search_properties:price_min_negatif' using errcode = '22023';
  end if;
  if v_price_min is not null and v_price_max is not null
     and v_price_min > v_price_max then
    raise exception 'search_properties:rentang_price_tidak_valid'
      using errcode = '22023';
  end if;
  v_gender := nullif(f->>'gender', '');
  if v_gender is not null
     and v_gender not in ('male_only', 'female_only', 'any') then
    raise exception 'search_properties:gender_tidak_valid' using errcode = '22023';
  end if;
  v_room_types := nullif(array(
    select v
    from jsonb_array_elements_text(coalesce(f->'room_types', '[]'::jsonb)) v
    where v in ('single', 'shared', 'studio')
  ), '{}');
  v_facility_ids := nullif(array(
    select v::uuid
    from jsonb_array_elements_text(coalesce(f->'facility_ids', '[]'::jsonb)) v
  ), '{}');
  v_rating_min := nullif(f->>'rating_min', '')::numeric;
  if v_rating_min is not null
     and (v_rating_min < 1 or v_rating_min > 5) then
    raise exception 'search_properties:rating_min_dalam_1_5'
      using errcode = '22023';
  end if;
  v_available := coalesce(nullif(f->>'available_only', '')::boolean, true);
  v_campus_id := nullif(f->>'campus_id', '')::uuid;
  v_max_dist := nullif(f->>'max_distance_m', '')::integer;
  if v_max_dist is not null and v_max_dist < 1 then
    raise exception 'search_properties:max_distance_tidak_valid'
      using errcode = '22023';
  end if;
  v_move_in := nullif(f->>'move_in_from', '')::date;
  v_q := nullif(f->>'q', '');
  if v_q is not null then
    v_q := '%' || v_q || '%';
  end if;
  if v_campus_id is not null
     and not exists (
       select 1 from public.campuses c
       where c.id = v_campus_id) then
    raise exception 'search_properties:kampus_tidak_ditemukan'
      using errcode = '22023';
  end if;

  with b as (
    select
      case when p_bbox is not null
        then st_makeenvelope(p_bbox[1], p_bbox[2], p_bbox[3], p_bbox[4], 4326)::geography
      end as bbox_geog,
      case when p_near_lat is not null
        then st_setsrid(st_makepoint(p_near_lng, p_near_lat), 4326)::geography
      end as near_geog
  ),
  cand as (
    select
      p.id, p.name, p.gender_policy, p.last_availability_update_at,
      st_y(p.location::geometry) as lat,
      st_x(p.location::geometry) as lng,
      rm.price_from, rm.availability,
      coalesce(rev.rating_avg, 0)::numeric(3, 2) as rating_avg,
      coalesce(rev.rating_count, 0) as rating_count,
      case
        when b2.near_geog is not null
          then st_distance(p.location, b2.near_geog)
        when v_campus_id is not null
          then st_distance(p.location, c.location)
      end as distance_m,
      img.cover_path,
      coalesce(fac.facilities, '{}'::text[]) as facilities,
      public.fn_property_popularity(p.id) as popularity
    from public.properties p
    cross join b b2
    join lateral (
      select
        case when v_available
          then min(r.price) filter (where r.status = 'available')
          else min(r.price)
        end::integer as price_from,
        count(*) filter (where r.status = 'available')::integer as availability
      from public.rooms r
      where r.property_id = p.id
        and (v_room_types is null or r.room_type = any (v_room_types))
    ) rm on (not v_available or coalesce(rm.availability, 0) > 0)
    left join lateral (
      select avg(rv.rating_overall)::numeric(3, 2) as rating_avg,
             count(*)::integer as rating_count
      from public.reviews rv
      where rv.property_id = p.id and rv.status = 'approved'
    ) rev on true
    left join lateral (
      select i.storage_path as cover_path
      from public.property_images i
      where i.property_id = p.id
      order by i.is_cover desc, i.sort_order, i.id
      limit 1
    ) img on true
    left join lateral (
      select array_agg(fa.name order by fa.name) as facilities
      from public.property_facilities pf
      join public.facilities fa on fa.id = pf.facility_id
           and fa.is_active
      where pf.property_id = p.id
    ) fac on true
    left join public.campuses c on c.id = v_campus_id
    where p.verification_status = 'verified'
      and p.listing_status = 'active'
      and (b2.bbox_geog is null or p.location && b2.bbox_geog)
      and (b2.near_geog is null
           or st_dwithin(p.location, b2.near_geog, p_near_radius_m))
      and (v_campus_id is null
           or st_dwithin(p.location, c.location, coalesce(v_max_dist, 3000)))
      and (v_price_min is null or rm.price_from >= v_price_min)
      and (v_price_max is null or rm.price_from <= v_price_max)
      and (v_gender is null or p.gender_policy = 'any'
           or p.gender_policy = v_gender)
      and (v_rating_min is null or coalesce(rev.rating_avg, 0) >= v_rating_min)
      and (v_q is null or p.name ilike v_q or p.address ilike v_q)
      and (v_move_in is null or exists (
        select 1 from public.rooms r2
        where r2.property_id = p.id
          and r2.status = 'available'
          and (r2.availability_date is null or r2.availability_date <= v_move_in)))
      and (v_facility_ids is null or (
        select count(*)
        from public.property_facilities pf2
        join public.facilities fa2 on fa2.id = pf2.facility_id
             and fa2.is_active
        where pf2.property_id = p.id
          and pf2.facility_id = any (v_facility_ids)) = cardinality(v_facility_ids))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id,
      'name', s.name,
      'price_from', s.price_from,
      'cover_path', s.cover_path,
      'rating_avg', s.rating_avg,
      'rating_count', s.rating_count,
      'distance_m', case when s.distance_m is null
                         then null else round(s.distance_m::numeric) end,
      'availability', s.availability,
      'gender_policy', s.gender_policy,
      'facilities', s.facilities,
      'lat', s.lat,
      'lng', s.lng,
      'updated_at', s.last_availability_update_at
    ) order by
      s.o_price asc nulls last,
      s.o_dist asc nulls last,
      s.o_pop desc nulls last,
      s.o_rating desc nulls last,
      s.o_pop2 desc nulls last,
      s.id asc
  ), '[]'::jsonb)
  into v_items
  from (
    select
      c.*,
      case v_sort when 'harga' then c.price_from end as o_price,
      case v_sort when 'jarak' then c.distance_m end as o_dist,
      case when v_sort = 'popularity' then c.popularity end as o_pop,
      case when v_sort = 'relevansi' then c.rating_avg end as o_rating,
      case when v_sort = 'relevansi' then c.popularity end as o_pop2
    from cand c
    order by
      case v_sort when 'harga' then c.price_from end asc nulls last,
      case v_sort when 'jarak' then c.distance_m end asc nulls last,
      case when v_sort = 'popularity' then c.popularity end desc nulls last,
      case when v_sort = 'relevansi' then c.rating_avg end desc nulls last,
      case when v_sort = 'relevansi' then c.popularity end desc nulls last,
      c.id asc
    limit v_size + 1
    offset (v_page - 1) * v_size
  ) s;

  if jsonb_array_length(v_items) > v_size then
    v_has_more := true;
    select coalesce(jsonb_agg(e.val), '[]'::jsonb)
    into v_items
    from jsonb_array_elements(v_items) with ordinality as e(val, ord)
    where e.ord <= v_size;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'page', v_page,
    'page_size', v_size,
    'has_more', v_has_more
  );
end;
$$;

-- feed: komponen skor fasilitas hanya menghitung fasilitas aktif.
create or replace function public.feed_recommendations(
  p_limit integer default 12
)
returns jsonb
language plpgsql security invoker
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_model_id uuid;
  v_model_name text;
  v_params jsonb;
  v_has_prefs boolean := false;
  v_bmin integer;
  v_bmax integer;
  v_gender text;
  v_campus_id uuid;
  v_max_dist integer;
  v_facs uuid[];
  v_items jsonb;
begin
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'feed_recommendations:limit_dalam_1_50'
      using errcode = '22023';
  end if;

  select m.model_id, m.model_name, m.params
    into v_model_id, v_model_name, v_params
  from public.fn_active_recommender() m;

  if v_uid is not null then
    select p.budget_min, p.budget_max, p.gender_preference,
           p.primary_campus_id, coalesce(p.max_distance_m, 3000),
           p.facility_priority
      into v_bmin, v_bmax, v_gender, v_campus_id, v_max_dist, v_facs
    from public.user_preferences p
    where p.user_id = v_uid;
    v_has_prefs := found;
  end if;

  with pref as (
    select
      case when v_has_prefs then v_bmin end as bmin,
      case when v_has_prefs then v_bmax end as bmax,
      case when v_has_prefs then v_gender end as gender,
      case when v_has_prefs then v_campus_id end as campus_id,
      case when v_has_prefs then v_max_dist end as max_dist,
      case when v_has_prefs then v_facs end as facs
  ),
  params as (
    select
      coalesce((v_params->>'w_budget')::numeric, 0.35) as w_budget,
      coalesce((v_params->>'w_campus')::numeric, 0.30) as w_campus,
      coalesce((v_params->>'w_facility')::numeric, 0.15) as w_facility,
      coalesce((v_params->>'w_rating')::numeric, 0.20) as w_rating,
      coalesce((v_params->>'w_trending')::numeric, 0.0) as w_trending
  ),
  cand as (
    select
      p.id, p.name,
      rm.price_from,
      coalesce(rev.rating_avg, 0)::numeric(3, 2) as rating_avg,
      coalesce(rev.rating_count, 0) as rating_count,
      st.distance_m,
      coalesce(fac.matched, 0) as matched,
      public.fn_property_popularity(p.id) as popularity,
      coalesce(asp.positives, 0) as positives
    from public.properties p
    cross join pref pf
    join lateral (
      select min(r.price) filter (where r.status = 'available')::integer
               as price_from,
             count(*) filter (where r.status = 'available')::integer
               as availability
      from public.rooms r
      where r.property_id = p.id
    ) rm on (rm.availability > 0)
    left join lateral (
      select avg(rv.rating_overall)::numeric(3, 2) as rating_avg,
             count(*)::integer as rating_count
      from public.reviews rv
      where rv.property_id = p.id and rv.status = 'approved'
    ) rev on true
    left join lateral (
      select st_distance(p.location, c.location) as distance_m
      from public.campuses c
      where c.id = pf.campus_id
    ) st on true
    left join lateral (
      select count(*) as matched
      from public.property_facilities pfac
      join public.facilities fa on fa.id = pfac.facility_id
           and fa.is_active
      where pfac.property_id = p.id
        and pfac.facility_id = any (pf.facs)
    ) fac on true
    left join lateral (
      select count(*) as positives
      from public.review_aspect_scores ras
      join public.reviews rv2 on rv2.id = ras.review_id
      where rv2.property_id = p.id
        and rv2.status = 'approved'
        and ras.sentiment = 'positive'
    ) asp on true
    where p.verification_status = 'verified'
      and p.listing_status = 'active'
      and (pf.bmax is null or rm.price_from <= pf.bmax)
      and (pf.bmin is null or rm.price_from >= pf.bmin)
      and (pf.gender is null or p.gender_policy = 'any'
           or p.gender_policy = pf.gender)
      and (pf.campus_id is null or st.distance_m is null
           or st.distance_m <= pf.max_dist)
  ),
  scored as (
    select
      c.id as property_id,
      c.name,
      c.popularity,
      c.positives,
      c.rating_avg,
      c.rating_count,
      pf.bmax, pf.campus_id, pf.facs,
      (case
        when pf.bmax is null or pf.bmax = 0 then 0.5
        when c.price_from between pf.bmin and pf.bmax
          then greatest(0, 1 - abs(c.price_from::numeric - (pf.bmin + pf.bmax) / 2.0)
                            / greatest(pf.bmax - pf.bmin, 1))
        else greatest(0, 1 - least(abs(c.price_from - pf.bmax),
                                   abs(c.price_from - coalesce(pf.bmin, 0)))::numeric
                           / greatest(pf.bmax, 1))
      end)::numeric as comp_budget,
      (case
        when c.distance_m is null then 0.5
        else greatest(0, 1 - c.distance_m / greatest(pf.max_dist, 1)::double precision)
      end)::numeric as comp_campus,
      (case
        when pf.facs is null or cardinality(pf.facs) = 0 then 0.5
        else c.matched::numeric / cardinality(pf.facs)
      end)::numeric as comp_facility,
      (case
        when c.rating_count = 0 then 0.5
        else c.rating_avg / 5.0
      end)::numeric as comp_rating,
      prm.w_budget, prm.w_campus, prm.w_facility, prm.w_rating, prm.w_trending
    from cand c
    cross join pref pf
    cross join params prm
  ),
  with_score as (
    select
      s.*,
      least(100, greatest(0, round(
        100 * (
          s.w_budget * s.comp_budget
          + s.w_campus * s.comp_campus
          + s.w_facility * s.comp_facility
          + s.w_rating * s.comp_rating
          + s.w_trending * least(1.0::numeric, (ln(1 + s.popularity) / ln(101))::numeric)
        )
        / greatest(s.w_budget + s.w_campus + s.w_facility + s.w_rating + s.w_trending, 0.0001)
      )))::integer as score,
      array_remove(array[
        case when s.comp_budget >= 0.60 and s.bmax is not null then 'budget_fit' end,
        case when s.comp_campus >= 0.60 and s.campus_id is not null then 'near_campus' end,
        case when s.comp_facility > 0 and s.facs is not null
              and cardinality(s.facs) > 0 then 'facility_match' end,
        case when s.rating_count >= 1 and s.rating_avg >= 4.0
              then 'high_verified_rating' end,
        case when s.positives > 0 then 'positive_aspects' end,
        case when (ln(1 + s.popularity) / ln(101))::numeric >= 0.70
              then 'trending' end
      ], null) as reasons_raw
    from scored s
  ),
  ordered as (
    select t.property_id, t.name, t.score, t.popularity, t.reasons_raw, t.rn
    from (
      select
        w.property_id, w.name, w.score, w.popularity, w.reasons_raw,
        row_number() over (
          order by w.score desc, w.popularity desc, w.property_id
        ) as rn
      from with_score w
    ) t
    where t.rn <= p_limit
  ),
  ins as (
    insert into public.recommendation_logs
      (user_id, property_id, model_version_id, rank, score, reason_codes, context)
    select v_uid, o.property_id, v_model_id, o.rn::integer, o.score,
           case when cardinality(o.reasons_raw) = 0
                then array['trending'] else o.reasons_raw end,
           jsonb_build_object('surface', 'feed')
    from ordered o
    where v_uid is not null
    returning id
  )
  select jsonb_build_object(
    'items',
    coalesce(jsonb_agg(jsonb_build_object(
      'property_id', o.property_id,
      'display_name', o.name,
      'score', o.score,
      'rank', o.rn,
      'reason_codes', case when cardinality(o.reasons_raw) = 0
                           then array['trending'] else o.reasons_raw end
    ) order by o.rn), '[]'::jsonb),
    'model_name', coalesce(v_model_name, 'baseline-none')
  )
  into v_items
  from ordered o;

  return v_items;
end;
$$;
