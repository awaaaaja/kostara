-- CP-04B: deaktivasi facility menghapus penanda listing (FR-ADM-04/AC-ADM-05).
-- Admin tulis facilities/campuses sudah ada di 20260925010010_cp04b_integration.sql
-- (facilities_admin, campuses_admin).

-- Catatan: re-aktivasi tidak mengembalikan penanda lama (owner menandai ulang
-- bila perlu) — keputusan sadar untuk invariant "tampil = aktif".
create or replace function public.facilities_deactivate()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if new.is_active = false and old.is_active = true then
    delete from public.property_facilities where facility_id = old.id;
  end if;
  return new;
end;
$$;

create trigger facilities_deactivate
  after update of is_active on public.facilities
  for each row execute function public.facilities_deactivate();
