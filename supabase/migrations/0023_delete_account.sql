-- ============================================================================
-- 0023 — self-serve account deletion (Apple Guideline 5.1.1(v))
--
-- Apple now requires that any app letting users create an account in-app
-- must also let them delete that account in-app. Same expectation applies
-- on Google Play. Without it, v1 submission is a hard reject.
--
-- This migration adds `public.delete_account()` — a security-definer
-- function the signed-in client can RPC into. The function:
--
--   1. Reads auth.uid() — bails if no session is attached.
--   2. Removes the user's storage objects from `avatars/<uid>/...`
--      and `catches/<uid>/...`. Storage objects don't auto-cascade
--      from auth.users, so we wipe them explicitly.
--   3. Deletes the row from `auth.users`. Profiles, catches, trips,
--      tournament memberships/entries, friendships, notifications,
--      device_tokens, and notification_preferences all have
--      `on delete cascade` references back through profiles, so a
--      single delete here wipes the user's footprint app-wide.
--
-- Security: SECURITY DEFINER + EXECUTE granted only to `authenticated`.
-- The function never accepts a user-supplied id; it always operates on
-- auth.uid(), so a malicious client cannot use it to delete anyone else.
-- ============================================================================

begin;

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- Wipe the user's storage objects in both buckets. Path convention is
  -- `<user_id>/<filename>` for both `avatars` (0019) and `catches` (0002).
  delete from storage.objects
   where bucket_id in ('avatars', 'catches')
     and (storage.foldername(name))[1] = v_uid::text;

  -- Cascade everything else through the FK chain by removing the auth user.
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;

notify pgrst, 'reload schema';

commit;
