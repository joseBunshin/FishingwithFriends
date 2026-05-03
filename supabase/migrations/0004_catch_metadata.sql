-- ============================================================================
-- 0004 — catch_and_release + rig columns + view recreate
--
-- The M0/U4 catch-log form captured Catch & Release + Rig/Lure but the
-- schema had no home for them. M1 needs them as real columns so they
-- round-trip cleanly through the persistence layer and stay queryable
-- (search, filters, future stats).
--
-- Recreates `catches_friend_view` so friend reads pick up the new columns.
-- ============================================================================

begin;

alter table public.catches
  add column if not exists catch_and_release boolean not null default false,
  add column if not exists rig text;

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
  c.secret_spot,
  c.catch_and_release,
  c.rig,
  c.notes,
  c.photo_paths,
  c.conditions,
  c.created_at,
  c.updated_at
from public.catches c;

commit;
