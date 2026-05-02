-- ============================================================================
-- Fishing with Friends — development seed
--
-- Populates 3 mock friend accounts + ~25 catches + 1 trip + 1 active
-- tournament + reactions/comments so you can exercise the full app
-- end-to-end (friend feed, tournament leaderboard, stats, PRs, badges,
-- share cards, notifications).
--
-- ----------------------------------------------------------------------------
-- HOW TO USE
-- ----------------------------------------------------------------------------
-- 1. In Supabase Dashboard → Authentication → Users → "Add user", create
--    these three accounts (any password — you don't need to log in as them
--    via the app for dev testing):
--      alice@fwf.test
--      bob@fwf.test
--      charlie@fwf.test
--    Tip: turn off "Send email confirmation" on the Add user dialog so the
--    accounts are usable immediately.
--
-- 2. Edit `JOSE_EMAIL` below if your real account email is not
--    'jose.diaz@bunshin.io'.
--
-- 3. Paste this whole file into Supabase Dashboard → SQL Editor → Run.
--
-- ----------------------------------------------------------------------------
-- IDEMPOTENCY
-- ----------------------------------------------------------------------------
-- Re-running wipes prior seed data scoped to the four test users
-- (catches/trips/tournaments/friendships/reactions/comments) before
-- re-inserting. Your real account's profile row is preserved — only its
-- catches/trips/tournaments are wiped, since those are the ones the seed
-- owns. So if you want to keep catches you logged manually in the app,
-- skip running the seed again.
-- ============================================================================

begin;

-- Block PostgREST from picking up half-applied schema while seed runs.
set local lock_timeout = '5s';

-- ----------------------------------------------------------------------------
-- 1. Resolve test user IDs by email and validate everyone exists.
-- ----------------------------------------------------------------------------
create temporary table _seed_users (alias text primary key, id uuid not null, email text not null) on commit drop;

insert into _seed_users (alias, id, email)
select v.alias, u.id, u.email
from (values
  ('jose',    'jose.diaz@bunshin.io'),
  ('alice',   'alice@fwf.test'),
  ('bob',     'bob@fwf.test'),
  ('charlie', 'charlie@fwf.test')
) as v(alias, email)
join auth.users u on u.email = v.email;

do $$
declare missing text;
begin
  select string_agg(want.email, ', ') into missing
    from (values
      ('jose.diaz@bunshin.io'),
      ('alice@fwf.test'),
      ('bob@fwf.test'),
      ('charlie@fwf.test')
    ) as want(email)
    left join _seed_users s on s.email = want.email
    where s.id is null;

  if missing is not null then
    raise exception 'Seed pre-flight failed — missing auth.users for: %. Create them via Dashboard → Authentication → Users → Add user, then re-run.', missing;
  end if;
end $$;

-- Convenience: alias → id lookups, used everywhere below.
-- (select id from _seed_users where alias = 'jose')

-- ----------------------------------------------------------------------------
-- 2. Wipe prior seed data, scoped to the four test users.
-- ----------------------------------------------------------------------------
-- Order matters: child tables first to avoid FK violations.
delete from public.tournament_chat_messages
  where tournament_id in (
    select t.id from public.tournaments t
    where t.creator_id in (select id from _seed_users)
  );

delete from public.tournament_side_pots
  where tournament_id in (
    select t.id from public.tournaments t
    where t.creator_id in (select id from _seed_users)
  );

delete from public.tournament_entries
  where angler_id in (select id from _seed_users);

delete from public.tournament_members
  where angler_id in (select id from _seed_users);

delete from public.tournaments
  where creator_id in (select id from _seed_users);

delete from public.feed_reactions
  where user_id in (select id from _seed_users);

delete from public.comments
  where author_id in (select id from _seed_users);

delete from public.user_badges
  where angler_id in (select id from _seed_users);

delete from public.personal_records
  where angler_id in (select id from _seed_users);

delete from public.catches
  where angler_id in (select id from _seed_users);

delete from public.trip_participants
  where trip_id in (
    select t.id from public.trips t
    where t.angler_id in (select id from _seed_users)
  );

delete from public.trips
  where angler_id in (select id from _seed_users);

delete from public.friendships
  where requester_id in (select id from _seed_users)
     or addressee_id in (select id from _seed_users);

delete from public.notifications
  where recipient_id in (select id from _seed_users);

