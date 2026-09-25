-- CP-04B: ringkasan admin menghitung SELURUH rooms (AC-ADM-01).
-- Kebijakan lama hanya menampilkan rooms pada properti listable → dashboard
-- admin kehilangan 4 room seed (36 vs 40). Supersede: tambah clause admin.
-- Immutable: drop + create ulang policy (tidak mengedit migration lama).

drop policy if exists rooms_select on public.rooms;
create policy rooms_select on public.rooms
  for select
  using (public.fn_property_listable(property_id) or public.app_is_admin());
