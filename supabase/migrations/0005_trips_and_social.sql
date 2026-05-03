-- ============================================================================
-- 0005 — trips, trip_participants, feed_reactions, comments + notification triggers
--
-- Introduces:
--   - `trips`: optional parent of catches. One active per angler at a time.
--   - `trip_participants`: tagged companions on a trip (invited / accepted / declined).
--   - `feed_reactions`: 5-emoji reactions, one per (catch, user).
--   - `comments`: flat, soft-deletable, ≤2000 chars.
--   - `catches.trip_id`: nullable FK to trips, set null on trip delete.
--   - 4 row triggers that write into the existing `notifications` table.
--   - Recreate `catches_friend_view` to expose `trip_id`.
--
-- RLS follows the M0/M1 friends-only model:
--   - Owner has full control of their rows.
--   - Mutual friends can read.
--   - Non-friends see nothing.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- catches.trip_id + recreate catches_friend_view
-- ----------------------------------------------------------------------------

alter table public.catches
  add column if not exists trip_id uuid;

create index if not exists catches_trip_idx
  on public.catches (trip_id) where trip_id is not null;

-- ----------------------------------------------------------------------------
-- trips
-- ----------------------------------------------------------------------------

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  angler_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  body_of_water text,
  cover_photo_path text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ended_at is null or ended_at >= started_at)
);

create index if not exists trips_angler_idx
  on public.trips (angler_id, started_at desc);

-- Single-active-trip-per-angler invariant.
create unique index if not exists trips_one_active_per_angler
  on public.trips (angler_id) where is_active;

-- Now that trips exists, retro-FK catches.trip_id.
alter table public.catches
  drop constraint if exists catches_trip_id_fkey;
alter table public.catches
  add constraint catches_trip_id_fkey foreign key (trip_id)
    references public.trips(id) on delete set null;

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
  c.trip_id,
  c.notes,
  c.photo_paths,
  c.conditions,
  c.created_at,
  c.updated_at
from public.catches c;

-- ----------------------------------------------------------------------------
-- trip_participants
-- ----------------------------------------------------------------------------

create type public.trip_participant_status as enum ('invited', 'accepted', 'declined');

create table if not exists public.trip_participants (
  trip_id uuid not null references public.trips(id) on delete cascade,
  angler_id uuid not null references public.profiles(id) on delete cascade,
  status public.trip_participant_status not null default 'invited',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (trip_id, angler_id)
);

-- ----------------------------------------------------------------------------
-- feed_reactions — single (catch, user) row per reaction
-- ----------------------------------------------------------------------------

create table if not exists public.feed_reactions (
  catch_id uuid not null references public.catches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('rod', 'fire', 'fist', 'mind', 'handshake')),
  created_at timestamptz not null default now(),
  primary key (catch_id, user_id)
);

create index if not exists feed_reactions_catch_idx
  on public.feed_reactions (catch_id, kind);

-- ----------------------------------------------------------------------------
-- comments — flat, soft-deletable
-- ----------------------------------------------------------------------------

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  catch_id uuid not null references public.catches(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists comments_catch_idx
  on public.comments (catch_id, created_at);

-- ----------------------------------------------------------------------------
-- updated_at triggers (reuse the helper from 0001_init.sql)
-- ----------------------------------------------------------------------------

do $$
declare t text;
begin
  for t in select unnest(array['trips','trip_participants','comments'])
  loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format('create trigger set_updated_at before update on public.%I
                    for each row execute function public.tg_set_updated_at()', t);
  end loop;
end$$;

-- ============================================================================
-- Row Level Security
-- ============================================================================

alter table public.trips enable row level security;
alter table public.trip_participants enable row level security;
alter table public.feed_reactions enable row level security;
alter table public.comments enable row level security;

-- trips: owner OR mutual friend can read; only owner writes.
create policy trips_select_owner_or_friends on public.trips
  for select to authenticated using (
    angler_id = auth.uid() or public.are_friends(auth.uid(), angler_id)
  );
create policy trips_insert_self on public.trips
  for insert to authenticated with check (angler_id = auth.uid());
create policy trips_update_self on public.trips
  for update to authenticated
  using (angler_id = auth.uid()) with check (angler_id = auth.uid());
create policy trips_delete_self on public.trips
  for delete to authenticated using (angler_id = auth.uid());

-- trip_participants: trip owner sees all participants;
-- the participant sees their own row. Insert by owner; update (accept/decline)
-- by participant only.
create policy trip_participants_select on public.trip_participants
  for select to authenticated using (
    angler_id = auth.uid()
    or exists (
      select 1 from public.trips t
      where t.id = trip_participants.trip_id and t.angler_id = auth.uid()
    )
  );
create policy trip_participants_insert_owner on public.trip_participants
  for insert to authenticated with check (
    exists (
      select 1 from public.trips t
      where t.id = trip_participants.trip_id and t.angler_id = auth.uid()
    )
  );
create policy trip_participants_update_self on public.trip_participants
  for update to authenticated
  using (angler_id = auth.uid()) with check (angler_id = auth.uid());
create policy trip_participants_delete_owner_or_self on public.trip_participants
  for delete to authenticated using (
    angler_id = auth.uid()
    or exists (
      select 1 from public.trips t
      where t.id = trip_participants.trip_id and t.angler_id = auth.uid()
    )
  );

-- feed_reactions: visible to reactor, catch owner, and catch owner's friends.
-- The reactor inserts and deletes; updates (re-react with different kind) go
-- through delete + insert at the repository level.
create policy reactions_select on public.feed_reactions
  for select to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.catches c
      where c.id = feed_reactions.catch_id
        and (c.angler_id = auth.uid()
             or public.are_friends(auth.uid(), c.angler_id))
    )
  );