-- ----------------------------------------------------------------------------
-- 3. Profile updates — fill display_name, bio, home_water, onboarding flag.
-- The auto-profile-on-signup trigger (0008) already created the rows.
-- We update; the trigger-derived username stays unless we override it.
-- ----------------------------------------------------------------------------
update public.profiles set
  display_name = 'Alice Rivers',
  username = 'alice_rivers',
  bio = 'Bass tournament regular. PB 8.4 lb largemouth on a chatterbait, will not shut up about it.',
  home_water = 'Lake Norman, NC',
  onboarding_completed_at = now() - interval '14 days'
where id = (select id from _seed_users where alias = 'alice');

update public.profiles set
  display_name = 'Bob Mariner',
  username = 'bob_mariner',
  bio = 'Inshore guide out of St. Pete. Snook, reds, trout. Catch & release everything over 30".',
  home_water = 'Tampa Bay, FL',
  onboarding_completed_at = now() - interval '21 days'
where id = (select id from _seed_users where alias = 'bob');

update public.profiles set
  display_name = 'Charlie Crick',
  username = 'charlie_crick',
  bio = 'Trout creek-stomper. If it has cold water and a hatch I am there.',
  home_water = 'Soque River, GA',
  onboarding_completed_at = now() - interval '9 days'
where id = (select id from _seed_users where alias = 'charlie');

-- Make sure jose has onboarding completed too — harmless if already set.
update public.profiles set
  onboarding_completed_at = coalesce(onboarding_completed_at, now() - interval '30 days'),
  home_water = coalesce(home_water, 'Lake Norman, NC')
where id = (select id from _seed_users where alias = 'jose');

-- ----------------------------------------------------------------------------
-- 4. Friendships — Jose is friends with all 3; small sub-graph among mocks.
-- One row per ordered pair; are_friends() checks both directions.
-- ----------------------------------------------------------------------------
insert into public.friendships (requester_id, addressee_id, status, created_at, updated_at)
values
  ((select id from _seed_users where alias = 'jose'),
   (select id from _seed_users where alias = 'alice'),
   'accepted', now() - interval '20 days', now() - interval '20 days'),
  ((select id from _seed_users where alias = 'jose'),
   (select id from _seed_users where alias = 'bob'),
   'accepted', now() - interval '18 days', now() - interval '18 days'),
  ((select id from _seed_users where alias = 'charlie'),
   (select id from _seed_users where alias = 'jose'),
   'accepted', now() - interval '8 days',  now() - interval '8 days'),
  ((select id from _seed_users where alias = 'alice'),
   (select id from _seed_users where alias = 'bob'),
   'accepted', now() - interval '12 days', now() - interval '12 days'),
  ((select id from _seed_users where alias = 'bob'),
   (select id from _seed_users where alias = 'charlie'),
   'accepted', now() - interval '6 days',  now() - interval '6 days');

-- ----------------------------------------------------------------------------
-- 5. Catches — 25 total spread across all 4 anglers, varied dates/species.
-- weight_kg / length_cm are canonical metric (the UI converts on display).
-- 1 lb ≈ 0.4536 kg, 1 in ≈ 2.54 cm.
-- ----------------------------------------------------------------------------

-- Convenience CTE-style helper — species ID lookups.
-- We splat them into a temp table for cleaner inserts below.
create temporary table _seed_species (label text primary key, id uuid) on commit drop;
insert into _seed_species (label, id)
select s.common_name, s.id from public.species s where s.common_name in (
  'Largemouth Bass', 'Smallmouth Bass', 'Spotted Bass',
  'Rainbow Trout', 'Brown Trout', 'Brook Trout',
  'Walleye', 'Northern Pike',
  'Bluegill', 'Yellow Perch', 'Channel Catfish',
  'Striped Bass', 'Snook', 'Red Drum', 'Spotted Sea Trout', 'Tarpon',
  'Mahi-Mahi', 'Bluefish'
);

