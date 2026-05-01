-- ============================================================================
-- Fishing with Friends — initial schema
-- Bunshin Studios © 2026
--
-- Implements personas + features from spec v1.0:
--   - Anglers, Tournament Creators, Admins
--   - Catch logging with optional Secret Spot (hide GPS from friends)
--   - Friend graph (mutual follow / friendship request)
--   - Tournaments with invite-only Pending/Accepted membership
--   - Friend-only RLS visibility everywhere
--   - Private storage bucket "catches" served via signed URLs only
-- ============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "postgis";

-- ----------------------------------------------------------------------------
-- profiles
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (char_length(username) between 3 and 30),
  display_name text,
  avatar_path text,
  bio text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_username_idx on public.profiles (lower(username));

-- ----------------------------------------------------------------------------
-- friendships (single row per ordered pair, status pending|accepted|blocked)
-- ----------------------------------------------------------------------------
create type public.friendship_status as enum ('pending', 'accepted', 'blocked');

create table if not exists public.friendships (
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status public.friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create index if not exists friendships_addressee_idx
  on public.friendships (addressee_id, status);

-- Helper: are A and B mutual accepted friends?
create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

-- ----------------------------------------------------------------------------
-- species (admin-managed global list)
-- ----------------------------------------------------------------------------
create table if not exists public.species (
  id uuid primary key default gen_random_uuid(),
  common_name text not null unique,
  scientific_name text,
  category text,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- catches
-- ----------------------------------------------------------------------------
create table if not exists public.catches (
  id uuid primary key default gen_random_uuid(),
  angler_id uuid not null references public.profiles(id) on delete cascade,
  species_id uuid references public.species(id),
  species_label text,
  length_in numeric(6, 2),
  weight_lb numeric(6, 2),
  caught_at timestamptz not null default now(),
  location geography(point, 4326),
  secret_spot boolean not null default false,
  notes text,
  photo_paths text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length_in is null or length_in >= 0),
  check (weight_lb is null or weight_lb >= 0)
);

create index if not exists catches_angler_idx on public.catches (angler_id, caught_at desc);
create index if not exists catches_species_idx on public.catches (species_id);
create index if not exists catches_location_idx on public.catches using gist (location);

-- Friend-visible view that respects Secret Spot.
create or replace view public.catches_friend_view as
select
  c.id, c.angler_id, c.species_id, c.species_label,
  c.length_in, c.weight_lb, c.caught_at,
  case when c.secret_spot then null else c.location end as location,
  c.secret_spot, c.notes, c.photo_paths,
  c.created_at, c.updated_at
from public.catches c;

-- ----------------------------------------------------------------------------
-- tournaments
-- ----------------------------------------------------------------------------
create type public.tournament_metric as enum ('weight', 'length');
create type public.tournament_member_status as enum ('pending', 'accepted', 'rejected');

create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  metric public.tournament_metric not null default 'weight',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists tournaments_creator_idx on public.tournaments (creator_id);
create index if not exists tournaments_window_idx on public.tournaments (starts_at, ends_at);

create table if not exists public.tournament_members (
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  angler_id uuid not null references public.profiles(id) on delete cascade,
  status public.tournament_member_status not null default 'pending',
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (tournament_id, angler_id)
);

create index if not exists tournament_members_angler_idx
  on public.tournament_members (angler_id, status);

create table if not exists public.tournament_entries (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  catch_id uuid not null references public.catches(id) on delete cascade,
  angler_id uuid not null references public.profiles(id) on delete cascade,
  submitted_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references public.profiles(id),
  unique (tournament_id, catch_id)
);

create index if not exists tournament_entries_lookup
  on public.tournament_entries (tournament_id, angler_id);

-- ----------------------------------------------------------------------------
-- notifications
-- ----------------------------------------------------------------------------
create type public.notification_kind as enum (
  'friend_request', 'friend_accepted',
  'tournament_invite', 'tournament_member_approved', 'tournament_member_rejected',
  'tournament_entry_approved', 'tournament_entry_rejected',
  'system'
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  kind public.notification_kind not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

-- ============================================================================
-- updated_at triggers
-- ============================================================================
create or replace function public.tg_set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare t text;
begin
  for t in select unnest(array['profiles','friendships','catches','tournaments','tournament_members'])
  loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format('create trigger set_updated_at before update on public.%I
                    for each row execute function public.tg_set_updated_at()', t);
  end loop;
end$$;

-- ============================================================================
-- Row Level Security
-- ============================================================================
alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.species enable row level security;
alter table public.catches enable row level security;
alter table public.tournaments enable row level security;
alter table public.tournament_members enable row level security;
alter table public.tournament_entries enable row level security;
alter table public.notifications enable row level security;

-- profiles: anyone signed in can read; you can only update your own row.
create policy profiles_select_all on public.profiles
  for select to authenticated using (true);
create policy profiles_insert_self on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- friendships: visible to either party; only requester inserts; addressee
-- can move pending -> accepted/rejected; either can delete.
create policy friendships_select_party on public.friendships
  for select to authenticated using (
    requester_id = auth.uid() or addressee_id = auth.uid()
  );
create policy friendships_insert_requester on public.friendships
  for insert to authenticated with check (
    requester_id = auth.uid() and addressee_id <> auth.uid()
  );
create policy friendships_update_addressee on public.friendships
  for update to authenticated
  using (addressee_id = auth.uid())
  with check (addressee_id = auth.uid());
create policy friendships_delete_party on public.friendships
  for delete to authenticated using (
    requester_id = auth.uid() or addressee_id = auth.uid()
  );

-- species: read for anyone signed in; write for admins only.
create policy species_select_all on public.species
  for select to authenticated using (true);
create policy species_admin_write on public.species
  for all to authenticated
  using (exists (select 1 from public.profiles p
                 where p.id = auth.uid() and p.is_admin))
  with check (exists (select 1 from public.profiles p
                      where p.id = auth.uid() and p.is_admin));

-- catches: angler always sees own; friends see each other's; insert/update/delete own only.
create policy catches_select_self_or_friends on public.catches
  for select to authenticated using (
    angler_id = auth.uid() or public.are_friends(auth.uid(), angler_id)
  );
create policy catches_write_self on public.catches
  for insert to authenticated with check (angler_id = auth.uid());
create policy catches_update_self on public.catches
  for update to authenticated
  using (angler_id = auth.uid()) with check (angler_id = auth.uid());
create policy catches_delete_self on public.catches
  for delete to authenticated using (angler_id = auth.uid());

-- tournaments: visible if public, you're the creator, or you're an accepted member.
create policy tournaments_select on public.tournaments
  for select to authenticated using (
    is_public
    or creator_id = auth.uid()
    or exists (
      select 1 from public.tournament_members m
      where m.tournament_id = tournaments.id
        and m.angler_id = auth.uid()
        and m.status = 'accepted'
    )
  );
create policy tournaments_insert on public.tournaments
  for insert to authenticated with check (creator_id = auth.uid());
create policy tournaments_update_creator on public.tournaments
  for update to authenticated
  using (creator_id = auth.uid()) with check (creator_id = auth.uid());
create policy tournaments_delete_creator on public.tournaments
  for delete to authenticated using (creator_id = auth.uid());

-- tournament_members: angler sees own membership; creator sees all members of their tournaments.
create policy tournament_members_select on public.tournament_members
  for select to authenticated using (
    angler_id = auth.uid()
    or exists (
      select 1 from public.tournaments t
      where t.id = tournament_members.tournament_id and t.creator_id = auth.uid()
    )
  );
-- Anglers may request to join (status=pending) on their own behalf only.
create policy tournament_members_insert_self_pending on public.tournament_members
  for insert to authenticated with check (
    angler_id = auth.uid() and status = 'pending'
  );
-- Only creator can move pending -> accepted/rejected. Self-approval is blocked.
create policy tournament_members_update_creator on public.tournament_members
  for update to authenticated
  using (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_members.tournament_id
        and t.creator_id = auth.uid()
        and t.creator_id <> tournament_members.angler_id
    )
  )
  with check (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_members.tournament_id
        and t.creator_id = auth.uid()
        and t.creator_id <> tournament_members.angler_id
    )
  );
create policy tournament_members_delete_self_or_creator on public.tournament_members
  for delete to authenticated using (
    angler_id = auth.uid()
    or exists (
      select 1 from public.tournaments t
      where t.id = tournament_members.tournament_id and t.creator_id = auth.uid()
    )
  );

-- tournament_entries: angler must be accepted member; only their own catches.
-- Only creator approves; angler cannot approve their own entry.
create policy tournament_entries_select on public.tournament_entries
  for select to authenticated using (
    angler_id = auth.uid()
    or exists (
      select 1 from public.tournaments t
      where t.id = tournament_entries.tournament_id and t.creator_id = auth.uid()
    )
    or exists (
      select 1 from public.tournament_members m
      where m.tournament_id = tournament_entries.tournament_id
        and m.angler_id = auth.uid()
        and m.status = 'accepted'
    )
  );
create policy tournament_entries_insert on public.tournament_entries
  for insert to authenticated with check (
    angler_id = auth.uid()
    and exists (
      select 1 from public.catches c
      where c.id = tournament_entries.catch_id and c.angler_id = auth.uid()
    )
    and exists (
      select 1 from public.tournament_members m
      where m.tournament_id = tournament_entries.tournament_id
        and m.angler_id = auth.uid()
        and m.status = 'accepted'
    )
  );
create policy tournament_entries_update_creator on public.tournament_entries
  for update to authenticated
  using (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_entries.tournament_id
        and t.creator_id = auth.uid()
        and t.creator_id <> tournament_entries.angler_id
    )
  )
  with check (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_entries.tournament_id
        and t.creator_id = auth.uid()
        and t.creator_id <> tournament_entries.angler_id
    )
  );

-- notifications: each user sees their own.
create policy notifications_select_own on public.notifications
  for select to authenticated using (recipient_id = auth.uid());
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

-- ============================================================================
-- Storage: private "catches" bucket
-- ============================================================================
-- Insert as a separate migration after running this — most teams manage
-- buckets via the dashboard. Recommended config:
--   - id: 'catches', public: false
--   - object path convention: '<angler_id>/<uuid>.jpg'
-- Then add storage policies:
--   - select/insert/update/delete restricted to (auth.uid())::text = (storage.foldername(name))[1]
--   - friend reads happen via short-lived signed URLs minted server-side or via
--     a postgres function that checks public.are_friends(auth.uid(), owner)
-- See docs/SUPABASE_SETUP.md for the full storage policy block.
