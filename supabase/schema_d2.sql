-- Myseum — Supabase schema (Phase D2a: avatars + friends)
-- Run this in the dashboard → SQL Editor (after schema.sql).

-- ── Avatars storage bucket ───────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
    on storage.objects for select
    to public
    using (bucket_id = 'avatars');

-- Files live under "<user_id>/...". Users can write only their own folder.
drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
    on storage.objects for insert
    to authenticated
    with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
    on storage.objects for update
    to authenticated
    using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ── Friendships ──────────────────────────────────────────────────────────────
-- Opening someone's invite link/QR makes you friends immediately (status
-- 'accepted'). A single row is visible to both sides via the select policy.
create table if not exists public.friendships (
    id          uuid primary key default gen_random_uuid(),
    requester   uuid not null references auth.users (id) on delete cascade,
    addressee   uuid not null references auth.users (id) on delete cascade,
    status      text not null default 'accepted' check (status in ('pending', 'accepted')),
    created_at  timestamptz not null default now(),
    unique (requester, addressee),
    check (requester <> addressee)
);

alter table public.friendships enable row level security;

drop policy if exists "friendships_select_involved" on public.friendships;
create policy "friendships_select_involved"
    on public.friendships for select
    to authenticated
    using (auth.uid() = requester or auth.uid() = addressee);

drop policy if exists "friendships_insert_requester" on public.friendships;
create policy "friendships_insert_requester"
    on public.friendships for insert
    to authenticated
    with check (auth.uid() = requester);

drop policy if exists "friendships_update_addressee" on public.friendships;
create policy "friendships_update_addressee"
    on public.friendships for update
    to authenticated
    using (auth.uid() = addressee);

drop policy if exists "friendships_delete_involved" on public.friendships;
create policy "friendships_delete_involved"
    on public.friendships for delete
    to authenticated
    using (auth.uid() = requester or auth.uid() = addressee);
