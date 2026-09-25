-- CP-04B: kalkulator due date terpusat (TP-PAY-01) + activate_tenancy supersede.
-- Immutable migration: hanya menambah fn & mengganti definisi fungsi.

-- CP-04B: kalkulator due date terpusat (FR-PAY-01/02, TP-PAY-01).
-- Dipakai activate_tenancy dan unit test; murni komputasi, tanpa tabel.
create or replace function public.fn_generate_due_dates(
  p_start date,
  p_due_day integer,
  p_count integer
) returns setof date
language plpgsql immutable
set search_path = pg_catalog, pg_temp as $$
declare
  v_base date := date_trunc('month', p_start)::date;
  v_due date;
begin
  -- due bulan start; bila tanggal due sudah lewat → geser bulan berikutnya
  v_due := make_date(
    extract(year from v_base)::integer,
    extract(month from v_base)::integer,
    least(p_due_day,
          extract(day from (v_base + interval '1 month - 1 day'))::integer)
  );
  if v_due < p_start then
    v_base := (v_base + interval '1 month')::date;
  end if;
  for i in 0..p_count - 1 loop
    return next make_date(
      extract(year from (v_base + make_interval(months => i)))::integer,
      extract(month from (v_base + make_interval(months => i)))::integer,
      least(
        p_due_day,
        extract(day from (date_trunc('month', v_base + make_interval(months => i))
                          + interval '1 month - 1 day'))::integer
      )
    );
  end loop;
end;
$$;

-- activate_tenancy supersede: badan sama, pembuatan due memakai fn di atas.
create or replace function public.activate_tenancy(p_request_id uuid)
returns jsonb
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_req record;
  v_room record;
  v_prop_owner uuid;
  v_tid uuid;
  v_start date := current_date;
  v_due_day integer;
  v_amount integer;
  v_next date;
begin
  if v_uid is null then
    raise exception 'activate_tenancy:belum_masuk';
  end if;
  if p_request_id is null then
    raise exception 'activate_tenancy:request_wajib';
  end if;

  select id, property_id, room_id, seeker_id, status, decided_at
    into v_req
  from public.tenancy_requests
  where id = p_request_id
  for update;
  if not found then
    raise exception 'activate_tenancy:request_tidak_ditemukan';
  end if;

  -- idempotent: accept kedua mengembalikan tenancy yang sama (AC-TEN-02)
  if v_req.status = 'accepted' then
    select id into v_tid from public.tenancies where request_id = v_req.id;
    if v_tid is null then
      raise exception 'activate_tenancy:konsistensi_request_tenancy';
    end if;
    return (
      select jsonb_build_object(
        'tenancy', to_jsonb(t),
        'next_due_date', (
          select s.next_due_date from public.payment_schedules s
          where s.tenancy_id = t.id
        )
      )
      from public.tenancies t where t.id = v_tid
    );
  end if;
  if v_req.status <> 'pending' then
    raise exception 'activate_tenancy:status_tidak_valid';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'owner' then
    raise exception 'activate_tenancy:hanya_owner';
  end if;
  select owner_id into v_prop_owner from public.properties where id = v_req.property_id;
  if v_prop_owner is distinct from v_uid then
    raise exception 'activate_tenancy:bukan_pemilik_property';
  end if;

  select id, status, price into v_room
  from public.rooms where id = v_req.room_id
  for update;
  if not found then
    raise exception 'activate_tenancy:room_tidak_ditemukan';
  end if;
  if v_room.status not in ('available', 'reserved') then
    raise exception 'activate_tenancy:room_sudah_terisi';
  end if;
  if v_room.price is null or v_room.price <= 0 then
    raise exception 'activate_tenancy:harga_kamar_tidak_valid';
  end if;

  v_amount := v_room.price;
  v_due_day := extract(day from v_start)::integer;

  insert into public.tenancies (
    request_id, property_id, room_id, seeker_id, owner_id,
    start_date, billing_cycle, amount, due_day, status
  )
  values (
    v_req.id, v_req.property_id, v_req.room_id, v_req.seeker_id, v_uid,
    v_start, 'monthly', v_amount, v_due_day, 'active'
  )
  returning id into v_tid;

  -- room → occupied (FSM: available→reserved→occupied, dua statement terpisah)
  if v_room.status = 'available' then
    update public.rooms set status = 'reserved' where id = v_room.id;
  end if;
  update public.rooms set status = 'occupied' where id = v_room.id;

  update public.tenancy_requests
  set status = 'accepted', decided_at = now(), decided_by = v_uid
  where id = v_req.id;

  -- 12 due date ke depan; due akhir bulan di-clamp 31→28/29/30 (FR-PAY-01/02)
  -- kalkulator terpusat fn_generate_due_dates (unit-test TP-PAY-01).
  v_next := (
    select * from public.fn_generate_due_dates(v_start, v_due_day, 1) limit 1
  );
  insert into public.payment_records (tenancy_id, due_date, amount)
  select v_tid, d, v_amount
    from public.fn_generate_due_dates(v_start, v_due_day, 12) AS t(d);

  insert into public.payment_schedules (tenancy_id, next_due_date, amount)
  values (v_tid, v_next, v_amount);

  return (
    select jsonb_build_object(
      'tenancy', to_jsonb(t),
      'next_due_date', v_next
    )
    from public.tenancies t where t.id = v_tid
  );
end;
$$;
revoke all on function public.activate_tenancy(uuid) from public;
grant execute on function public.activate_tenancy(uuid) to authenticated;

