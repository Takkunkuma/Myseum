-- Myseum — Phase D3 webhook: call the notify-invite Edge Function whenever an
-- event_shares row is inserted. Run in the SQL Editor AFTER deploying the function.
--
-- Uses pg_net directly (no dependency on the supabase_functions schema, which
-- only exists once you've used the dashboard Webhooks UI).

create extension if not exists pg_net;

create or replace function public.notify_invite_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, net, extensions
as $$
begin
    perform net.http_post(
        url     := 'https://zhqzpzjgdfoszkkkuurs.supabase.co/functions/v1/notify-invite',
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body    := jsonb_build_object('record', to_jsonb(new))
    );
    return new;
end;
$$;

drop trigger if exists on_event_share_created on public.event_shares;

create trigger on_event_share_created
    after insert on public.event_shares
    for each row
    execute function public.notify_invite_trigger();
