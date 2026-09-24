-- CP-03B: RPC discovery & recommendation (kontrak: cp03a-api-contracts §2–3)
-- search_properties = SATU sumber list & map (AC-MAP-01). SECURITY INVOKER
-- (RLS aktif). Args GPS sesaat — TIDAK pernah disimpan (NFR-PRIV-01).
-- Return jsonb; cover berupa cover_path (client bangun URL public bucket).

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

create or replace function public.nearby_properties(
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer,
  p_filters jsonb default '{}'::jsonb,
  p_page integer default 1,
  p_page_size integer default 20
)
returns jsonb
language plpgsql stable security invoker
set search_path = public, extensions, pg_temp
as $$
begin
  if p_lat is null or p_lng is null then
    raise exception 'nearby_properties:wajib_lat_lng' using errcode = '22023';
  end if;
  if p_radius_m is null or p_radius_m < 1 or p_radius_m > 20000 then
    raise exception 'nearby_properties:radius_dalam_1_20000'
      using errcode = '22023';
  end if;
  -- lat/lng hanya argumen sesaat — tidak ada tulisan ke tabel mana pun
  return public.search_properties(
    p_filters := p_filters,
    p_sort := 'jarak',
    p_page := p_page,
    p_page_size := p_page_size,
    p_near_lat := p_lat,
    p_near_lng := p_lng,
    p_near_radius_m := p_radius_m
  );
end;
$$;

create or replace function public.campus_suggestions(
  p_q text default null,
  p_limit integer default 8
)
returns jsonb
language sql stable security invoker
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'items',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'location_label', coalesce(s.address, ''))
        order by s.name)
      from (
        select c.id, c.name, c.address
        from public.campuses c
        where c.is_active
          and (p_q is null or p_q = '' or c.name ilike '%' || p_q || '%')
        order by c.name
        limit least(greatest(coalesce(p_limit, 8), 1), 20)
      ) s
    ), '[]'::jsonb)
  );
$$;

-- feed: hard filter preferensi → skor 0–100 deterministik (bobot terparameterisasi
-- dari model_params aktif) → log recommendation_logs. Tanpa model aktif →
-- bobot default + model_name baseline-fallback (AC-REC-01/03). Skor = normalized
-- match BUKAN probability (FR-REC-04). popularity hanya komponen bobot 0
-- (default) / tie-break — rantai cold-start preferensi+geo (cp02-ml A9).
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

grant execute on function
  public.search_properties(jsonb, text, integer, integer, numeric[],
                           double precision, double precision, integer)
  to anon, authenticated, service_role;
grant execute on function
  public.nearby_properties(double precision, double precision, integer,
                           jsonb, integer, integer)
  to anon, authenticated, service_role;
grant execute on function
  public.campus_suggestions(text, integer)
  to anon, authenticated, service_role;
grant execute on function
  public.feed_recommendations(integer)
  to anon, authenticated, service_role;