create policy reactions_insert_self on public.feed_reactions
  for insert to authenticated with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.catches c
      where c.id = feed_reactions.catch_id
        and (c.angler_id = auth.uid()
             or public.are_friends(auth.uid(), c.angler_id))
    )
  );
create policy reactions_delete_self on public.feed_reactions
  for delete to authenticated using (user_id = auth.uid());

-- comments: same friend-only visibility. Authors insert. Authors can update
-- only `deleted_at` (soft-delete) — no body edits in v1.
create policy comments_select on public.comments
  for select to authenticated using (
    author_id = auth.uid()
    or exists (
      select 1 from public.catches c
      where c.id = comments.catch_id
        and (c.angler_id = auth.uid()
             or public.are_friends(auth.uid(), c.angler_id))
    )
  );
create policy comments_insert_self on public.comments
  for insert to authenticated with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.catches c
      where c.id = comments.catch_id
        and (c.angler_id = auth.uid()
             or public.are_friends(auth.uid(), c.angler_id))
    )
  );
create policy comments_soft_delete_author on public.comments
  for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

-- ============================================================================
-- Notification triggers
-- ============================================================================

create or replace function public.tg_notify_friend_request() returns trigger
language plpgsql security definer as $$
begin
  if new.status = 'pending' then
    insert into public.notifications (recipient_id, kind, payload)
    values (
      new.addressee_id,
      'friend_request'::public.notification_kind,
      jsonb_build_object('requester_id', new.requester_id)
    );
  end if;
  return new;
end;
$$;

create or replace function public.tg_notify_friend_accepted() returns trigger
language plpgsql security definer as $$
begin
  if old.status = 'pending' and new.status = 'accepted' then
    insert into public.notifications (recipient_id, kind, payload)
    values (
      new.requester_id,
      'friend_accepted'::public.notification_kind,
      jsonb_build_object('addressee_id', new.addressee_id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_friend_request on public.friendships;
create trigger notify_friend_request
  after insert on public.friendships
  for each row execute function public.tg_notify_friend_request();

drop trigger if exists notify_friend_accepted on public.friendships;
create trigger notify_friend_accepted
  after update on public.friendships
  for each row execute function public.tg_notify_friend_accepted();

-- Reaction notification: fires once per insert; skips self-reactions.
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_enum e on t.oid = e.enumtypid
    where t.typname = 'notification_kind' and e.enumlabel = 'reaction'
  ) then
    alter type public.notification_kind add value 'reaction';
  end if;
  if not exists (
    select 1 from pg_type t
    join pg_enum e on t.oid = e.enumtypid
    where t.typname = 'notification_kind' and e.enumlabel = 'comment'
  ) then
    alter type public.notification_kind add value 'comment';
  end if;
end$$;

create or replace function public.tg_notify_reaction() returns trigger
language plpgsql security definer as $$
declare owner uuid;
begin
  select angler_id into owner from public.catches where id = new.catch_id;
  if owner is null or owner = new.user_id then
    return new;
  end if;
  insert into public.notifications (recipient_id, kind, payload)
  values (
    owner,
    'reaction'::public.notification_kind,
    jsonb_build_object(
      'catch_id', new.catch_id,
      'reactor_id', new.user_id,
      'kind', new.kind
    )
  );
  return new;
end;
$$;

drop trigger if exists notify_reaction on public.feed_reactions;
create trigger notify_reaction
  after insert on public.feed_reactions
  for each row execute function public.tg_notify_reaction();

create or replace function public.tg_notify_comment() returns trigger
language plpgsql security definer as $$
declare owner uuid;
begin
  select angler_id into owner from public.catches where id = new.catch_id;
  if owner is null or owner = new.author_id then
    return new;
  end if;
  insert into public.notifications (recipient_id, kind, payload)
  values (
    owner,
    'comment'::public.notification_kind,
    jsonb_build_object(
      'catch_id', new.catch_id,
      'comment_id', new.id,
      'author_id', new.author_id
    )
  );
  return new;
end;
$$;

drop trigger if exists notify_comment on public.comments;
create trigger notify_comment
  after insert on public.comments
  for each row execute function public.tg_notify_comment();

commit;
