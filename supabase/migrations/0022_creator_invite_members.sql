-- ============================================================================
-- 0022 — let tournament creators directly invite anglers as members
--
-- The 0001 schema only allowed `tournament_members.insert` when the
-- inserter is inserting their OWN row with status='pending'. That's the
-- "I want to join" code-redemption path.
--
-- The "creator invites a friend" path was missing — there was no policy
-- letting the creator insert a row for someone else. Repo code already
-- shipped support (TournamentInput.invitedAnglerIds → insertMembers),
-- but every attempt RLS-failed silently.
--
-- This migration adds the second insert path. The check ensures only
-- the tournament's creator can insert a member row for any angler in
-- that tournament. Status not constrained — creators can add directly
-- as 'accepted' (vouched) or 'pending' (awaiting their own re-confirm).
--
-- The existing self-pending policy stays — both paths now work
-- side-by-side:
--   - angler self-inserts with status='pending' via join-code
--   - creator inserts any angler with any status via the invite UI
-- ============================================================================

begin;

-- Drop a possibly-broken earlier version of this policy that used
-- a direct EXISTS subquery on tournaments. That formulation triggered
-- the same cross-table RLS recursion 0007 originally fixed, so the
-- check failed at runtime with "new row violates row-level security
-- policy for table tournament_members".
drop policy if exists tournament_members_insert_creator
  on public.tournament_members;

-- Use the security-definer helper from 0007 to read tournaments.creator_id
-- without re-entering RLS. This breaks the recursion cleanly.
create policy tournament_members_insert_creator
  on public.tournament_members
  for insert to authenticated
  with check (
    public.tournament_creator_id(tournament_id) = auth.uid()
  );

notify pgrst, 'reload schema';

commit;
