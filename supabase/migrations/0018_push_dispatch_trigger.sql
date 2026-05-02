-- ============================================================================
-- 0018 — push dispatch trigger on notifications
--
-- Adds an AFTER INSERT trigger on `notifications` that calls a Supabase
-- edge function via pg_net. The edge function (push-dispatch) authenticates
-- to FCM HTTP v1 using the service-account JSON stored in Supabase secrets,
-- looks up the recipient's device tokens + preferences, and sends pushes.
--
-- Configuration (insert into fwf_app_settings, just like 0010 conditions):
--   app.settings.push_dispatch_fn_url   — https://<ref>.supabase.co/functions/v1/push-dispatch
--   app.settings.service_role_key       — already configured for conditions
-- ============================================================================

begin;

create or replace function public.tg_dispatch_push_notification()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text := public.fwf_setting('app.settings.push_dispatch_fn_url');
begin
  if v_url is null then
    -- URL not configured (dev environment without push wired) — silently skip.
    return new;
  end if;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' ||
        coalesce(public.fwf_setting('app.settings.service_role_key'), '')
    ),
    body    := jsonb_build_object(
      'notification_id', new.id,
      'recipient_id',    new.recipient_id,
      'kind',            new.kind,
      'payload',         new.payload,
      'created_at',      new.created_at
    ),
    timeout_milliseconds := 10000
  );

  return new;
end;
$$;

drop trigger if exists tg_push_dispatch_after_insert on public.notifications;
create trigger tg_push_dispatch_after_insert
  after insert on public.notifications
  for each row
  execute function public.tg_dispatch_push_notification();

notify pgrst, 'reload schema';

commit;
