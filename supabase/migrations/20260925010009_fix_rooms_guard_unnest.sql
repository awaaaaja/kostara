-- CP-04A fix: rooms_guard memakai unnest 2D dengan alias 2 kolom (as t(frm, to_)).
-- unnest(text[][]) di FROM menghasilkan SATU kolom text (di-flatten) → 42P10/42804.
-- Kontainment @> juga salah: cek elemen tunggal, bukan pasangan baris (available dan
-- occupied keduanya ada di array → dianggap valid). Perbaikan: generate_subscripts.
-- Bug ini lolos test karena pesan error tetap memuat "rooms_guard" di CONTEXT.

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
      select 1
      from generate_subscripts(v_allowed, 1) as s(i)
      where v_allowed[s.i][1] = old.status
        and v_allowed[s.i][2] = new.status
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
