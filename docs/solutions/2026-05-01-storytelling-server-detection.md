---
title: Storytelling — server-side PR + badge detection
date: 2026-05-01
type: architecture
milestone: M5
component: supabase/migrations/0009_storytelling_schema.sql
---

# Storytelling — server-side detection

M5 ships Personal Records and Badges as auto-detected outcomes, not user-driven actions. The decision was where to live: client-side post-save logic, or a Postgres trigger.

## Decision

**Server-side AFTER INSERT/UPDATE trigger on `catches`.** Implementation in `0009_storytelling_schema.sql` — `tg_evaluate_storytelling_after_catch()` is a security-definer function that:

1. Iterates the metric set (`weight_kg`, `length_cm`) and upserts the matching `personal_records` row when the new value strictly beats the prior best (or no prior exists).
2. Loops over rows in `badges` and calls `check_badge_earned(...)` to evaluate each predicate against the new catch + the angler's history. Inserts into `user_badges` on first earn, with `unique (angler_id, badge_code)` making double-grants a no-op.

## Why server-side

- **Offline-safety.** M6 introduces an offline sync queue. When a queued catch eventually reaches the server, the trigger fires in commit order. A device that was offline at the time of a competing catch insert is irrelevant — the DB sees both eventually, and PR/badge state stays consistent. Client-side detection on each device would diverge.
- **No per-device drift.** A user with two devices (phone + tablet) doesn't get out-of-sync PR rows because each device tried to compute "is this a PR?" against its own copy of catches.
- **One contract.** PostgREST clients, edge functions, and any future server-side automation all see the same trigger.

## Why declarative seeded badges, not a runtime DSL

The `badges` table holds `predicate text` (an enum-like) plus `params jsonb`. A small predicate evaluator (`check_badge_earned`) handles each enum value. Adding a new badge is a SQL insert; adding a *new kind* of predicate is a function patch.

For 5 v1 badges, a full DSL or rule-engine would be overkill. If we cross ~20 badges or need user-defined predicates (clubs writing their own), reassess.

## Why these 5 v1 badges

`first_catch`, `ten_catches`, `hundred_catches`, `first_species`, `species_slam`. All evaluate in pure SQL using either a count, an aggregate over the angler's history, or a same-day species set query. None require timezone awareness — a deliberate choice that avoids per-user TZ capture in v1.

The origin doc lists `sunrise_warrior` (catch before 7am local) which we deferred. Evaluating "before 7am local" needs the user's timezone to be stored or passed; M6's data model expansion is a better home.

## Predicate evaluator shape

```sql
case p_predicate
  when 'first_catch'           then ...
  when 'count_catches'         then ... params->>'count'::int
  when 'first_species'         then ...
  when 'species_slam_in_day'   then ... date_trunc('day', caught_at)
  else                              false  -- unknown predicate, never crash
end
```

Unknown predicate names return `false` rather than raising, so a future client running against an older DB (or vice versa) doesn't break catch inserts.

## RLS posture

- `personal_records`: `select` for owner. No insert/update/delete policy — trigger writes via security-definer.
- `user_badges`: `select` for owner. Same posture.
- `badges`: public `select` for authenticated users. No client write — admin via service role only.

## Test surface

- `test/features/storytelling/storytelling_repository_test.dart` covers the read path with hand-rolled data-source fakes.
- DB-level testing (trigger correctness against real catch inserts) lives in `test_integration/friends_only_rls_test.dart` — extended in M5 to assert that user B cannot read user A's `personal_records` or `user_badges` rows. *(Pending — to add when integration suite is run next.)*

## When to revisit

Move detection back to a client+server hybrid (or pure client) when **any** of:

- Badges grow beyond ~20 and the SQL evaluator becomes hard to read.
- We need user-defined or club-defined badges (predicates that vary per group).
- Per-user timezone becomes a first-class data model field — at that point evaluating local-time predicates is straightforward server-side.

## Related

- The celebration screen (`lib/features/storytelling/presentation/celebration_screen.dart`) reads `saveOutcomeProvider(catchId)` after a catch save. The trigger writes happen during the same DB transaction as the catch insert, so the immediate read finds them.
- The save-flow hook is best-effort — `catch_log_screen.dart` swallows errors from `saveOutcomeProvider` and degrades to the catch detail. Celebration never blocks save success.
