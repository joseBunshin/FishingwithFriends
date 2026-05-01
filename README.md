# Fishing with Friends

Social angling app for iOS and Android — catch logging, friend feeds, and competitive tournaments. Migration of the Lovable web prototype into a production Flutter + Supabase app.

> Bunshin Studios © 2026 · Spec v1.0

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
docs/
  SUPABASE_SETUP.md             one-pager for backend bootstrap
```

Each feature folder uses a `data / domain / presentation` split as it grows.

## Feature status

| Module | Status |
|---|---|
| Auth (email + password) | UI wired, talks to Supabase |
| Catch logging UI (media-first, Secret Spot, numeric pads) | UI built, persistence pending |
| Activity feed | placeholder cards |
| Tournaments | placeholder cards |
| Friends / search | not started |
| Notifications center | not started |
| Live leaderboards (Realtime) | not started |

## Design rules (from spec §5)

- Minimalist, high-contrast — no background photography; use `AppGradients`.
- Hero image transitions on catch detail.
- Haptic feedback on save (`HapticFeedback.heavyImpact()`).
- 56pt minimum tap targets — `AppSpacing.minTap` — for wet/outdoor hands.
- Bottom-bar nav as the primary navigation surface.

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

## Contributing

Use the project's Compound Engineering skills:

- `/ce-plan` to break down a feature
- `/ce-work` to execute it
- `/ce-code-review` before opening a PR
- `/ce-commit` and `/ce-commit-push-pr` to ship

## License

Proprietary — Bunshin Studios © 2026.
