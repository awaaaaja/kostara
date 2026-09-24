-- CP-03B: RLS — semua tabel di-enable + matrix policy (cp02-test-plan TP-RLS-*)
-- Prinsip: default deny; publik hanya untuk listing verified+active & master aktif.

alter table public.profiles enable row level security;
alter table public.owner_profiles enable row level security;
alter table public.campuses enable row level security;
alter table public.facilities enable row level security;
alter table public.properties enable row level security;
alter table public.property_images enable row level security;
alter table public.rooms enable row level security;
alter table public.property_facilities enable row level security;
alter table public.user_preferences enable row level security;
alter table public.favorites enable row level security;
alter table public.interactions enable row level security;
alter table public.tenancy_requests enable row level security;
alter table public.tenancies enable row level security;
alter table public.payment_schedules enable row level security;
alter table public.payment_records enable row level security;
alter table public.reminders enable row level security;
alter table public.reviews enable row level security;
alter table public.review_aspect_scores enable row level security;
alter table public.reports enable row level security;
alter table public.model_versions enable row level security;
alter table public.model_params enable row level security;
alter table public.recommendation_logs enable row level security;
alter table public.audit_logs enable row level security;

-- P1: profiles — SELECT/UPDATE own + admin; INSERT via trigger (definer); no DELETE client
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.app_is_admin());
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.app_is_admin())
  with check (id = auth.uid() or public.app_is_admin());

-- owner_profiles
create policy owner_profiles_select on public.owner_profiles
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());
create policy owner_profiles_insert on public.owner_profiles
  for insert to authenticated
  with check (user_id = auth.uid() and verification_status = 'pending');
create policy owner_profiles_update on public.owner_profiles
  for update to authenticated
  using (user_id = auth.uid() or public.app_is_admin())
  with check (user_id = auth.uid() or public.app_is_admin());

-- master aktif = baca publik; tulis hanya trusted/admin path (tanpa policy insert/update)
create policy campuses_select on public.campuses
  for select
  using (is_active = true or public.app_is_admin());
create policy facilities_select on public.facilities
  for select
  using (is_active = true or public.app_is_admin());

-- P2: properties — publik hanya verified+active; owner lihat semua miliknya
create policy properties_select_public on public.properties
  for select
  using (verification_status = 'verified' and listing_status = 'active');
create policy properties_select_own on public.properties
  for select
  using (owner_id = auth.uid());
create policy properties_select_admin on public.properties
  for select
  using (public.app_is_admin());
create policy properties_insert on public.properties
  for insert to authenticated
  with check (owner_id = auth.uid());
create policy properties_update on public.properties
  for update to authenticated
  using (owner_id = auth.uid() or public.app_is_admin())
  with check (owner_id = auth.uid() or public.app_is_admin());

-- P2b: turunan listing — baca bila listable; tulis bila pemilik
create policy property_images_select on public.property_images
  for select
  using (public.fn_property_listable(property_id));
create policy property_images_insert on public.property_images
  for insert to authenticated
  with check (public.fn_owns_property(property_id));
create policy property_images_update on public.property_images
  for update to authenticated
  using (public.fn_owns_property(property_id))
  with check (public.fn_owns_property(property_id));
create policy property_images_delete on public.property_images
  for delete to authenticated
  using (public.fn_owns_property(property_id));

create policy rooms_select on public.rooms
  for select
  using (public.fn_property_listable(property_id));
create policy rooms_insert on public.rooms
  for insert to authenticated
  with check (public.fn_owns_property(property_id));
create policy rooms_update on public.rooms
  for update to authenticated
  using (public.fn_owns_property(property_id))
  with check (public.fn_owns_property(property_id));
create policy rooms_delete on public.rooms
  for delete to authenticated
  using (public.fn_owns_property(property_id));

create policy property_facilities_select on public.property_facilities
  for select
  using (public.fn_property_listable(property_id));
create policy property_facilities_insert on public.property_facilities
  for insert to authenticated
  with check (public.fn_owns_property(property_id));
create policy property_facilities_delete on public.property_facilities
  for delete to authenticated
  using (public.fn_owns_property(property_id));

-- P3: preferensi & discovery state milik sendiri
create policy user_preferences_all on public.user_preferences
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy favorites_select on public.favorites
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());
create policy favorites_insert on public.favorites
  for insert to authenticated
  with check (user_id = auth.uid());
