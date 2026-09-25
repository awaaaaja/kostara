-- CP-04B: skor aspek 1–5 (FR-REV-02 "8 rating aspek 1–5 wajib").
-- Tabel sebelumnya hanya menyimpan sentiment (arah NLP) — nilai rating
-- manual tidak ke mana-mana. Kolom `score` menampung nilai form; sentiment
-- tetap di-derive untuk pipeline NLP masa depan.

alter table public.review_aspect_scores
  add column if not exists score smallint
  check (score between 1 and 5);

-- Supersede kebijakan penulis (0011): skor manual wajib 1–5 dan sentiment
-- konsisten dengan skor — hanya pemilik review yang menulis.
drop policy if exists review_aspect_scores_author on public.review_aspect_scores;
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
    and score between 1 and 5
    and sentiment = case
      when score >= 4 then 'positive'
      when score <= 2 then 'negative'
      else 'neutral'
    end
  );
