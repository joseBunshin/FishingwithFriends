-- ============================================================================
-- 0010 — conditions auto-fill trigger
--
-- M6 introduces async server-side population of `catches.conditions`:
-- when a catch is inserted with empty conditions, an AFTER INSERT trigger
-- calls a Supabase edge function via `pg_net` (fire-and-forget HTTP). The
-- edge function fetches weather (Open-Meteo) and, for saltwater species,
-- tide (NOAA Tides & Currents), then writes the result back via
-- service-role UPDATE. Failures leave conditions = '{}' — the catch save
-- is never blocked or error-stated by an external API outage.
--
-- Required Supabase project settings (Project Settings → Configuration):
--   app.settings.conditions_fn_url    Edge function HTTPS URL
--   app.settings.service_role_key     Used by the edge fn for writes
--
-- Both can be set via SQL:
--   alter database postgres
--     set "app.settings.conditions_fn_url" = 'https://<ref>.supabase.co/functions/v1/conditions-fill';
--   alter database postgres
--     set "app.settings.service_role_key" = '<service-role-key>';
-- ============================================================================

begin;

create extension if not exists pg_net;

-- ----------------------------------------------------------------------------
-- Helper: read a database setting safely (null when unset)
-- ----------------------------------------------------------------------------
create or replace function public.fwf_setting(p_name text)
returns text
language sql
stable
as $$
  select nullif(current_setting(p_name, true), '');
$$;

-- ----------------------------------------------------------------------------
-- Trigger function — fires for inserts where conditions is empty.
--
-- Note: pg_net.http_post is fire-and-forget; it returns immediately with
-- a request id and runs the HTTP call asynchronously in a background
-- worker. Catch-insert latency is unaffected.
-- ----------------------------------------------------------------------------
create or replace function public.tg_dispatch_conditions_fill()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text := public.fwf_setting('app.settings.conditions_fn_url');
  v_payload jsonb;
begin
  if v_url is null then
    -- Edge function URL not configured — silently skip. Lets dev
    -- environments work without provisioning the function.
    return new;
  end if;
  if new.location is null then
    -- No GPS; nothing the edge function can fetch.
    return new;
  end if;
  if new.conditions <> '{}'::jsonb then
    -- Already populated (e.g., manual SQL backfill). Skip.
    return new;
  end if;

  v_payload := jsonb_build_object(
    'catch_id', new.id,
    'lat',      st_y(new.location::geometry),
    'lng',      st_x(new.location::geometry),
    'caught_at', new.caught_at,
    'species_id', new.species_id
  );

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' ||
        coalesce(public.fwf_setting('app.settings.service_role_key'), '')
    ),
    body    := v_payload,
    timeout_milliseconds := 10000
  );

  return new;
end;
$$;

drop trigger if exists tg_conditions_fill_after_insert on public.catches;
create trigger tg_conditions_fill_after_insert
  after insert on public.catches
  for each row
  execute function public.tg_dispatch_conditions_fill();

-- ----------------------------------------------------------------------------
-- Service-role write path — the edge function calls this RPC to update
-- conditions without bumping `updated_at` (which would re-trigger the
-- storytelling AFTER UPDATE evaluator from 0009 unnecessarily).
-- ----------------------------------------------------------------------------
create or replace function public.fwf_set_catch_conditions(
  p_catch_id uuid,
  p_conditions jsonb
) returns void
language sql
security definer
set search_path = public
as $$
  update public.catches
    set conditions = p_conditions
    where id = p_catch_id;
$$;

-- ----------------------------------------------------------------------------
-- Refresh PostgREST schema cache.
-- ----------------------------------------------------------------------------

notify pgrst, 'reload schema';

commit;
