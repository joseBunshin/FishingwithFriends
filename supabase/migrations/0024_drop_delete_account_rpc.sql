-- ============================================================================
-- 0024 — drop the broken delete_account() RPC introduced in 0023
--
-- 0023 tried to delete the auth.users row directly from a security-definer
-- function. Supabase blocks that ("direct deletion from tables is not
-- allowed") — the only supported path is the auth admin API, which needs
-- the service-role key and therefore has to run from an edge function.
--
-- The replacement lives at `supabase/functions/delete-account/index.ts`,
-- which the Flutter client invokes via `client.functions.invoke('delete-account')`.
-- See `docs/EDGE_FUNCTIONS.md` for the deploy + verify steps.
--
-- This migration cleans up the dead function so the Postgres surface
-- matches the actual deletion architecture.
-- ============================================================================

begin;

drop function if exists public.delete_account();

notify pgrst, 'reload schema';

commit;
