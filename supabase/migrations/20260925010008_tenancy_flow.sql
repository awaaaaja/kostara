-- CP-04A: alur tenancy (B11) — submit/activate/end (kontrak: cp03a-api-contracts §4)
-- SECURITY DEFINER + cek ownership di dalam fungsi (cp03a-backend-design §1.5/§4).
-- activate = 1 transaksi: accept → tenancy → room occupied → schedule + 12
-- payment_records (AC-TEN-01); idempotent via tenancies.request_id (AC-TEN-02).
-- Accept TIDAK dapat dicapai via REST (policy update dibatasi) — anti TOCTOU.

-- ===== 1. Tautan request → tenancy (idempotency key) =====
alter table public.tenancies
  add column if not exists request_id uuid references public.tenancy_requests(id);
create unique index if not exists tenancies_request_id_uq
  on public.tenancies (request_id);

-- ===== 2. submit_tenancy_request =====
create or replace function public.submit_tenancy_request(
  p_property_id uuid,
  p_room_id uuid,
  p_message text default null
)
returns jsonb
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_room record;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'submit_tenancy_request:belum_masuk';
  end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'seeker' then
    raise exception 'submit_tenancy_request:hanya_seeker';
  end if;
  if p_property_id is null or p_room_id is null then
    raise exception 'submit_tenancy_request:property_room_wajib';
  end if;
  if not public.fn_property_listable(p_property_id) then
    raise exception 'submit_tenancy_request:property_tidak_tersedia';
  end if;
  select id, property_id, status, price into v_room
  from public.rooms where id = p_room_id;
  if not found then
    raise exception 'submit_tenancy_request:room_tidak_ditemukan';
  end if;
  if v_room.property_id <> p_property_id then
    raise exception 'submit_tenancy_request:room_property_tidak_cocok';
  end if;
  if v_room.status <> 'available' then
    raise exception 'submit_tenancy_request:room_tidak_tersedia';
  end if;
  if exists (
    select 1 from public.properties where id = p_property_id and owner_id = v_uid
  ) then
    raise exception 'submit_tenancy_request:property_sendiri';
  end if;
  begin
    insert into public.tenancy_requests (property_id, room_id, seeker_id, message)
    values (p_property_id, p_room_id, v_uid, nullif(btrim(coalesce(p_message, '')), ''))
    returning id into v_id;
  exception when unique_violation then
    raise exception 'submit_tenancy_request:masih_ada_permintaan_pending';
  end;
  return (
    select to_jsonb(r) from public.tenancy_requests r where r.id = v_id
  );
end;
$$;
revoke all on function public.submit_tenancy_request(uuid, uuid, text) from public;
grant execute on function public.submit_tenancy_request(uuid, uuid, text)
  to authenticated;

-- ===== 3. activate_tenancy (atomik + idempotent) =====
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
  v_base date;
  v_first integer;
  v_m date;
  v_d integer;
  v_due date;
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

  -- 12 due date ke depan; due_day akhir-bulan di-clamp (31→28/29/30) (FR-PAY-01/02)
  v_base := date_trunc('month', v_start)::date;
  v_first := least(
    v_due_day,
    extract(day from (v_base + interval '1 month - 1 day'))::integer
  );
  v_due := make_date(
    extract(year from v_base)::integer,
    extract(month from v_base)::integer,
    v_first
  );
  if v_due < v_start then
    v_base := (v_base + interval '1 month')::date;
    v_first := least(
      v_due_day,
      extract(day from (v_base + interval '1 month - 1 day'))::integer
    );
    v_due := make_date(
      extract(year from v_base)::integer,
      extract(month from v_base)::integer,
      v_first
    );
  end if;
  v_next := v_due;
  for i in 0..11 loop
    v_m := (v_base + make_interval(months => i))::date;
    v_d := least(
      v_due_day,
      extract(day from (date_trunc('month', v_m) + interval '1 month - 1 day'))::integer
    );
    v_due := make_date(
      extract(year from v_m)::integer,
      extract(month from v_m)::integer,
      v_d
    );
    insert into public.payment_records (tenancy_id, due_date, amount)
    values (v_tid, v_due, v_amount);
  end loop;

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

-- ===== 4. end_tenancy (idempotent) =====
create or replace function public.end_tenancy(
  p_tenancy_id uuid,
  p_end_date date default null
)
returns jsonb
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_t record;
begin
  if v_uid is null then
    raise exception 'end_tenancy:belum_masuk';
  end if;
  if p_tenancy_id is null then
    raise exception 'end_tenancy:tenancy_wajib';
  end if;

  select id, property_id, room_id, owner_id, seeker_id, start_date,
         end_date, status
    into v_t
  from public.tenancies
  where id = p_tenancy_id
  for update;
  if not found then
    raise exception 'end_tenancy:tenancy_tidak_ditemukan';
  end if;
  if v_t.status = 'ended' then
    return (select to_jsonb(t) from public.tenancies t where t.id = v_t.id);
  end if;
  if v_t.status <> 'active' then
    raise exception 'end_tenancy:status_tidak_valid';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'super_admin' then
    if v_role is distinct from 'owner' or v_t.owner_id <> v_uid then
      raise exception 'end_tenancy:bukan_pemilik';
    end if;
  end if;
  if p_end_date is not null and p_end_date < v_t.start_date then
    raise exception 'end_tenancy:end_date_sebelum_start';
  end if;

  update public.tenancies
  set status = 'ended',
      ended_at = now(),
      end_date = coalesce(p_end_date, current_date)
  where id = v_t.id;

  update public.rooms set status = 'available' where id = v_t.room_id;

  return (select to_jsonb(t) from public.tenancies t where t.id = v_t.id);
end;
$$;
revoke all on function public.end_tenancy(uuid, date) from public;
grant execute on function public.end_tenancy(uuid, date) to authenticated;

-- ===== 5. Policy update tenancy_requests: accept HANYA lewat RPC =====
-- seekerpolicy update: hanya membatalkan permintaan sendiri saat pending.
create policy tenancy_requests_cancel on public.tenancy_requests
  for update to authenticated
  using (seeker_id = auth.uid() and status = 'pending')
  with check (
    seeker_id = auth.uid() and status in ('pending', 'cancelled')
  );
-- owner policy: menolak (dgn alasan, CHECK NOT NULL) — bukan menerima.
create policy tenancy_requests_reject on public.tenancy_requests
  for update to authenticated
  using (public.fn_owns_property(property_id))
  with check (
    public.fn_owns_property(property_id)
    and status in ('pending', 'rejected')
  );
-- admin: moderasi penuh.
create policy tenancy_requests_admin on public.tenancy_requests
  for update to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

drop policy if exists tenancy_requests_update on public.tenancy_requests;
