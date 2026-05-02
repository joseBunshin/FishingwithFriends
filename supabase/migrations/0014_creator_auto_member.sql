-- ============================================================================
-- 0014 — auto-enroll tournament creators as accepted members
--
-- M3 shipped a tournament_entries RLS policy that requires the inserting
-- angler to be an `accepted` row in tournament_members. The creator was
-- never auto-added to that table — `tournaments.creator_id` is the only
-- record of their role — so when a creator tries to submit their own
-- catch they hit:
--   42501: new row violates row-level security policy for table
--          "tournament_entries"
--
-- Fix: an AFTER INSERT trigger on tournaments that writes
-- (creator_id, 'accepted') into tournament_members. Plus a one-time
-- backfill for tournaments that exist before this migration.
--
-- This also makes member listings, side-pot visibility, and chat
-- counts accurate without each query needing to UNION the creator
-- separately.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- Trigger function — security definer so it bypasses RLS on the
-- members table (which restricts inserts to creator-only).
-- ----------------------------------------------------------------------------
create or replace function public.tg_tournament_creator_auto_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tournament_members (
    tournament_id, angler_id, status, approved_by
  )
  values (
    new.id, new.creator_id, 'accepted', new.creator_id
  )
  on conflict (tournament_id, angler_id) do nothing;
  return new;
end;
$$;

drop trigger if exists tournament_creator_auto_member
  on public.tournaments;
create trigger tournament_creator_auto_member
  after insert on public.tournaments
  for each row execute function public.tg_tournament_creator_auto_member();

-- ----------------------------------------------------------------------------
-- Backfill — every existing tournament gets its creator added.
-- ----------------------------------------------------------------------------
insert into public.tournament_members
  (tournament_id, angler_id, status, approved_by)
select
  t.id, t.creator_id, 'accepted', t.creator_id
from public.tournaments t
on conflict (tournament_id, angler_id) do update
  set status = 'accepted',
      approved_by = excluded.approved_by,
      updated_at = now();

-- Refresh PostgREST schema cache.
notify pgrst, 'reload schema';

commit;
