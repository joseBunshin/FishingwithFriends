-- ============================================================================
-- 0016 — plain latitude/longitude columns on catches
--
-- Supabase returns the `geography` column as EWKB hex
-- ("0101000020E6100000...") which the Flutter DTO doesn't parse — so
-- the catch detail screen renders "Location not captured" even when
-- the row has a valid GPS point. The DTO understood WKT and GeoJSON
-- shapes but not EWKB.
--
-- Rather than teach the DTO a third format, expose lat/lng as plain
-- numeric columns alongside `location`. PostgREST returns numerics as
-- JSON numbers, no parsing needed.
--
-- The `location` PostGIS column stays — it's still the authoritative
-- spatial type for indexes, distance queries, and the conditions trigger.
-- The new columns mirror it via a BEFORE INSERT/UPDATE trigger.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- Columns
-- ----------------------------------------------------------------------------
alter table public.catches
  add column if not exists latitude  numeric(9, 6),
  add column if not exists longitude numeric(9, 6);

-- ----------------------------------------------------------------------------
-- Trigger — keep latitude/longitude in sync with `location`.
-- Runs BEFORE so the inserted row already has the values.
-- ----------------------------------------------------------------------------
create or replace function public.tg_catches_sync_latlng()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  if new.location is null then
    new.latitude := null;
    new.longitude := null;
  else
    new.latitude  := st_y(new.location::geometry);
    new.longitude := st_x(new.location::geometry);
  end if;
  return new;
end;
$$;

drop trigger if exists catches_sync_latlng on public.catches;
create trigger catches_sync_latlng
  before insert or update of location on public.catches
  for each row execute function public.tg_catches_sync_latlng();

-- ----------------------------------------------------------------------------
-- Backfill — populate the new columns for every existing row.
-- ----------------------------------------------------------------------------
update public.catches
  set latitude  = st_y(location::geometry),
      longitude = st_x(location::geometry)
  where location is not null
    and (latitude is null or longitude is null);

-- ----------------------------------------------------------------------------
-- Recreate the friend-visible view with the new columns.
-- ----------------------------------------------------------------------------
drop view if exists public.catches_friend_view;
create or replace view public.catches_friend_view as
select
  c.id,
  c.angler_id,
  c.species_id,
  c.species_label,
  c.length_cm,
  c.weight_kg,
  c.caught_at,
  case when c.secret_spot then null else c.location end as location,
  case when c.secret_spot then null else c.latitude  end as latitude,
  case when c.secret_spot then null else c.longitude end as longitude,
  c.secret_spot,
  c.catch_and_release,
  c.rig,
  c.trip_id,
  c.notes,
  c.photo_paths,
  c.conditions,
  c.created_at,
  c.updated_at
from public.catches c;

notify pgrst, 'reload schema';

commit;
