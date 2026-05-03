-- ============================================================================
-- 0020 — friend-visibility on personal_records + user_badges
--
-- The 0009 storytelling layer locked PRs and user_badges to owner-only
-- reads. That was correct for M5 when storytelling lived on the Me tab,
-- but the M7+ "social profile" surface needs friends to see each other's
-- badges and PRs the way they already see each other's catches (per the
-- 0001 catches RLS via `public.are_friends`).
--
-- This migration broadens the SELECT policies. Writes stay locked: PRs
-- and user_badges are still written exclusively by the security-definer
-- trigger (`tg_evaluate_storytelling_after_catch`) — we do not add
-- INSERT/UPDATE/DELETE policies for clients.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- personal_records
-- ----------------------------------------------------------------------------
drop policy if exists personal_records_owner_select on public.personal_records;

create policy personal_records_self_or_friends_select
  on public.personal_records
  for select to authenticated
  using (
    angler_id = auth.uid()
    or public.are_friends(auth.uid(), angler_id)
  );

-- ----------------------------------------------------------------------------
-- user_badges
-- ----------------------------------------------------------------------------
drop policy if exists user_badges_owner_select on public.user_badges;

create policy user_badges_self_or_friends_select
  on public.user_badges
  for select to authenticated
  using (
    angler_id = auth.uid()
    or public.are_friends(auth.uid(), angler_id)
  );

-- Refresh PostgREST schema cache so the dashboard sees the new policies.
notify pgrst, 'reload schema';

commit;
