-- ============================================================================
-- 0009 — Storytelling layer schema
--
-- M5 introduces three tables that turn raw catch data into stories:
--
--   * personal_records  — auto-detected best (weight, length) per angler+species
--   * badges            — global definition table (admin-curated, public read)
--   * user_badges       — earned-badge ledger per angler
--
-- Detection runs server-side via an AFTER INSERT/UPDATE trigger on `catches`,
-- not on the client. Reason: when M6 ships the offline sync queue, replays
-- shouldn't lose PRs because the device that recorded them was offline at
-- competing-catch sync time. The DB sees every row in commit order — the
-- only durable home for the contract.
--
-- RLS:
--   * personal_records — owner-only read/write
--   * user_badges      — owner-only read; insert via security-definer trigger
--   * badges           — public read (every user needs to know what badges
--                         exist); admin-only write via service role
--
-- Note on `sunrise_warrior` (catch-before-7am-local):
--   The origin doc lists this badge. Evaluating "local hour" server-side
--   requires per-user timezone, which v1 does not capture. Until M6 adds
--   timezone-aware predicates, the seed list ships TZ-safe badges only:
--   first_catch, ten_catches, hundred_catches, first_species, species_slam.
--   sunrise_warrior is documented as a deferred badge.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- personal_records
-- ----------------------------------------------------------------------------
create type public.pr_metric as enum ('weight_kg', 'length_cm');

create table if not exists public.personal_records (
  id uuid primary key default gen_random_uuid(),
  angler_id uuid not null references public.profiles(id) on delete cascade,
  species_id uuid references public.species(id) on delete cascade,
  metric public.pr_metric not null,
  value numeric(10, 3) not null check (value >= 0),
  catch_id uuid not null references public.catches(id) on delete cascade,
  achieved_at timestamptz not null default now(),
  unique (angler_id, species_id, metric)
);

create index if not exists personal_records_angler_idx
  on public.personal_records (angler_id, achieved_at desc);

alter table public.personal_records enable row level security;

drop policy if exists personal_records_owner_select on public.personal_records;
create policy personal_records_owner_select on public.personal_records
  for select to authenticated using (angler_id = auth.uid());

-- Inserts/updates happen exclusively from the trigger (security-definer);
-- direct client writes are denied by absence of an INSERT/UPDATE policy.
-- The trigger bypasses RLS via security-definer, so we need no policy.

-- ----------------------------------------------------------------------------
-- badges (global definitions)
-- ----------------------------------------------------------------------------
create table if not exists public.badges (
  code text primary key,
  title text not null,
  description text not null,
  icon_name text not null,
  predicate text not null check (
    predicate in (
      'first_catch',
      'count_catches',
      'first_species',
      'species_slam_in_day'
    )
  ),
  params jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.badges enable row level security;

drop policy if exists badges_public_select on public.badges;
create policy badges_public_select on public.badges
  for select to authenticated using (true);

-- No insert/update/delete policies — admin writes via service role.

-- ----------------------------------------------------------------------------
-- user_badges (earned ledger)
-- ----------------------------------------------------------------------------
create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  angler_id uuid not null references public.profiles(id) on delete cascade,
  badge_code text not null references public.badges(code) on delete cascade,
  earned_at timestamptz not null default now(),
  source_catch_id uuid references public.catches(id) on delete set null,
  unique (angler_id, badge_code)
);

create index if not exists user_badges_angler_idx
  on public.user_badges (angler_id, earned_at desc);

alter table public.user_badges enable row level security;

drop policy if exists user_badges_owner_select on public.user_badges;
create policy user_badges_owner_select on public.user_badges
  for select to authenticated using (angler_id = auth.uid());

-- No insert policy — earned badges are written exclusively by the
-- security-definer trigger, never directly by clients.

-- ----------------------------------------------------------------------------
-- Predicate evaluator — pure SQL helper called by the trigger
-- Returns true when the just-inserted catch causes the predicate to fire
-- for the first time.
-- ----------------------------------------------------------------------------
create or replace function public.check_badge_earned(
  p_angler_id uuid,
  p_catch_id uuid,
  p_caught_at timestamptz,
  p_species_id uuid,
  p_predicate text,
  p_params jsonb
) returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  total_count int;
  distinct_species int;
  same_day_distinct int;
  required int;
