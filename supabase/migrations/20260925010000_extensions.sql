-- CP-03B: extensions + shared trigger helpers
-- postgis dipasang di schema public agar tipe geography & fungsi spatial
-- ter-resolve pada search_path default (anon/authenticated).

create extension if not exists postgis with schema public;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'BEFORE UPDATE: isi updated_at otomatis. Dipakai tabel yang punya kolom updated_at.';
