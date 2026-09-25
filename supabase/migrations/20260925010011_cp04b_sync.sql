-- CP-04B bagian 2: sinkronisasi jadwal pembayaran, alasan moderasi wajib,
-- dan penulisan skor aspek oleh pengulas (RLS).
-- Immutable: hanya menambah/mengganti fungsi & kebijakan baru.

-- ===== 1. Trigger: setelah pembayaran berubah → jadwal & pengingat sinkron =====
-- next_due_date selalu = due paling awal yang belum lunas (AC-PAY-02/06);
-- pengingat untuk record yang dibayar / tanggalnya diubah dibatalkan — app
-- membuat ulang saat layar dibuka (ADR-006 resync on open), tanpa duplikat
-- (unique index reminders_scheduled_uq tetap berlaku).
create or replace function public.payment_records_sync_schedule()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if new.status is distinct from old.status
     or new.due_date is distinct from old.due_date then
    update public.payment_schedules s
       set next_due_date = coalesce(
             (select min(pr.due_date)
                from public.payment_records pr
               where pr.tenancy_id = new.tenancy_id
                 and pr.status = 'unpaid'),
             s.next_due_date)
     where s.tenancy_id = new.tenancy_id;

    if new.status = 'paid'
       or new.due_date is distinct from old.due_date then
      update public.reminders
         set status = 'cancelled'
       where payment_record_id = new.id
         and status = 'scheduled';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists payment_records_sync_schedule on public.payment_records;
create trigger payment_records_sync_schedule
  after update on public.payment_records
  for each row execute function public.payment_records_sync_schedule();

-- ===== 2. reviews_guard supersede: reject wajib alasan (FR-REV-03) =====
create or replace function public.reviews_guard()
returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending'
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'reviews_guard:status_awal_pending';
    end if;
  else
    if new.tenancy_id is distinct from old.tenancy_id
       or new.property_id is distinct from old.property_id
       or new.user_id is distinct from old.user_id
       or new.review_type is distinct from old.review_type
       or new.rating_overall is distinct from old.rating_overall
       or new.review_text is distinct from old.review_text
       or new.created_at is distinct from old.created_at then
      raise exception 'reviews_guard:konten_immutable';
    end if;
    if (new.status is distinct from old.status
        or new.moderated_by is distinct from old.moderated_by
        or new.moderation_reason is distinct from old.moderation_reason)
       and auth.uid() is not null and not public.app_is_admin() then
      raise exception 'reviews_guard:moderasi_admin_saja';
    end if;
    -- reject = keputusan publik → alasan wajib; 'hidden' cukup flag internal
    if new.status = 'rejected'
       and new.status is distinct from old.status
       and nullif(btrim(coalesce(new.moderation_reason, '')), '') is null then
      raise exception 'reviews_guard:reject_butuh_alasan';
    end if;
  end if;
  return new;
end;
$$;

-- ===== 3. RLS: pengulas menulis skor aspek miliknya sendiri =====
-- Sebelumnya hanya admin yang boleh menulis → submit review selalu gagal di
-- sisi aspek. Kebijakan baru: INSERT oleh pemilik review (tenancy sudah
-- divalidasi lewat policy reviews_insert + fk tenancy/property), source
-- 'manual', tanpa model_version_id. Tidak ada UPDATE/DELETE oleh author —
-- skor aspek immutable sama seperti konten review (konten = data audit).
create policy review_aspect_scores_author on public.review_aspect_scores
  for insert to authenticated
  with check (
    exists (
      select 1 from public.reviews r
       where r.id = review_id
         and r.user_id = auth.uid()
    )
    and source = 'manual'
    and model_version_id is null
    and confidence is null
  );
