create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  cin text not null,
  avatar_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint profiles_cin_format check (cin ~ '^[0-9]{8}$')
);

-- Run this once if the column doesn't exist yet (idempotent migration):
-- alter table public.profiles add column if not exists avatar_url text;

create table if not exists public.tasks (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  subject text not null,
  due_at timestamptz not null,
  completed boolean not null default false,
  priority text not null default 'medium',
  reminder_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tasks_priority_check check (priority in ('low', 'medium', 'high'))
);

create table if not exists public.schedule_sessions (
  id text primary key,
  day_index integer not null check (day_index between 0 and 5),
  title text not null,
  room text not null,
  teacher text not null,
  color_hex text not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  start_time text not null check (start_time ~ '^([01]\d|2[0-3]):[0-5]\d$'),
  end_time text not null check (end_time ~ '^([01]\d|2[0-3]):[0-5]\d$'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.ai_agent_sessions (
  conversation_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  summary text not null default '',
  last_messages_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (conversation_id, user_id)
);

create index if not exists idx_tasks_user_due_at
on public.tasks (user_id, due_at);

create index if not exists idx_tasks_user_open_due_at
on public.tasks (user_id, due_at)
where completed = false;

create index if not exists idx_schedule_sessions_day_time
on public.schedule_sessions (day_index, start_time);

create index if not exists idx_ai_agent_sessions_user_updated
on public.ai_agent_sessions (user_id, updated_at desc);

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists set_tasks_updated_at on public.tasks;
create trigger set_tasks_updated_at
before update on public.tasks
for each row
execute function public.set_updated_at();

drop trigger if exists set_schedule_sessions_updated_at on public.schedule_sessions;
create trigger set_schedule_sessions_updated_at
before update on public.schedule_sessions
for each row
execute function public.set_updated_at();

drop trigger if exists set_ai_agent_sessions_updated_at on public.ai_agent_sessions;
create trigger set_ai_agent_sessions_updated_at
before update on public.ai_agent_sessions
for each row
execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, cin)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email, ''), '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'cin', '00000000')
  )
  on conflict (id) do update
  set email = excluded.email,
      full_name = excluded.full_name,
      cin = excluded.cin,
      updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.schedule_sessions enable row level security;
alter table public.ai_agent_sessions enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own"
on public.tasks
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own"
on public.tasks
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own"
on public.tasks
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own"
on public.tasks
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "schedule_sessions_read_all" on public.schedule_sessions;
create policy "schedule_sessions_read_all"
on public.schedule_sessions
for select
to authenticated, anon
using (true);

drop policy if exists "ai_agent_sessions_select_own" on public.ai_agent_sessions;
create policy "ai_agent_sessions_select_own"
on public.ai_agent_sessions
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "ai_agent_sessions_insert_own" on public.ai_agent_sessions;
create policy "ai_agent_sessions_insert_own"
on public.ai_agent_sessions
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "ai_agent_sessions_update_own" on public.ai_agent_sessions;
create policy "ai_agent_sessions_update_own"
on public.ai_agent_sessions
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "ai_agent_sessions_delete_own" on public.ai_agent_sessions;
create policy "ai_agent_sessions_delete_own"
on public.ai_agent_sessions
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- ─── Storage: avatars bucket ────────────────────────────────────────────────
-- Create the bucket (run once via Supabase dashboard or CLI; SQL below is
-- informational — storage.buckets is not writable via plain SQL migrations).
--
-- Dashboard path: Storage → New bucket → name "avatars", Public ON
--
-- Equivalent CLI: supabase storage buckets create avatars --public
--
-- RLS policies for the avatars bucket:
drop policy if exists "avatars_select_public" on storage.objects;
create policy "avatars_select_public"
on storage.objects for select
to public
using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