-- Insert catches via a single VALUES list keyed by alias + species label.
-- We resolve angler_id and species_id from the temp tables on the fly.
with catch_rows (
  alias, species_label, length_cm, weight_kg, days_ago, hours_ago,
  lat, lng, secret_spot, c_and_r, rig, notes, conditions
) as (values
  -- Jose — 8 catches, mix of FW + a coastal trip, recent dates, some PR-worthy
  ('jose',    'Largemouth Bass',     53.34, 3.86,  1, 14,  35.5500, -80.9000, false, true,  'Chatterbait',         'Big girl off the rocks at sunrise. PB pending.', '{"weather":{"temp_c":18,"sky":"clear"},"water_temp_c":15,"wind_kph":8}'::jsonb),
  ('jose',    'Largemouth Bass',     43.18, 1.81,  3,  9,  35.5510, -80.9020, false, true,  'Senko',               'Texas-rigged on the dock pilings.',                  '{"weather":{"temp_c":20,"sky":"partly_cloudy"}}'::jsonb),
  ('jose',    'Smallmouth Bass',     38.10, 1.24,  6, 11,  35.5530, -80.9100, false, true,  'Tube jig',            'Rocky point. Hit on the second hop.',                '{"weather":{"temp_c":17,"sky":"overcast"},"wind_kph":15}'::jsonb),
  ('jose',    'Bluegill',            22.86, 0.27, 10, 16,  35.5520, -80.8990, false, false, '1/64oz jig + waxworm','Kid fish on the bobber rig.',                        '{}'::jsonb),
  ('jose',    'Channel Catfish',     61.00, 4.31, 14, 21,  35.5515, -80.9050, false, false, 'Cut bait',            'Night session on the pier. Cooler turtle.',          '{"weather":{"temp_c":22,"sky":"clear"},"moon":"waxing_gibbous"}'::jsonb),
  ('jose',    'Red Drum',            66.04, 3.18, 28, 10,  27.7000, -82.5000, false, true,  'Topwater walker',     'Boca Ciega flat. Tide just starting to push.',       '{"weather":{"temp_c":26,"sky":"clear"},"tide":{"phase":"flooding"}}'::jsonb),
  ('jose',    'Spotted Sea Trout',   48.26, 1.13, 28, 12,  27.7050, -82.5050, false, true,  'Soft plastic paddle', 'Same flat, different drift.',                        '{"tide":{"phase":"flooding"}}'::jsonb),
  ('jose',    'Bluefish',            58.42, 1.95, 28, 14,  27.7100, -82.5100, false, false, 'Spoon',               'Schoolie blitz on bait pods. Glorious.',             '{}'::jsonb),

  -- Alice — 6 freshwater bass-focused catches, Lake Norman area
  ('alice',   'Largemouth Bass',     56.00, 4.12,  2, 13,  35.5400, -80.9200, false, true,  'Jig + craw trailer',  'Boat dock graveyard. Took the 1/2oz brown.',         '{"weather":{"temp_c":16,"sky":"overcast"}}'::jsonb),
  ('alice',   'Largemouth Bass',     45.00, 2.27,  5, 10,  35.5380, -80.9220, false, true,  'Squarebill crank',    'Crashing the rip rap.',                              '{}'::jsonb),
  ('alice',   'Largemouth Bass',     50.80, 3.22,  9, 16,  35.5410, -80.9180, true,  true,  'Drop shot',           'Dont ask where.',                                    '{}'::jsonb),
  ('alice',   'Spotted Bass',        38.00, 1.36, 12, 11,  35.5420, -80.9210, false, true,  'Ned rig',             'River channel ledge. Felt the tap, set, fish.',      '{}'::jsonb),
  ('alice',   'Smallmouth Bass',     40.64, 1.59, 18, 14,  35.5390, -80.9230, false, true,  'Tube jig',            'Bonus brown bass on the points.',                    '{"wind_kph":20}'::jsonb),
  ('alice',   'Largemouth Bass',     48.26, 2.49, 24, 12,  35.5405, -80.9195, false, true,  'Frog',                'Mat fishing in the slop. Heart-stopper of a blow up.', '{"weather":{"sky":"clear","temp_c":24}}'::jsonb),

  -- Bob — 6 saltwater inshore Florida catches, varied species
  ('bob',     'Snook',               74.93, 3.40,  1, 15,  27.6900, -82.6500, false, true,  'Live pilchard',       'Dock light slob. Took 4 minutes to land.',           '{"tide":{"phase":"ebbing"}}'::jsonb),
  ('bob',     'Red Drum',            71.12, 3.45,  4, 11,  27.7100, -82.6300, false, true,  'Gold spoon',          'Tail in the grass on the low tide.',                 '{"tide":{"phase":"low"}}'::jsonb),
  ('bob',     'Spotted Sea Trout',   55.88, 1.63,  4, 12,  27.7110, -82.6310, false, true,  'Soft plastic shrimp', 'Same trip — gator trout off the same flat.',         '{"tide":{"phase":"low"}}'::jsonb),
  ('bob',     'Tarpon',              137.16, 38.55,  9, 14, 27.6800, -82.7100, true,  true, 'Live crab',           'Pass migration. 100lb+ fish, 45-min fight.',         '{"tide":{"phase":"flooding"}}'::jsonb),
  ('bob',     'Snook',               66.04, 2.04, 16, 18,  27.6950, -82.6400, false, true,  'Plug',                'Beach snook on a clear morning.',                    '{}'::jsonb),
  ('bob',     'Mahi-Mahi',           81.28, 5.44, 30, 13,  27.5000, -83.2000, false, false, 'Trolled ballyhoo',    'Offshore weed line. Bull stayed on for the cousin.', '{"weather":{"temp_c":29,"sky":"clear"}}'::jsonb),
  ('bob',     'Largemouth Bass',     47.00, 2.95,  2,  9,  35.5450, -80.9100, false, true,  'Chatterbait',         'Charity bass on the trip up to NC for the tournament.', '{}'::jsonb),

  -- Charlie — 5 freshwater trout catches, Soque River area
  ('charlie', 'Rainbow Trout',       40.64, 0.91,  2, 10,  34.6000, -83.7100, false, true,  'Olive woolly bugger', 'Pocket water below the bridge.',                     '{"water_temp_c":11}'::jsonb),
  ('charlie', 'Brown Trout',         55.88, 2.04,  5,  9,  34.6020, -83.7080, true,  true,  'Streamer',            'Predawn streamer eat. Real one.',                    '{"water_temp_c":10}'::jsonb),
  ('charlie', 'Brook Trout',         28.00, 0.30,  7, 11,  34.6500, -83.6500, false, true,  'Dry — parachute adams','Headwater brookie. Tiny and perfect.',              '{}'::jsonb),
  ('charlie', 'Rainbow Trout',       33.02, 0.50, 11, 13,  34.6010, -83.7090, false, true,  'Egg pattern',         'Behind the hatchery. Lazy but it counts.',           '{}'::jsonb),
  ('charlie', 'Rainbow Trout',       50.80, 1.50, 19,  8,  34.6005, -83.7110, false, true,  'Nymph rig',           'Indicator drift in the long run. Solid bow.',        '{"water_temp_c":12}'::jsonb)
)
insert into public.catches (
  angler_id, species_id, species_label, length_cm, weight_kg,
  caught_at, location, secret_spot, catch_and_release, rig, notes, conditions
)
select
  (select id from _seed_users where alias = c.alias),
  (select id from _seed_species where label = c.species_label),
  c.species_label,
  c.length_cm,
  c.weight_kg,
  now() - (c.days_ago || ' days')::interval - (c.hours_ago || ' hours')::interval,
  st_setsrid(st_makepoint(c.lng, c.lat), 4326)::geography,
  c.secret_spot,
  c.c_and_r,
  c.rig,
  c.notes,
  c.conditions
