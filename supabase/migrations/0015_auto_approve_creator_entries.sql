-- ============================================================================
-- 0015 — auto-approve tournament entries submitted by the creator
--
-- After 0014 the creator can submit their own catches as entries (they
-- pass the is_accepted_tournament_member check). But the entry lands in
-- `pending` status, which means the creator has to "approve" their own
-- entry — a no-op tap that confuses everyone.
--
-- Fix: a BEFORE INSERT trigger on tournament_entries that, when the
-- submitter is the tournament's creator, stamps:
--   status = 'approved'
--   approved_at = now()
--   approved_by = creator_id
--
-- Server-side so a buggy or malicious client can't reach the same state
-- by guessing column names; the existing tournament_entries_update_creator
-- policy still gates manual approval/rejection of others' entries.
-- ============================================================================

begin;

create or replace function public.tg_auto_approve_creator_entry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_creator uuid;
begin
  v_creator := public.tournament_creator_id(new.tournament_id);
  if v_creator is not null and v_creator = new.angler_id then
    new.status := 'approved';
    new.approved_at := now();
    new.approved_by := v_creator;
  end if;
  return new;
end;
$$;

drop trigger if exists tournament_entries_auto_approve_creator
  on public.tournament_entries;
create trigger tournament_entries_auto_approve_creator
  before insert on public.tournament_entries
  for each row execute function public.tg_auto_approve_creator_entry();

-- Backfill existing pending entries from creators (e.g., entries that
-- landed in this state before today's fix) so the leaderboard reflects
-- reality.
update public.tournament_entries e
  set status = 'approved',
      approved_at = coalesce(e.approved_at, now()),
      approved_by = e.angler_id
  where e.status = 'pending'
    and e.angler_id = public.tournament_creator_id(e.tournament_id);

notify pgrst, 'reload schema';

commit;
