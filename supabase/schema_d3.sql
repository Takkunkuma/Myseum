-- Myseum — Supabase schema (Phase D3: push device tokens)
-- Run this in the dashboard → SQL Editor (after the earlier schema files).

create table if not exists public.device_tokens (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    token       text not null,
    platform    text not null default 'ios',
    updated_at  timestamptz not null default now(),
    unique (user_id, token)
);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_own" on public.device_tokens;
create policy "device_tokens_own"
    on public.device_tokens for all
    to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- The notify-invite Edge Function reads this table with the service-role key
-- (which bypasses RLS), so no extra read policy is needed for it.