from catch_rows c;

-- Storytelling trigger (0009) auto-populated personal_records and user_badges
-- from the inserts above. The latlng sync trigger (0016) auto-populated
-- catches.latitude/longitude from the geography column. Nothing else to do.

-- ----------------------------------------------------------------------------
-- 6. Trip — one finished trip co-led by Jose with Alice tagged in.
-- ----------------------------------------------------------------------------
with t as (
  insert into public.trips (
    angler_id, title, body_of_water, started_at, ended_at, is_active
  ) values (
    (select id from _seed_users where alias = 'jose'),
    'Norman Spring Pre-spawn',
    'Lake Norman, NC',
    now() - interval '6 days' - interval '8 hours',
    now() - interval '6 days',
    false
  ) returning id
)
insert into public.trip_participants (trip_id, angler_id, status)
select t.id, (select id from _seed_users where alias = 'alice'), 'accepted' from t
union all
select t.id, (select id from _seed_users where alias = 'bob'),   'invited'  from t;

-- ----------------------------------------------------------------------------
-- 7. Tournament — "Spring Bass Brawl", live now (started 7d ago, ends 7d out).
-- ----------------------------------------------------------------------------
-- Trigger 0014 will auto-enroll Jose (creator) as accepted.
-- Trigger 0015 will auto-approve Jose's own entry submissions.

