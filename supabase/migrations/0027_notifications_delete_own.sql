-- ============================================================================
-- 0027 — let users delete their own notifications
--
-- 0001 created notifications + select_own + update_own policies. There was
-- no DELETE policy, so the in-app swipe-to-delete added in fix-batch-2 U6
-- needs this. Hard delete (not soft) — once swiped, the row is gone. If
-- we want soft-delete later (audit trail, restore, etc.) we'd add a
-- deleted_at column in a future migration.
--
-- Apple App Store privacy expectation: user-deletable own data. This
-- aligns with that.
-- ============================================================================

begin;

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own on public.notifications
  for delete to authenticated using (recipient_id = auth.uid());

notify pgrst, 'reload schema';

commit;
