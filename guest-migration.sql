-- CivicLens guest-first migration. Run ONCE in Supabase SQL Editor after backing up.
-- It preserves existing reports, comments, and votes. It does not drop tables or data.
begin;

alter table public.reports alter column user_id drop not null;
alter table public.reports add column if not exists guest_id text;
alter table public.report_comments alter column user_id drop not null;
alter table public.report_comments add column if not exists guest_id text;
alter table public.report_votes add column if not exists guest_id text;

-- Replace the old (report_id,user_id) primary key so guest votes can be stored safely.
-- Drop the old primary key BEFORE dropping NOT NULL from user_id; PostgreSQL does not
-- allow a primary-key column to become nullable while it is still part of the key.
do $$ declare pk_name text; begin
  select c.conname into pk_name
  from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace
  where n.nspname='public' and t.relname='report_votes' and c.contype='p';
  if pk_name is not null then execute format('alter table public.report_votes drop constraint %I',pk_name); end if;
end $$;
alter table public.report_votes alter column user_id drop not null;
alter table public.report_votes add column if not exists id uuid default gen_random_uuid();
update public.report_votes set id=gen_random_uuid() where id is null;
alter table public.report_votes alter column id set not null;
do $$ begin
  if not exists (select 1 from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and t.relname='report_votes' and c.contype='p') then
    alter table public.report_votes add constraint report_votes_pkey primary key (id);
  end if;
end $$;
create unique index if not exists report_votes_signed_in_unique on public.report_votes(report_id,user_id) where user_id is not null;
create unique index if not exists report_votes_guest_unique on public.report_votes(report_id,guest_id) where guest_id is not null;
create index if not exists reports_guest_id_idx on public.reports(guest_id);
create index if not exists comments_guest_id_idx on public.report_comments(guest_id);

-- Remove conflicting old insert/delete policies by name, then create guest-safe policies.
drop policy if exists "Signed-in users create reports as themselves" on public.reports;
drop policy if exists "Guests and signed-in users can create reports" on public.reports;
create policy "Guests and signed-in users can create reports" on public.reports for insert to anon, authenticated
  with check ((user_id is null and guest_id is not null and char_length(guest_id) between 20 and 80) or (auth.uid() is not null and user_id=auth.uid()));

drop policy if exists "Users vote as themselves" on public.report_votes;
drop policy if exists "Guests and users can support reports" on public.report_votes;
create policy "Guests and users can support reports" on public.report_votes for insert to anon, authenticated
  with check ((user_id is null and guest_id is not null and char_length(guest_id) between 20 and 80) or (auth.uid() is not null and user_id=auth.uid()));
drop policy if exists "Users remove own vote" on public.report_votes;
drop policy if exists "Guests remove their own browser vote" on public.report_votes;
create policy "Signed-in users remove own vote" on public.report_votes for delete to authenticated
  using (auth.uid() is not null and user_id=auth.uid());
-- Guest supports are intentionally append-only: an anonymous browser ID is not verified identity.

drop policy if exists "Signed-in users add own comments" on public.report_comments;
drop policy if exists "Guests and users can add comments" on public.report_comments;
create policy "Guests and users can add comments" on public.report_comments for insert to anon, authenticated
  with check ((user_id is null and guest_id is not null and char_length(guest_id) between 20 and 80 and char_length(body) between 1 and 500) or (auth.uid() is not null and user_id=auth.uid() and char_length(body) between 1 and 500));

-- Public photo uploads are restricted to the existing CivicLens bucket and guest/ folder.
drop policy if exists "Guests upload photos to CivicLens bucket" on storage.objects;
create policy "Guests upload photos to CivicLens bucket" on storage.objects for insert to anon, authenticated
  with check (bucket_id='civiclens-photos' and (storage.foldername(name))[1]='guest' and lower(storage.extension(name)) in ('jpg','jpeg','png','webp'));

commit;
