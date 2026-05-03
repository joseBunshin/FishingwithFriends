# Fishing with Friends

Social angling app for iOS and Android — catch logging, friend feeds, and competitive tournaments. Migration of the Lovable web prototype into a production Flutter + Supabase app.

> Bunshin Development Studios © 2026 · Spec v1.0

## Stack

- **Flutter** (multi-platform iOS / Android)
- **Riverpod** for state
- **go_router** for navigation
- **Supabase** — PostgreSQL, Realtime, Gotrue auth, private Storage with signed URLs
- **PostGIS** for catch geometry (with optional Secret Spot privacy)

## Quick start

```bash
# 1. Install Flutter 3.41+
flutter --version

# 2. Install dependencies
flutter pub get

# 3. Configure Supabase
cp .env.example .env
#   then fill SUPABASE_URL and SUPABASE_ANON_KEY

# 4. Run the schema migrations against your Supabase project
#    See docs/SUPABASE_SETUP.md

# 5. Run the app
flutter run                       # auto-pick device
flutter run -d "iPhone 15 Pro"    # specific iOS sim
flutter run -d emulator-5554      # specific Android emulator
```

## Project layout

```
lib/
  app.dart                      MaterialApp.router root
  main.dart                     bootstrap (env, Supabase, ProviderScope)
  core/
    env/                        .env loader
    error/                      AppException hierarchy
    router/                     go_router + AppShell (bottom nav + FAB)
    supabase/                   shared Supabase providers
    theme/                      colors, gradients, spacing tokens, theme builder
  features/
    auth/                       sign-in / sign-up
    catches/                    "Hero" catch logging + my catches grid
    social/                     friend-only activity feed
    tournaments/                tournament list + leaderboard (WIP)
    profile/                    profile, friends, sign-out
    notifications/              (planned)
supabase/
  migrations/
    0001_init.sql               schema + RLS for all tables
    0002_storage_policies.sql   private 'catches' bucket policies
    0003_units_and_species.sql  canonical metric + species water_type + seed
    0004_catch_metadata.sql     catch_and_release + rig columns + view recreate
    0005_trips_and_social.sql   trips + reactions + comments + notification triggers
    0006_tournaments_realtime.sql  tournaments realtime: snapshot entries + chat + side pots
    0007_tournament_rls_recursion_fix.sql  security-definer helpers for tournament RLS
    0008_auto_profile_on_signup.sql  trigger + backfill so auth.users -> public.profiles
    0009_storytelling_schema.sql  PRs / badges / user_badges + auto-detect trigger
    0010_conditions_autofill.sql  pg_net trigger + RPC for conditions edge fn
  functions/
    conditions-fill/              Deno edge fn: Open-Meteo + NOAA Tides
assets/
  geo/
    mpa_simplified.geojson      bundled US Marine Protected Area polygons (M4)
docs/
  SUPABASE_SETUP.md             one-pager for backend bootstrap
```

Each feature folder uses a `data / domain / presentation` split as it grows.

## Feature status (v1)

