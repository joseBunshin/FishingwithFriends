-- ============================================================================
-- 0007 — fix infinite-recursion in tournaments RLS
--
-- The 0001 policies for `tournaments` and `tournament_members` reference
-- each other via EXISTS subqueries. When PostgREST evaluates them as the
-- authenticated role, the planner spirals — Postgres surfaces this as
-- "infinite recursion detected in policy for relation tournaments".
--
-- Fix: introduce two `security definer` helpers that read the
-- cross-referenced rows without triggering RLS, and rewrite every
-- tournament-family policy that previously inlined an EXISTS to call
-- the helpers instead.
--
-- Affected policies recreated:
--   * tournaments_select
--   * tournament_members_select
--   * tournament_members_update_creator
--   * tournament_members_delete_self_or_creator
--   * tournament_entries_select
--   * tournament_entries_insert
--   * tournament_entries_update_creator
--   * side_pots_select          (from 0006)
--   * side_pots_creator_write   (from 0006)
--   * chat_select_member        (from 0006)
--   * chat_insert_member        (from 0006)
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- Helpers — security definer so they read past RLS
-- ----------------------------------------------------------------------------

create or replace function public.tournament_creator_id(tid uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select creator_id from public.tournaments where id = tid;
$$;

create or replace function public.is_accepted_tournament_member(tid uuid, uid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.tournament_members
    where tournament_id = tid
      and angler_id = uid
      and status = 'accepted'
  );
$$;

-- ----------------------------------------------------------------------------
-- tournaments
-- ----------------------------------------------------------------------------

drop policy if exists tournaments_select on public.tournaments;
create policy tournaments_select on public.tournaments
  for select to authenticated using (
    is_public
    or creator_id = auth.uid()
    or public.is_accepted_tournament_member(id, auth.uid())
  );

-- ----------------------------------------------------------------------------
-- tournament_members
-- ----------------------------------------------------------------------------

drop policy if exists tournament_members_select on public.tournament_members;
create policy tournament_members_select on public.tournament_members
  for select to authenticated using (
    angler_id = auth.uid()
    or public.tournament_creator_id(tournament_id) = auth.uid()
  );

drop policy if exists tournament_members_update_creator on public.tournament_members;
create policy tournament_members_update_creator on public.tournament_members
  for update to authenticated
  using (
    public.tournament_creator_id(tournament_id) = auth.uid()
    and public.tournament_creator_id(tournament_id) <> tournament_members.angler_id
  )
  with check (
    public.tournament_creator_id(tournament_id) = auth.uid()
    and public.tournament_creator_id(tournament_id) <> tournament_members.angler_id
  );

drop policy if exists tournament_members_delete_self_or_creator on public.tournament_members;
create policy tournament_members_delete_self_or_creator on public.tournament_members
  for delete to authenticated using (
    angler_id = auth.uid()
    or public.tournament_creator_id(tournament_id) = auth.uid()
  );

-- ----------------------------------------------------------------------------
-- tournament_entries
-- ----------------------------------------------------------------------------

drop policy if exists tournament_entries_select on public.tournament_entries;
create policy tournament_entries_select on public.tournament_entries
  for select to authenticated using (
    angler_id = auth.uid()
    or public.tournament_creator_id(tournament_id) = auth.uid()
    or public.is_accepted_tournament_member(tournament_id, auth.uid())
  );

drop policy if exists tournament_entries_insert on public.tournament_entries;
create policy tournament_entries_insert on public.tournament_entries
  for insert to authenticated with check (
    angler_id = auth.uid()
    and exists (
      select 1 from public.catches c
      where c.id = tournament_entries.catch_id
        and c.angler_id = auth.uid()
    )
    and public.is_accepted_tournament_member(tournament_id, auth.uid())
  );

drop policy if exists tournament_entries_update_creator on public.tournament_entries;
create policy tournament_entries_update_creator on public.tournament_entries
  for update to authenticated
  using (
    public.tournament_creator_id(tournament_id) = auth.uid()
    and public.tournament_creator_id(tournament_id) <> tournament_entries.angler_id
  )
  with check (
    public.tournament_creator_id(tournament_id) = auth.uid()
    and public.tournament_creator_id(tournament_id) <> tournament_entries.angler_id
  );

-- ----------------------------------------------------------------------------
-- tournament_side_pots (created in 0006)
-- ----------------------------------------------------------------------------

drop policy if exists side_pots_select on public.tournament_side_pots;
create policy side_pots_select on public.tournament_side_pots
  for select to authenticated using (
    public.tournament_creator_id(tournament_id) = auth.uid()
    or public.is_accepted_tournament_member(tournament_id, auth.uid())
  );

drop policy if exists side_pots_creator_write on public.tournament_side_pots;
create policy side_pots_creator_write on public.tournament_side_pots
  for all to authenticated
  using (public.tournament_creator_id(tournament_id) = auth.uid())
  with check (public.tournament_creator_id(tournament_id) = auth.uid());

-- ----------------------------------------------------------------------------
-- tournament_chat_messages (created in 0006)
-- ----------------------------------------------------------------------------

drop policy if exists chat_select_member on public.tournament_chat_messages;
create policy chat_select_member on public.tournament_chat_messages
  for select to authenticated using (
    public.tournament_creator_id(tournament_id) = auth.uid()
    or public.is_accepted_tournament_member(tournament_id, auth.uid())
  );

drop policy if exists chat_insert_member on public.tournament_chat_messages;
create policy chat_insert_member on public.tournament_chat_messages
  for insert to authenticated with check (
    author_id = auth.uid()
    and (
      public.tournament_creator_id(tournament_id) = auth.uid()
      or public.is_accepted_tournament_member(tournament_id, auth.uid())
    )
  );

-- ----------------------------------------------------------------------------
-- Refresh PostgREST schema cache so it sees the new policies
-- ----------------------------------------------------------------------------

notify pgrst, 'reload schema';

commit;
