-- Myseum — Supabase schema (Phase D2b: shared events)
-- Run this in the dashboard → SQL Editor (after schema.sql and schema_d2.sql).

-- When you invite friends to an event, one row per invitee is created here.
-- The invitee accepts (event is mirrored into their calendar) or declines.
create table if not exists public.event_shares (
    id          uuid primary key default gen_random_uuid(),
    owner       uuid not null references auth.users (id) on delete cascade,
    invitee     uuid not null references auth.users (id) on delete cascade,
    title       text not null,
    starts_at   timestamptz not null,
    ends_at     timestamptz not null,
    is_all_day  boolean not null default false,
    status      text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
    created_at  timestamptz not null default now()
);

alter table public.event_shares enable row level security;

drop policy if exists "event_shares_select_involved" on public.event_shares;
create policy "event_shares_select_involved"
    on public.event_shares for select
    to authenticated
    using (auth.uid() = owner or auth.uid() = invitee);

drop policy if exists "event_shares_insert_owner" on public.event_shares;
create policy "event_shares_insert_owner"
    on public.event_shares for insert
    to authenticated
    with check (auth.uid() = owner);

-- Invitee accepts/declines (updates status).
drop policy if exists "event_shares_update_invitee" on public.event_shares;
create policy "event_shares_update_invitee"
    on public.event_shares for update
    to authenticated
    using (auth.uid() = invitee);

drop policy if exists "event_shares_delete_owner" on public.event_shares;
create policy "event_shares_delete_owner"
    on public.event_shares for delete
    to authenticated
    using (auth.uid() = owner);