begin
  case p_predicate
    when 'first_catch' then
      select count(*) into total_count
        from public.catches
        where angler_id = p_angler_id;
      return total_count = 1;

    when 'count_catches' then
      required := coalesce((p_params->>'count')::int, 0);
      select count(*) into total_count
        from public.catches
        where angler_id = p_angler_id;
      return total_count >= required;

    when 'first_species' then
      if p_species_id is null then return false; end if;
      select count(distinct species_id) into distinct_species
        from public.catches
        where angler_id = p_angler_id and species_id is not null;
      return distinct_species = 1;

    when 'species_slam_in_day' then
      required := coalesce((p_params->>'count')::int, 3);
      if p_species_id is null then return false; end if;
      select count(distinct species_id) into same_day_distinct
        from public.catches
        where angler_id = p_angler_id
          and species_id is not null
          and date_trunc('day', caught_at) = date_trunc('day', p_caught_at);
      return same_day_distinct >= required;

    else
      -- Unknown predicate — never fire, never crash.
      return false;
  end case;
end;
$$;

-- ----------------------------------------------------------------------------
-- Trigger: on catches AFTER INSERT OR UPDATE, evaluate PR + badges
-- ----------------------------------------------------------------------------
create or replace function public.tg_evaluate_storytelling_after_catch()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  b record;
  prior_value numeric;
begin
  -- ---------- Personal Records ----------
  -- weight_kg
  if new.weight_kg is not null and new.species_id is not null then
    select value into prior_value
      from public.personal_records
      where angler_id = new.angler_id
        and species_id = new.species_id
        and metric = 'weight_kg';

    if prior_value is null then
      insert into public.personal_records
        (angler_id, species_id, metric, value, catch_id)
        values (new.angler_id, new.species_id, 'weight_kg',
                new.weight_kg, new.id);
    elsif new.weight_kg > prior_value then
      update public.personal_records
        set value = new.weight_kg,
            catch_id = new.id,
            achieved_at = now()
        where angler_id = new.angler_id
          and species_id = new.species_id
          and metric = 'weight_kg';
    end if;
  end if;

  -- length_cm
  if new.length_cm is not null and new.species_id is not null then
    select value into prior_value
      from public.personal_records
      where angler_id = new.angler_id
        and species_id = new.species_id
        and metric = 'length_cm';

    if prior_value is null then
      insert into public.personal_records
        (angler_id, species_id, metric, value, catch_id)
        values (new.angler_id, new.species_id, 'length_cm',
                new.length_cm, new.id);
    elsif new.length_cm > prior_value then
      update public.personal_records
        set value = new.length_cm,
            catch_id = new.id,
            achieved_at = now()
        where angler_id = new.angler_id
          and species_id = new.species_id
          and metric = 'length_cm';
    end if;
  end if;

  -- ---------- Badges ----------
  for b in select code, predicate, params from public.badges loop
    if public.check_badge_earned(
        new.angler_id, new.id, new.caught_at, new.species_id,
        b.predicate, b.params)
    then
      insert into public.user_badges
        (angler_id, badge_code, source_catch_id)
        values (new.angler_id, b.code, new.id)
      on conflict (angler_id, badge_code) do nothing;
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists tg_storytelling_after_catch on public.catches;
create trigger tg_storytelling_after_catch
  after insert or update of weight_kg, length_cm, species_id, caught_at
  on public.catches
  for each row execute function public.tg_evaluate_storytelling_after_catch();

-- ----------------------------------------------------------------------------
-- Seed v1 badge definitions
-- ----------------------------------------------------------------------------
insert into public.badges (code, title, description, icon_name, predicate, params)
values
  ('first_catch',
   'First Catch',
   'You logged your very first catch. Welcome aboard.',
   'set_meal',
   'first_catch',
   '{}'::jsonb),
  ('ten_catches',
   'Tackle Box',
   '10 catches logged. You are getting the hang of it.',
   'inventory_2',
   'count_catches',
   '{"count": 10}'::jsonb),
  ('hundred_catches',
   'Centurion',
   '100 catches logged. Serious dedication.',
   'workspace_premium',
   'count_catches',
   '{"count": 100}'::jsonb),
  ('first_species',
   'Field Guide',
   'Logged a catch with a species. Identification matters.',
   'menu_book',
   'first_species',
   '{}'::jsonb),
  ('species_slam',
   'Slam Day',
   '3+ different species in a single day. Mixed-bag mastery.',
   'auto_awesome',
   'species_slam_in_day',
   '{"count": 3}'::jsonb)
on conflict (code) do update
  set title = excluded.title,
      description = excluded.description,
      icon_name = excluded.icon_name,
      predicate = excluded.predicate,
      params = excluded.params;

-- Refresh PostgREST schema cache.
notify pgrst, 'reload schema';

commit;
