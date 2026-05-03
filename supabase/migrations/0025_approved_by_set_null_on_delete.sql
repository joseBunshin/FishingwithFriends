-- ============================================================================
-- 0025 — make `approved_by` FKs survive an account deletion
--
-- The `delete-account` edge function calls `auth.admin.deleteUser(uid)`,
-- which cascades through every FK that references `public.profiles(id)`.
-- All of them in the schema use `on delete cascade` — except two:
--
--   tournament_members.approved_by  → public.profiles(id)
--   tournament_entries.approved_by  → public.profiles(id)
--
-- Both came from 0001 without an `on delete` action, so they default to
-- `NO ACTION`. When a user who has approved a tournament member or entry
-- tries to delete their account, the cascade chain reaches these rows
-- and the FK fails with `23503 update or delete on table "profiles"
-- violates foreign key constraint`. The edge function surfaces this as
-- `500 auth-delete-failed`.
--
-- Cascading the whole approved row would be wrong — tournaments and
-- entries belong to the angler/creator, not the historical approver.
-- The right behaviour is `set null`: drop the approver pointer, keep
-- the row. Both columns are already nullable (no `not null` in 0001).
-- ============================================================================

begin;

alter table public.tournament_members
  drop constraint if exists tournament_members_approved_by_fkey;
alter table public.tournament_members
  add constraint tournament_members_approved_by_fkey
  foreign key (approved_by) references public.profiles(id)
  on delete set null;

alter table public.tournament_entries
  drop constraint if exists tournament_entries_approved_by_fkey;
alter table public.tournament_entries
  add constraint tournament_entries_approved_by_fkey
  foreign key (approved_by) references public.profiles(id)
  on delete set null;

notify pgrst, 'reload schema';

commit;
