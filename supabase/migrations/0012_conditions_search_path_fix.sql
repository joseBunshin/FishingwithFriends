-- ============================================================================
-- 0012 — fix conditions trigger search_path so PostGIS types resolve
--
-- The trigger function in 0010 references `new.location::geometry` and
-- `st_x(...) / st_y(...)` to extract lat/lng. PostGIS in Supabase lives
-- in the `extensions` schema, but the function declared
-- `set search_path = public`, so the cast fails with:
--   42704: type "geometry" does not exist
--
-- Fix: include `extensions` in the function's search_path. Same change
-- applies to fwf_setting() (purely defensive — it doesn't touch PostGIS
-- but harmless).
-- ============================================================================

begin;

create or replace function public.tg_dispatch_conditions_fill()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text := public.fwf_setting('app.settings.conditions_fn_url');
  v_payload jsonb;
begin
  if v_url is null then
    return new;
  end if;
  if new.location is null then
    return new;
  end if;
  if new.conditions <> '{}'::jsonb then
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

notify pgrst, 'reload schema';

commit;