| Module | Status |
|---|---|
| Visual system — navy + orange + paper, soft cards, no gradient chrome | ✅ M0/U1 |
| Bottom-nav — 8 tabs (Home / Catches / Log / Stats / Tourneys / Map / Friends / Me) | ✅ M0/U2 |
| Home tab — stat tiles + recent catches, derived from real catches | ✅ M0/U3, M1/U5 |
| Catch Log — multi-photo, unit toggles, Secret Spot + Catch & Release, **persists end-to-end** | ✅ M0/U4 + M1/U2–U4 |
| Sign-In — Supabase email + password, off-white surface | ✅ M0/U5 |
| Schema — canonical metric, species water_type, catch metadata, ~30-species seed | ✅ M0/U6 + M1/U1 |
| Catches grid — photo-first tiles with signed URLs + hero transitions | ✅ M1/U6 |
| Catch detail — photo carousel, measurement pills, Secret Spot enforcement | ✅ M1/U7 |
| Friends-only RLS contract proof (gated integration test) | ✅ M1/U8 + M2/U10 + M3/U9 (extended for tournament-context visibility) |
| Trips — start, end, attach catches, /trips/:id detail | ✅ M2/U1–U3 + U7 |
| Friends — search, request, accept, reject, list | ✅ M2/U4 + U5 |
| Activity Feed — friends + self, reactions, comments, @mentions | ✅ M2/U6 + U8 + U9 |
| **Tournaments — create, invite/join-by-code, approve members + entries, realtime leaderboard, chat, side pots** | ✅ M3 |
| **Catch Map — flutter_map + OSM, own/friend pins, heatmap toggle, Secret Spot suppression, NOAA MPA awareness** | ✅ M4 |
| **Stats deepening — time-of-day heatmap, vs-friends comparison, conditions correlation placeholder** | ✅ M4 |
| **Storytelling — auto-detected PRs + badges (5 seeded), streaks, catch comparison context, share cards (PNG export), Year-in-Review** | ✅ M5 |
| **Offline-first — drift SQLite outbox + sync orchestrator, optimistic UI badges + sync pill, photo retry** | ✅ M6a |
| **Conditions auto-fill — Open-Meteo + NOAA Tides edge function via pg_net trigger, conditions block on detail, Stats correlation unlock** | ✅ M6b (deploy edge fn — see `docs/EDGE_FUNCTIONS.md`) |
| Push notifications (FCM/APNs), notification preferences | M6c (needs `flutterfire configure`) |
| **Onboarding — 3-step flow (display name + handle, home water, find friends); edit profile on Me tab** | ✅ M7 (partial) |
| App icon + launch screen; store submission metadata | M7 polish (needs Mac for iOS builds) |

## Design rules

- Navy primary + warm orange accent on off-white paper surface (matches Lovable references in `Assests/`).
- White rounded cards with soft single-shadow. **No gradient chrome.** Gradients are reserved for celebratory moments only — `AppGradients.celebration` for PR takeovers and badge unlocks.
- Hero image transitions on catch detail.
- Haptic feedback on save (`HapticFeedback.heavyImpact()`).
- 56pt minimum tap targets — `AppSpacing.minTap` — for wet/outdoor hands.
- 8-tab bottom-nav as the primary navigation surface; Log is a regular tab (not a FAB).

## Security rules (from spec §6)

- **RLS everywhere.** Friend-only visibility is enforced at the database, not just the client. See `supabase/migrations/0001_init.sql`.
- **No public buckets.** Catch photos live in a private bucket and reach friends only via short-lived signed URLs.
- **No self-approval.** Tournament creators cannot approve their own membership or entries — enforced by RLS `with check` clauses.
- **Validation.** Numeric ranges and ordering invariants (`ends_at > starts_at`) sit in CHECK constraints; client-side validation is for UX, not security.

## Useful commands

```bash
flutter analyze                       # static analysis
flutter test                          # unit / widget tests
dart run build_runner build           # codegen for freezed/riverpod
dart run build_runner watch           # codegen in watch mode
```

### Running integration tests

The friends-only RLS suite runs against your dev Supabase project to prove the privacy contract end-to-end. It is gated behind an env var so a default `flutter test` stays unit-only.

```bash
# bash / zsh
FWF_INTEGRATION=true flutter test test_integration/friends_only_rls_test.dart

# PowerShell
$env:FWF_INTEGRATION='true'; flutter test test_integration/friends_only_rls_test.dart
```

Prerequisites:

- `.env` points at a **dev** Supabase project (never prod — the test creates and deletes rows).
- Migrations 0001–0004 have run.
- **Email confirmation is OFF** in Authentication → Providers → Email so the test users (`rls-a@fwf-test.local`, `rls-b@…`, `rls-c@…`) are immediately usable after sign-up.

The suite is idempotent — re-running re-uses the same test users and cleans up its own catches in `tearDownAll`.

## Contributing

Use the project's Compound Engineering skills:

- `/ce-plan` to break down a feature
- `/ce-work` to execute it
- `/ce-code-review` before opening a PR
- `/ce-commit` and `/ce-commit-push-pr` to ship

## License

Proprietary — Bunshin Development Studios © 2026.
