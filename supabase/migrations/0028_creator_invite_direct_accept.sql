-- ============================================================================
-- 0028 — fire tournament_invite notification on direct-accepted inserts
--
-- Original creator-invite flow inserted member rows with status='pending',
-- the 0006 invite trigger fired tournament_invite notifications, and the
-- creator (or invitee) had to flip the row to 'accepted' to actually join.
-- The TestFlight bug-batch-2 feedback called this out as friction — when
-- a tournament creator picks a friend, that friend is by definition
-- trusted, so a pending/approval round-trip is unnecessary.
--
-- App-side change (this batch): creator-side bulk invite (during create)
-- and InviteFriendsSheet inserts now use status='accepted'. This makes
-- those rows skip the approval gate, but it also means the 0006 trigger
-- (which only fired on status='pending') wouldn't surface the invite
-- notification at all.
--
-- This migration: relax the trigger so 'accepted' inserts also fire the
-- tournament_invite notification. The cold-invite path (requestJoinByCode)
-- still inserts as 'pending' and still gets the same notification, so
-- creators see incoming join requests on their side. The behavioral
-- separation is on the angler row's status, not on the trigger.
-- ============================================================================

begin;

create or replace function public.tg_notify_tournament_invite() returns trigger
language plpgsql security definer as $$
begin
  if new.status in ('pending', 'accepted') then
    insert into public.notifications (recipient_id, kind, payload)
    values (
      new.angler_id,
      'tournament_invite'::public.notification_kind,
      jsonb_build_object('tournament_id', new.tournament_id)
    );
  end if;
  return new;
end;
$$;

notify pgrst, 'reload schema';

commit;
