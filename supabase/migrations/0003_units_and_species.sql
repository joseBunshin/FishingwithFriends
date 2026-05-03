-- ============================================================================
-- 0003 — canonical metric measurements + species water type + seed
--
-- Migrates `catches` to canonical metric persistence (per-input UI conversion
-- still happens in the client), enriches `species` with water_type + regions,
-- and seeds a v1-launch list covering both freshwater and saltwater.
-- Adds `catches.conditions` JSONB now so the M6 weather/tide cache has a
-- forward-compatible home without a future migration.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- catches: canonical metric + conditions cache + recreated friend view
-- ----------------------------------------------------------------------------

drop view if exists public.catches_friend_view;

alter table public.catches
  rename column weight_lb to weight_kg;
alter table public.catches
  rename column length_in to length_cm;

-- Old check constraints reference the renamed columns by name and follow the
-- rename automatically — verified by inspecting pg_constraint after the
-- rename. No re-creation needed.

alter table public.catches
  add column if not exists conditions jsonb not null default '{}'::jsonb;

create or replace view public.catches_friend_view as
select
  c.id, c.angler_id, c.species_id, c.species_label,
  c.length_cm, c.weight_kg, c.caught_at,
  case when c.secret_spot then null else c.location end as location,
  c.secret_spot, c.notes, c.photo_paths, c.conditions,
  c.created_at, c.updated_at
from public.catches c;

-- ----------------------------------------------------------------------------
-- species: water type + regions + indexes
-- ----------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_type where typname = 'species_water_type') then
    create type public.species_water_type as enum ('freshwater', 'saltwater', 'both');
  end if;
end$$;

alter table public.species
  add column if not exists water_type public.species_water_type
    not null default 'freshwater',
  add column if not exists regions text[] not null default '{}'::text[];

create index if not exists species_water_type_idx
  on public.species (water_type);

drop index if exists species_common_name_idx;
create index if not exists species_common_name_idx
  on public.species (lower(common_name));

-- ----------------------------------------------------------------------------
-- seed — only insert if the table is empty so re-running the migration
-- against a populated species table is a no-op
-- ----------------------------------------------------------------------------

insert into public.species (common_name, scientific_name, category, water_type, regions)
select * from (values
  -- Freshwater
  ('Largemouth Bass',     'Micropterus nigricans',     'bass',    'freshwater'::public.species_water_type, array['us-all']),
  ('Smallmouth Bass',     'Micropterus dolomieu',      'bass',    'freshwater', array['us-all']),
  ('Spotted Bass',        'Micropterus punctulatus',   'bass',    'freshwater', array['us-southeast']),
  ('Rainbow Trout',       'Oncorhynchus mykiss',       'trout',   'freshwater', array['us-all']),
  ('Brown Trout',         'Salmo trutta',              'trout',   'freshwater', array['us-all']),
  ('Brook Trout',         'Salvelinus fontinalis',     'trout',   'freshwater', array['us-northeast', 'us-rockies']),
  ('Lake Trout',          'Salvelinus namaycush',      'trout',   'freshwater', array['us-great-lakes']),
  ('Walleye',             'Sander vitreus',            'walleye', 'freshwater', array['us-midwest', 'us-great-lakes']),
  ('Northern Pike',       'Esox lucius',               'pike',    'freshwater', array['us-north', 'us-great-lakes']),
  ('Muskellunge',         'Esox masquinongy',          'pike',    'freshwater', array['us-great-lakes', 'us-midwest']),
  ('Bluegill',            'Lepomis macrochirus',       'panfish', 'freshwater', array['us-all']),
  ('Black Crappie',       'Pomoxis nigromaculatus',    'panfish', 'freshwater', array['us-all']),
  ('White Crappie',       'Pomoxis annularis',         'panfish', 'freshwater', array['us-all']),
  ('Yellow Perch',        'Perca flavescens',          'panfish', 'freshwater', array['us-all']),
  ('Channel Catfish',     'Ictalurus punctatus',       'catfish', 'freshwater', array['us-all']),
  ('Flathead Catfish',    'Pylodictis olivaris',       'catfish', 'freshwater', array['us-southeast']),
  ('Common Carp',         'Cyprinus carpio',           'carp',    'freshwater', array['us-all']),

  -- Saltwater + euryhaline
  ('Striped Bass',        'Morone saxatilis',          'bass',    'both',       array['us-east-coast']),
  ('Snook',               'Centropomus undecimalis',   'inshore', 'saltwater',  array['us-southeast', 'gulf']),
  ('Red Drum',            'Sciaenops ocellatus',       'inshore', 'saltwater',  array['us-east-coast', 'gulf']),
  ('Spotted Sea Trout',   'Cynoscion nebulosus',       'inshore', 'saltwater',  array['us-east-coast', 'gulf']),
  ('Tarpon',              'Megalops atlanticus',       'inshore', 'saltwater',  array['us-southeast', 'gulf']),
  ('Permit',              'Trachinotus falcatus',      'inshore', 'saltwater',  array['us-southeast']),
  ('Bonefish',            'Albula vulpes',             'inshore', 'saltwater',  array['us-southeast']),
  ('Mangrove Snapper',    'Lutjanus griseus',          'snapper', 'saltwater',  array['us-southeast', 'gulf']),
  ('Red Snapper',         'Lutjanus campechanus',      'snapper', 'saltwater',  array['gulf']),
  ('Gag Grouper',         'Mycteroperca microlepis',   'grouper', 'saltwater',  array['us-southeast', 'gulf']),
  ('Mahi-Mahi',           'Coryphaena hippurus',       'pelagic', 'saltwater',  array['us-southeast', 'gulf']),
  ('Cobia',               'Rachycentron canadum',      'pelagic', 'saltwater',  array['us-east-coast', 'gulf']),
  ('Spanish Mackerel',    'Scomberomorus maculatus',   'pelagic', 'saltwater',  array['us-east-coast', 'gulf']),
  ('Bluefish',            'Pomatomus saltatrix',       'pelagic', 'saltwater',  array['us-east-coast']),
  ('Summer Flounder',     'Paralichthys dentatus',     'flatfish','saltwater',  array['us-east-coast'])
) as v(common_name, scientific_name, category, water_type, regions)
where not exists (select 1 from public.species);

commit;
