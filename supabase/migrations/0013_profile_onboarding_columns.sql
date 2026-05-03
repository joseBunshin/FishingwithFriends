-- ============================================================================
-- 0013 — onboarding columns on profiles
--
-- Adds the few profile fields the onboarding flow captures:
--   home_water       — favorite body of water (free text; "My Waters" v1.5
--                      will turn this into a typed reference)
--   onboarding_completed_at — null until the user finishes the flow.
--                              The router uses null vs non-null to decide
--                              whether to send them through onboarding
--                              after sign-in.
-- ============================================================================

begin;

alter table public.profiles
  add column if not exists home_water text,
  add column if not exists onboarding_completed_at timestamptz;

notify pgrst, 'reload schema';

commit;
