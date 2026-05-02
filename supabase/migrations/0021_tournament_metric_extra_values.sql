-- ============================================================================
-- 0021 — extend tournament_metric enum with the four extra scoring methods
--
-- The 0001 enum shipped only `weight` + `length`, but the Dart
-- TournamentMetric enum + Leaderboard.compute already support four more
-- modes the create-tournament UI wants to expose:
--
--   biggest_fish   — heaviest single approved entry per angler
--   most_catches   — count of approved entries per angler
--   longest_catch  — longest single approved entry per angler
--   biggest_single — global single-fish ranking, used for side pots
--
-- ALTER TYPE ... ADD VALUE IF NOT EXISTS is the safe additive form —
-- safe to re-run, no data migration needed.
-- ============================================================================

begin;

alter type public.tournament_metric add value if not exists 'biggest_fish';
alter type public.tournament_metric add value if not exists 'most_catches';
alter type public.tournament_metric add value if not exists 'longest_catch';
alter type public.tournament_metric add value if not exists 'biggest_single';

-- Refresh PostgREST schema cache so the dashboard sees the new values.
notify pgrst, 'reload schema';

commit;
