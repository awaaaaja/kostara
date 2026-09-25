-- CP-04B FIX: trigger facilities_deactivate harus SECURITY DEFINER.
-- Bug: trigger berjalan sebagai pemanggil (admin) → DELETE pada
-- property_facilities kena RLS (policy delete = pemilik properti) →
-- 0 baris terhapus; penanda tidak ikut hilang saat fasilitas dinonaktifkan
-- (AC-ADM-05 gagal lewat jalur admin REST). Supersede fungsi.

create or replace function public.facilities_deactivate()
returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.is_active = false and old.is_active = true then
    delete from public.property_facilities where facility_id = old.id;
  end if;
  return new;
end;
$$;