with tourn as (
  insert into public.tournaments (
    creator_id, name, description, metric, starts_at, ends_at, is_public, is_closed
  ) values (
    (select id from _seed_users where alias = 'jose'),
    'Spring Bass Brawl',
    'Two-week largemouth + smallmouth shootout. Top 3 by single-fish weight take the pot. Side board for biggest smallie.',
    'weight',
    now() - interval '7 days',
    now() + interval '7 days',
    false,
    false
  ) returning id
)
-- Members: Jose is auto-added by trigger; insert the other 3 directly as accepted.
-- (Manual insert bypasses the "self-only pending" RLS because we're running as service role here.)
insert into public.tournament_members (tournament_id, angler_id, status, approved_by, created_at, updated_at)
select t.id, (select id from _seed_users where alias = 'alice'),
       'accepted', (select id from _seed_users where alias = 'jose'),
       now() - interval '6 days', now() - interval '6 days' from tourn t
union all
select t.id, (select id from _seed_users where alias = 'bob'),
       'accepted', (select id from _seed_users where alias = 'jose'),
       now() - interval '6 days', now() - interval '6 days' from tourn t
union all
select t.id, (select id from _seed_users where alias = 'charlie'),
       'accepted', (select id from _seed_users where alias = 'jose'),
       now() - interval '5 days', now() - interval '5 days' from tourn t;

-- Side pot: biggest smallmouth bonus.
insert into public.tournament_side_pots (tournament_id, name, metric, species_filter)
select t.id, 'Biggest Smallie', 'weight', 'Smallmouth Bass'
from public.tournaments t
where t.creator_id = (select id from _seed_users where alias = 'jose')
  and t.name = 'Spring Bass Brawl';

-- Entries: pull each angler's biggest bass-class catch and submit it.
-- Status mix: a couple approved, one pending (so the creator UI has something to action).
with t as (
  select id from public.tournaments
  where creator_id = (select id from _seed_users where alias = 'jose')
    and name = 'Spring Bass Brawl'
),
candidate_catches as (
  select
    c.id        as catch_id,
    c.angler_id,
    c.species_label,
    c.weight_kg,
    c.length_cm,
    c.caught_at,
    row_number() over (partition by c.angler_id order by c.weight_kg desc nulls last) as rn
  from public.catches c
  where c.angler_id in (select id from _seed_users)
    and c.species_label in ('Largemouth Bass', 'Smallmouth Bass', 'Spotted Bass')
)
insert into public.tournament_entries (
  tournament_id, catch_id, angler_id,
  species_label, weight_kg, length_cm, caught_at,
  submitted_at, status, approved_at, approved_by
)
select
  t.id,
  cc.catch_id,
  cc.angler_id,
  cc.species_label,
  cc.weight_kg,
  cc.length_cm,
  cc.caught_at,
  cc.caught_at + interval '30 minutes' as submitted_at,
  case
    -- Jose's entries auto-approve via trigger 0015 anyway
    when cc.angler_id = (select id from _seed_users where alias = 'jose') then 'approved'
    when cc.angler_id = (select id from _seed_users where alias = 'alice') then 'approved'
    when cc.angler_id = (select id from _seed_users where alias = 'bob') then 'approved'
    else 'pending'
  end as status,
  case
    when cc.angler_id = (select id from _seed_users where alias = 'charlie') then null
    else cc.caught_at + interval '45 minutes'
  end as approved_at,
  case
    when cc.angler_id = (select id from _seed_users where alias = 'charlie') then null
    else (select id from _seed_users where alias = 'jose')
  end as approved_by
from t, candidate_catches cc
where cc.rn <= 2  -- top two bass per angler
  and cc.angler_id in (
    select id from _seed_users where alias in ('alice', 'bob', 'jose')
  )
union all
-- Charlie has no bass, so add his biggest trout as a pending entry just to
-- demonstrate the creator-approval flow. Tournament metric is 'weight' so it
-- still counts toward the leaderboard if approved.
select
  t.id,
  cc.catch_id,
  cc.angler_id,
  cc.species_label,
  cc.weight_kg,
  cc.length_cm,
  cc.caught_at,
  cc.caught_at + interval '20 minutes',
  'pending',
  null,
  null
from t, (
  select c.id as catch_id, c.angler_id, c.species_label, c.weight_kg, c.length_cm, c.caught_at,
         row_number() over (order by c.weight_kg desc) as rn
  from public.catches c
  where c.angler_id = (select id from _seed_users where alias = 'charlie')
) cc
where cc.rn = 1;

-- Tournament chat — 4 messages so the live chat tab has content.
insert into public.tournament_chat_messages (tournament_id, author_id, body, created_at)
select t.id, (select id from _seed_users where alias = 'jose'),
       'GLs everyone. Weather looks fishy this weekend, last day push is gonna be tight.',
       now() - interval '5 days'
from public.tournaments t
where t.creator_id = (select id from _seed_users where alias = 'jose')
  and t.name = 'Spring Bass Brawl'
union all
select t.id, (select id from _seed_users where alias = 'alice'),
       'Already had one bite off the dock at lunch. Game on.',
       now() - interval '4 days' - interval '6 hours'
from public.tournaments t
where t.creator_id = (select id from _seed_users where alias = 'jose')
  and t.name = 'Spring Bass Brawl'
union all
select t.id, (select id from _seed_users where alias = 'bob'),
       'Driving up Friday from FL. Can someone front me a chatterbait, brought zero freshwater stuff.',
       now() - interval '3 days' - interval '2 hours'
from public.tournaments t
where t.creator_id = (select id from _seed_users where alias = 'jose')
  and t.name = 'Spring Bass Brawl'
union all
select t.id, (select id from _seed_users where alias = 'charlie'),
       'Submitting a trout entry. Yes I know. Read the metric.',
       now() - interval '1 day' - interval '4 hours'
from public.tournaments t
where t.creator_id = (select id from _seed_users where alias = 'jose')
  and t.name = 'Spring Bass Brawl';

-- ----------------------------------------------------------------------------
-- 8. Reactions + comments — populate the friend feed for Jose's recent catches.
-- ----------------------------------------------------------------------------
-- Reactions: 5 total across 3 of Jose's most recent catches.
insert into public.feed_reactions (catch_id, user_id, kind, created_at)
select c.id, u.id, v.kind, now() - (v.hours_ago || ' hours')::interval
from (values
  (1, 'alice',   'fire',      6),
  (1, 'bob',     'rod',       8),
  (1, 'charlie', 'mind',     11),
  (2, 'bob',     'fire',      4),
  (3, 'alice',   'handshake', 2)
) as v(catch_rank, user_alias, kind, hours_ago)
join (
  select id, row_number() over (order by caught_at desc) as r
  from public.catches
  where angler_id = (select id from _seed_users where alias = 'jose')
) c on c.r = v.catch_rank
join _seed_users u on u.alias = v.user_alias;

-- Comments: a couple on Jose's biggest bass.
insert into public.comments (catch_id, author_id, body, created_at)
select c.id, u.id, v.body, now() - (v.hours_ago || ' hours')::interval
from (values
  ('alice', 'Dude. PB. The chatterbait curse continues.', 6),
  ('bob',   'Send me the GPS or we are no longer friends.', 5)
) as v(user_alias, body, hours_ago)
join (
  select id from public.catches
  where angler_id = (select id from _seed_users where alias = 'jose')
  order by weight_kg desc nulls last
  limit 1
) c on true
join _seed_users u on u.alias = v.user_alias;

-- ----------------------------------------------------------------------------
-- 9. Sanity output — counts so you can see what landed.
-- ----------------------------------------------------------------------------
select
  (select count(*) from public.profiles  where id in (select id from _seed_users))   as profiles,
  (select count(*) from public.friendships
     where requester_id in (select id from _seed_users)
        or addressee_id in (select id from _seed_users))                              as friendships,
  (select count(*) from public.catches   where angler_id in (select id from _seed_users)) as catches,
  (select count(*) from public.personal_records
     where angler_id in (select id from _seed_users))                                 as personal_records,
  (select count(*) from public.user_badges
     where angler_id in (select id from _seed_users))                                 as user_badges,
  (select count(*) from public.trips     where angler_id in (select id from _seed_users)) as trips,
  (select count(*) from public.tournaments
     where creator_id in (select id from _seed_users))                                as tournaments,
  (select count(*) from public.tournament_members
     where angler_id in (select id from _seed_users))                                 as tournament_members,
  (select count(*) from public.tournament_entries
     where angler_id in (select id from _seed_users))                                 as tournament_entries,
  (select count(*) from public.tournament_chat_messages
     where author_id in (select id from _seed_users))                                 as chat_messages,
  (select count(*) from public.feed_reactions
     where user_id in (select id from _seed_users))                                   as reactions,
  (select count(*) from public.comments
     where author_id in (select id from _seed_users))                                 as comments,
  (select count(*) from public.notifications
     where recipient_id in (select id from _seed_users))                              as notifications;

commit;
