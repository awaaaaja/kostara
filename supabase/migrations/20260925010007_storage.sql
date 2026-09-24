-- CP-03B: storage buckets + policy (cp02-rls-storage §4)
-- Publik: avatars, property-images. Privat: verification-documents-private.
-- Path convention:
--   avatars:                    <user_id>/<file>
--   property-images:            <property_id>/<file>
--   verification-documents-...: <user_id>/<file>

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880,
     array['image/png', 'image/jpeg', 'image/webp']),
  ('property-images', 'property-images', true, 5242880,
     array['image/png', 'image/jpeg', 'image/webp']),
  ('verification-documents-private', 'verification-documents-private', false, 10485760,
     array['image/png', 'image/jpeg', 'application/pdf'])
on conflict (id) do nothing;

create policy "avatars public read" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "avatars owner insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and owner = (select auth.uid())
              and split_part(name, '/', 1) = (select auth.uid())::text);

create policy "avatars owner update" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and owner = (select auth.uid()))
  with check (bucket_id = 'avatars' and owner = (select auth.uid()));

create policy "avatars owner delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and owner = (select auth.uid()));

create policy "property images public read" on storage.objects
  for select using (bucket_id = 'property-images');

create policy "property images owner insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'property-images'
              and owner = (select auth.uid())
              and exists (
                select 1 from public.properties p
                where p.id::text = split_part(storage.objects.name, '/', 1)
                  and p.owner_id = (select auth.uid())));

create policy "property images owner delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'property-images'
         and owner = (select auth.uid())
         and exists (
           select 1 from public.properties p
           where p.id::text = split_part(storage.objects.name, '/', 1)
             and p.owner_id = (select auth.uid())));

create policy "verification docs owner read" on storage.objects
  for select using (bucket_id = 'verification-documents-private'
                    and (owner = (select auth.uid())
                         or public.app_is_admin()));

create policy "verification docs owner insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'verification-documents-private'
              and owner = (select auth.uid())
              and split_part(name, '/', 1) = (select auth.uid())::text
              and public.app_current_role() = 'owner');

create policy "verification docs owner delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'verification-documents-private'
         and owner = (select auth.uid()));
