-- Myseum — Supabase schema (Phase D1: auth + profiles)
-- Run this in the Supabase dashboard → SQL Editor on your NEW project.

-- ── Profiles ────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
    id          uuid primary key references auth.users (id) on delete cascade,
    username    text not null,
    email       text,
    avatar_url  text,
    created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Any signed-in user can read profiles (needed later for friend lookups).
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select"
    on public.profiles for select
    to authenticated
    using (true);

-- Users can insert / update only their own row.
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
    on public.profiles for insert
    to authenticated
    with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
    on public.profiles for update
    to authenticated
    using (auth.uid() = id);

-- ── Auto-create a profile row when a user signs up ───────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, username, email)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
        new.email
    );
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ── Setup note ───────────────────────────────────────────────────────────────
-- For easy testing, disable email confirmation:
--   Dashboard → Authentication → Providers → Email → turn OFF "Confirm email".
-- (Phase D2 will add: avatar storage bucket, friendships, and shared events.)