create policy favorites_delete on public.favorites
  for delete to authenticated
  using (user_id = auth.uid());

-- P5: interactions — consent gate (AC-PRIV-03)
create policy interactions_select on public.interactions
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());
create policy interactions_insert on public.interactions
  for insert to authenticated
  with check (user_id = auth.uid() and public.fn_has_consent());

-- tenancy_requests: pihak (seeker/owner property) + admin
create policy tenancy_requests_select on public.tenancy_requests
  for select to authenticated
  using (seeker_id = auth.uid()
         or public.fn_owns_property(property_id)
         or public.app_is_admin());
create policy tenancy_requests_insert on public.tenancy_requests
  for insert to authenticated
  with check (seeker_id = auth.uid() and public.fn_property_listable(property_id));
create policy tenancy_requests_update on public.tenancy_requests
  for update to authenticated
  using ((seeker_id = auth.uid() and status = 'pending')
         or public.fn_owns_property(property_id)
         or public.app_is_admin())
  with check (seeker_id = auth.uid()
              or public.fn_owns_property(property_id)
              or public.app_is_admin());

-- P6: tenancies — pihak saja; mutasi HANYA via RPC definer/service (CP-04A)
create policy tenancies_select on public.tenancies
  for select to authenticated
  using (seeker_id = auth.uid()
         or owner_id = auth.uid()
         or public.app_is_admin());

-- payment: baca pihak; update paid = pemilik property / admin (trigger guard)
create policy payment_schedules_select on public.payment_schedules
  for select to authenticated
  using (public.fn_is_tenancy_party(tenancy_id) or public.app_is_admin());
create policy payment_schedules_update on public.payment_schedules
  for update to authenticated
  using (public.fn_is_tenancy_owner(tenancy_id) or public.app_is_admin())
  with check (public.fn_is_tenancy_owner(tenancy_id) or public.app_is_admin());

create policy payment_records_select on public.payment_records
  for select to authenticated
  using (public.fn_is_tenancy_party(tenancy_id) or public.app_is_admin());
create policy payment_records_update on public.payment_records
  for update to authenticated
  using (public.fn_is_tenancy_owner(tenancy_id) or public.app_is_admin())
  with check (public.fn_is_tenancy_owner(tenancy_id) or public.app_is_admin());

create policy reminders_select on public.reminders
  for select to authenticated
  using (public.fn_is_tenancy_party(tenancy_id) or public.app_is_admin());
create policy reminders_update on public.reminders
  for update to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

-- P3: reviews — publik approved; own non-approved; insert via eligibility;
-- update hanya admin (moderasi); tidak ada DELETE client (hide bukan hapus)
create policy reviews_select on public.reviews
  for select
  using (status = 'approved' or user_id = auth.uid() or public.app_is_admin());
create policy reviews_insert on public.reviews
  for insert to authenticated
  with check (user_id = auth.uid()
              and status = 'pending'
              and public.fn_can_review(tenancy_id, review_type));
create policy reviews_update on public.reviews
  for update to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

create policy review_aspect_scores_select on public.review_aspect_scores
  for select
  using (public.fn_review_listable(review_id) or public.app_is_admin());
create policy review_aspect_scores_admin on public.review_aspect_scores
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

create policy reports_select on public.reports
  for select to authenticated
  using (reporter_id = auth.uid() or public.app_is_admin());
create policy reports_insert on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');
create policy reports_update on public.reports
  for update to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

-- registry ML: baca admin; tulis pipeline via service role (bypass RLS)
create policy model_versions_select on public.model_versions
  for select to authenticated
  using (public.app_is_admin());
create policy model_params_select on public.model_params
  for select to authenticated
  using (public.app_is_admin());

-- P5: recommendation_logs — log feed sendiri; insert oleh RPC/app utk auth.uid()
create policy recommendation_logs_select on public.recommendation_logs
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());
create policy recommendation_logs_insert on public.recommendation_logs
  for insert to authenticated
  with check (user_id = auth.uid());

-- P4: audit_logs — SELECT admin saja; INSERT hanya via audit_log_write (definer)
create policy audit_logs_select on public.audit_logs
  for select to authenticated
  using (public.app_is_admin());

-- view privasi kolom (ADR-004): baca terbatas utk semua role
create view public.profiles_public as
  select id, full_name, avatar_url, role
  from public.profiles
  where status = 'active';
grant select on public.profiles_public to anon, authenticated, service_role;
