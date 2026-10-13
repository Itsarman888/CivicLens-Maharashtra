-- CivicLens Maharashtra v2: run this in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Resident',
  created_at timestamptz not null default now()
);
create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('moderator','admin')),
  created_at timestamptz not null default now()
);
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 5 and 120),
  description text not null check (char_length(description) between 10 and 1800),
  category text not null check (category in ('Road damage','Garbage','Streetlight','Water & drainage','Public safety','Other')),
  city text not null,
  division text not null,
  address text not null default '',
  latitude double precision not null check (latitude between 5 and 23),
  longitude double precision not null check (longitude between 70 and 81),
  priority text not null default 'Normal' check (priority in ('Low','Normal','Urgent')),
  status text not null default 'Reported' check (status in ('Reported','Under Review','In Progress','Resolved')),
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.report_votes (
  report_id uuid not null references public.reports(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (report_id, user_id)
);
create table if not exists public.report_comments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create or replace function public.is_moderator()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('moderator','admin')); $$;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'admin'); $$;
revoke all on function public.is_moderator() from public;
revoke all on function public.is_admin() from public;
grant execute on function public.is_moderator() to authenticated;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.reports enable row level security;
alter table public.report_votes enable row level security;
alter table public.report_comments enable row level security;

create policy "Profiles visible to signed-in users" on public.profiles for select to authenticated using (true);
create policy "Users create own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "Users update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "Roles visible to self or admins" on public.user_roles for select to authenticated using (auth.uid() = user_id or public.is_admin());
create policy "Reports visible to everyone" on public.reports for select to anon, authenticated using (true);
create policy "Signed-in users create reports as themselves" on public.reports for insert to authenticated with check (auth.uid() = user_id);
create policy "Authors edit own reports or moderators update status" on public.reports for update to authenticated using (auth.uid() = user_id or public.is_moderator()) with check (auth.uid() = user_id or public.is_moderator());
create policy "Authors or moderators delete reports" on public.reports for delete to authenticated using (auth.uid() = user_id or public.is_moderator());
create policy "Votes readable" on public.report_votes for select to anon, authenticated using (true);
create policy "Users vote as themselves" on public.report_votes for insert to authenticated with check (auth.uid() = user_id);
create policy "Users remove own vote" on public.report_votes for delete to authenticated using (auth.uid() = user_id);
create policy "Comments readable" on public.report_comments for select to anon, authenticated using (true);
create policy "Signed-in users add own comments" on public.report_comments for insert to authenticated with check (auth.uid() = user_id);
create policy "Authors delete own comments or moderators delete" on public.report_comments for delete to authenticated using (auth.uid() = user_id or public.is_moderator());

-- Public read access to photos; only authenticated users may upload to their own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('civiclens-photos','civiclens-photos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp'];
create policy "CivicLens photos are publicly viewable" on storage.objects for select using (bucket_id = 'civiclens-photos');
create policy "Users upload photos into own folder" on storage.objects for insert to authenticated with check (bucket_id = 'civiclens-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users delete own photos" on storage.objects for delete to authenticated using (bucket_id = 'civiclens-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- After a user signs up, promote a trusted account to moderator/admin manually:
-- insert into public.user_roles (user_id, role) values ('AUTH_USER_UUID_HERE', 'admin');
-- Do this only in the Supabase SQL editor, never in browser code.

-- Keep updated_at current whenever a report changes.
create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at before update on public.reports for each row execute function public.set_updated_at();
