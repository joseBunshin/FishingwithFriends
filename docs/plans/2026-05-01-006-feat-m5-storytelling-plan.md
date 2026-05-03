---
title: "feat: M5 — Storytelling layer (PRs, badges, streaks, share cards, Year-in-Review)"
type: feat
status: active
date: 2026-05-01
origin: docs/brainstorms/fishing-with-friends-v1-requirements.md
parent_plan: docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md
---

# feat: M5 — Storytelling layer

## Summary

Turn raw catch data into stories: auto-detected Personal Records, milestone Badges, fishing-day Streaks, contextual catch comparisons ("3rd biggest largemouth this year"), branded share cards exported as PNG, and a Year-in-Review surface composed of static animated cards. This is the milestone where the logbook starts feeling like a product an angler wants to come back to and to invite friends into.

Branch off `feat/m4-map-and-stats` as `feat/m5-storytelling` (same stacked-PR pattern as M1–M4). Stop at M5; M6 (offline-first + conditions auto-fill + push) plans separately.

---

## Problem Frame

After M4, the data side is rich but the surfacing side is dry. A user opens the app and sees their catches as a list and a map. Nothing tells them they just landed their biggest bass of the year, that they're on a 4-week streak, or that this is the "3rd biggest largemouth this season." Year-end has no story to tell. There is no growth surface — friends-only means we have to depend on share cards to feel proud enough that an angler hands one to a buddy with "look what I caught."

The origin doc's Section C is unambiguous about this:

> *"Branded share cards: one-tap share to iMessage / Instagram / X / etc. with a beautifully composed card (photo + species + weight + length + location text). The only growth surface in a friends-only app — needs to be gorgeous."*

M5 ships the storytelling layer that makes a logbook feel like a product.

---

## Requirements

- R1. New schema: `personal_records`, `badges`, `user_badges` tables with RLS that lets only the owning angler read their own records and badges; friends never see another user's PR rows directly. Public read for the `badges` definition table (every user needs to know what badges exist).
- R2. PR auto-detection: when a catch is inserted with weight or length values, a Postgres trigger writes/updates the relevant `personal_records` row for that angler+species pair if the new value beats the prior best.
- R3. Badge auto-detection: when a catch is inserted, a Postgres trigger evaluates seeded badge predicates and inserts `user_badges` rows for any newly-earned badge.
- R4. Catch save flow surfaces a full-screen celebration when the just-saved catch produced a PR or earned a badge. Single take-over view, dismissable.
- R5. The Me tab shows the user's badge wall (earned + locked silhouettes), with each badge tappable to a brief description.
- R6. Streaks are derived from `catches.caught_at` per user — a "current streak" of consecutive distinct fishing days and a longest-streak record. No new schema; computed on the client.
- R7. Catch detail surfaces a comparison context line ("3rd biggest largemouth this year" / "biggest catch on Lake Mendota") when the catch ranks meaningfully.
- R8. A catch detail action exports a branded share card as PNG to the system share sheet. Card layout is photo-first with species, weight, length, and a privacy-respecting location label (or "Secret spot" when the catch flagged it).
- R9. A Year-in-Review entry point on the Me tab opens a paged screen of static animated cards: top catches, biggest, most-caught species, days fished, biggest trip, friend leaderboard. Generated entirely from client-side queries — no server work.
- R10. App still passes `flutter analyze` clean and `flutter test` green after every M5 unit lands.
- R11. Friends-only RLS contract (0001 + 0007) and existing RLS on `catches` / `tournaments` / `friendships` remain intact. No migration in M5 may relax visibility on existing tables.

**Origin actors carried forward:** A1 Recreational angler (every M5 surface targets A1), A2 Tournament participant (Year-in-Review surfaces tournament wins).

---

## Scope Boundaries

### Deferred for later

- **Year-in-Review video composition.** Origin doc lists "Generated client-side from Supabase data, exportable as a video / share card." The video composition piece (rendering the animated cards as MP4 / MOV via `flutter_ffmpeg` or similar) is **deferred to v1.5**. M5 ships the animated-cards surface as a viewable + screenshot-shareable experience, not a video export. Rationale per parent plan: "video composition deferred to v1.5."
- **Voice-note transcription.** Audio capture itself is also deferred (origin doc lists notes/voice-notes; M0–M5 supports text notes only). Voice notes land in v1.5.
- **Photo species ID** (v1.5).
- **AI lure / depth / time suggestions** (v3).
- All M6+ work — offline-first, conditions auto-fill edge function, push notifications, onboarding polish, store submission. Each owns its own plan.

### Outside this product's identity

*(Carried verbatim from origin.)*

- Public profiles / public discovery / public catch feed.
- Marketplace / in-app gear sales.
- License or regulation enforcement.
- Prize disbursement or in-app payments.

### Deferred to Implementation

- **Final badge art.** M5 ships textual badge entries with placeholder Material icons. A designer pass for branded badge artwork can land in M7 polish without schema change (just an `icon_asset` column update or a client-side mapping).
- **Year-in-Review animation specifics** (timing, easing curves) — implementer picks during U9 against a "feel like Spotify Wrapped" reference. Not a planning question.
- **Share card photo treatment** — drop shadow, gradient border, watermark — implementer picks during U8 within the brand palette. Quality bar set by visual reference, not enumerated tokens.

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/catches/data/catches_repository.dart` — `create()` returns the inserted `Catch`. The PR + badge detection happens server-side via DB trigger (R2/R3); the Flutter side then fetches "what did this insert produce?" via a follow-up read. M5 introduces a thin "save outcome" provider that reads `personal_records` + `user_badges` for the just-saved catch.
- `lib/features/catches/presentation/catch_log_screen.dart` — `_save()` on success currently snackbars + pops. M5 changes this: route to the celebration screen if the save produced new PR(s) or badge(s); otherwise keep the existing snackbar+pop path.
- `lib/features/me/presentation/me_screen.dart` — placeholder. M5 adds a Badges section + Year-in-Review entry button.
- `lib/features/catches/presentation/catch_detail_screen.dart` — currently shows the catch with a tournament-submit action. M5 adds a "Share card" action and a comparison-context line.
- `supabase/migrations/0001_init.sql` — RLS contract baseline. M5 follows the same pattern (per-row owner-only read for personal_records + user_badges; public read on badges definitions).
- `supabase/migrations/0007_tournament_rls_recursion_fix.sql` — security-definer pattern is the right shape for any helper function used in a policy or trigger.

### Institutional Learnings

- `docs/solutions/2026-05-01-mpa-display-suppression.md` — established the "bundled asset + offline-first" pattern. M5's badge definitions are similarly low-churn data; we'll seed them once in the migration rather than push them via a CMS.
- `docs/SUPABASE_SETUP.md` documents the runlist convention; M5 adds migration 0009 to that list.

### External References

- **`screenshot` package** (`^3.0.0+`) or `RepaintBoundary` + `toImage` directly — Flutter's standard pattern to render a widget tree to PNG bytes. We'll use `RepaintBoundary` directly to avoid an extra dep; one screen captures the share-card widget. The `share_plus` package handles the system share sheet.
- **`share_plus`** (`^10.0.0+`) — first-party-style package with broad iOS / Android support. Adds one dep but the surface is small and deeply tested.
- **Streaks math** — pure-Dart, no library needed. Compute distinct local-day fishing dates from a sorted list of `caught_at`, count consecutive days from today backwards.
- **Spotify Wrapped / Apple Music Replay** — visual references for Year-in-Review's animated card style. Not literally cloned; we ship our own spin within the navy + orange palette.

---

## Key Technical Decisions

- **Server-side PR + badge detection via Postgres trigger, not client logic.** Client-side detection breaks under offline sync (M6) — a queue replay shouldn't lose PRs because the device that recorded them was offline when a competing catch synced. A trigger on `catches AFTER INSERT OR UPDATE` is the right home: it sees every persisted row in commit order, regardless of which device wrote it. M5 ships the trigger now even though the offline queue lands in M6, so the contract is in place before there's anything to retrofit.
- **PR detection considers both weight AND length per species.** A new "biggest weight largemouth" and a new "longest length largemouth" can co-exist as separate `personal_records` rows. Keys: `(angler_id, species_id, metric)` where metric = `weight_kg | length_cm`. Trigger updates only when the new value strictly beats the prior best.
- **Badges: declarative seeded definitions, evaluated as predicates.** The `badges` definition table holds `code`, `title`, `description`, `icon_name` (Material icon), and a server-side `predicate` recipe (e.g., enum + parameter). Trigger evaluates each predicate against the new catch context. Adding a new badge is a SQL insert, not a code change. M5 seeds: `first_catch`, `hundred_catches`, `first_species`, `sunrise_warrior` (catch before 7am local), `species_slam` (3+ distinct species same day).
- **Streaks computed client-side, not stored.** Streak math from a list of timestamps is cheap; storing a "current streak" column would risk drift. Provider derives current + longest from `myCatchesProvider`.
- **Save-flow celebration: route to a full screen, not a modal.** Modals stack awkwardly behind the catch detail and feel like a popup. The celebration is the *moment* — full-screen takeover with the photo, the headline ("New PR! Biggest Largemouth this year"), and an immediate share-card CTA.
- **Share card PNG export uses `RepaintBoundary` + `share_plus`, no third-party render package.** Build a `ShareCard` widget at the share-resolution we want (1080×1920 portrait), wrap in `RepaintBoundary`, capture, write to temp file, hand to `share_plus`. Self-contained; no native code; one new dep.
- **Year-in-Review is static animated cards, not a video.** Per parent plan. Video export is v1.5. M5's Year-in-Review screen is a swipeable PageView of cards each with their own enter animation; the user watches them in sequence and can screenshot.
- **Catch comparison line: query-on-render, not stored aggregate.** When the detail screen builds, a small provider issues a focused query for "how does this catch rank within angler+species this year." The cardinality is tiny per query (~hundreds of catches max for any angler in a year); no need for materialized aggregates in v1.
- **Badge silhouettes for unearned badges, not hidden.** All seeded badges show in the wall — earned in color, unearned greyed silhouette with the description. Anti-engagement-doomloop framing: the user knows what's possible, not what they're missing.

---

## Open Questions

### Resolved During Planning

- *Server-side trigger vs client-side detection:* trigger. Offline-safe.
- *PR scope — biggest weight only, or weight + length:* both. Cheap, and an angler who fishes for length cares.
- *Streak storage:* not stored. Derived.
- *Year-in-Review video export:* deferred to v1.5 per parent plan.
- *Share card sharing:* `share_plus`. One new dep, broad platform support.
- *Badge predicate language:* enum + parameters in SQL, not a DSL. Five seed badges fit comfortably; if it grows past ~20 we'll reconsider.
- *Celebration UX shape:* full-screen takeover, not modal.

### Deferred to Implementation

- *Exact share card pixel dimensions and typography* — implementer picks during U8. Aspect ratio target is 9:16 portrait (Instagram Story / TikTok); secondary 1:1 square for X/iMessage if cheap.
- *Year-in-Review card sequence and copy* — implementer picks during U9 within the documented set: top catches, biggest, most-caught species, days fished, biggest trip, friend leaderboard.
- *Whether streak resets at midnight UTC or local* — local. A user fishing at 11pm Saturday and 1am Sunday saw a single trip; not a streak break. Documented in U6 test scenarios.
- *Whether the catch detail comparison line shows on every catch or only "interesting" ranks* — only ranks ≤3 by default, all-time biggest always. Tunable in U7.

---

## High-Level Technical Design

> *Directional guidance, not implementation specification.*

```
M5 surface graph
─────────────────────────────────────────────────────────────────

      catches insert ──► [DB trigger]
                          ├─ evaluate PR predicates
                          │     update personal_records on beat
                          ├─ evaluate badge predicates
                          │     insert user_badges on first earn
                          └─ commit returns row id

      Catch save flow:
        catch row + saveOutcomeProvider(catchId) ──►
          { newPRs: [...], newBadges: [...] }
          │
          ├─ if any: route ► CelebrationScreen
          └─ else:   snackbar + pop (existing path)

      Me tab additions:
        BadgeWallSection (earned + silhouettes) ──► tap to BadgeDescriptionSheet
        StreakChip ("4-day streak")
        YearInReviewEntryButton ──► /year-in-review

      Catch detail additions:
        comparisonContextProvider(catchId) ──► "3rd biggest largemouth this year"
        ShareCardAction ──► RepaintBoundary capture ──► share_plus

      /year-in-review: PageView of animated cards built from
        myCatchesProvider + friendsCatchesProvider, no server queries.

────────────────────────────────────────────────────────────────
Schema delta (M5):
  personal_records (angler_id, species_id, metric, value, catch_id, ...)
  badges (code, title, description, icon_name, predicate, params)
  user_badges (angler_id, badge_code, earned_at, source_catch_id)
  trigger: tg_evaluate_storytelling_after_catch_insert ON catches
  RLS: owner-only read on personal_records + user_badges
       public read on badges (definitions are global)
  Seed: 5 badges (first_catch, hundred_catches, first_species,
                   sunrise_warrior, species_slam)
```

---

## Implementation Units

- U1. **Schema 0009 — `personal_records`, `badges`, `user_badges` + RLS + trigger + seed**

**Goal:** Land the storytelling schema with all triggers wired so subsequent units have a working server-side detection contract.

**Requirements:** R1, R2, R3, R10, R11.

**Dependencies:** None.

**Files:**
- Create: `supabase/migrations/0009_storytelling_schema.sql`
- Modify: `docs/SUPABASE_SETUP.md`

**Approach:**
- Create `personal_records (id uuid pk, angler_id uuid → profiles, species_id uuid → species, metric text check in ('weight_kg','length_cm'), value numeric, catch_id uuid → catches, achieved_at timestamptz default now(), unique(angler_id, species_id, metric))`.
- Create `badges (code text pk, title text not null, description text not null, icon_name text not null, predicate text not null check in ('first_catch','count_catches','first_species','catch_before_hour','species_slam_in_day'), params jsonb not null default '{}')`.
- Create `user_badges (id uuid pk, angler_id uuid → profiles, badge_code text → badges, earned_at timestamptz default now(), source_catch_id uuid → catches, unique(angler_id, badge_code))`.
- RLS: owner-only `select / insert / update / delete` on `personal_records`. Owner-only `select / insert` on `user_badges` (no update / delete — earned badges are permanent). `badges` table: public select for authenticated users; no insert / update / delete from clients (admin-only via service role).
- Trigger function `tg_evaluate_storytelling_after_catch_insert()` security-definer that: (a) iterates the metric set (weight_kg, length_cm), upserts the `personal_records` row when the new value strictly beats the prior best (NULL prior counts as "beat"); (b) iterates `badges`, evaluates predicate against the new catch's row + the angler's history, inserts `user_badges` on first earn (handled gracefully by `unique` constraint + `on conflict do nothing`).
- Seed 5 badges (codes + descriptions + icon names) at the bottom of the migration.
- `notify pgrst, 'reload schema';` at the end.

**Patterns to follow:**
- `0007_tournament_rls_recursion_fix.sql` — security-definer trigger pattern.
- `0001_init.sql` — RLS shape, `unique` constraints, FK cascade rules.

**Test scenarios:**
- Migration applies cleanly against a fresh project after 0001–0008.
- After insert of a 5kg largemouth catch by user A, `select * from personal_records where angler_id = A and species_id = largemouth` returns one row with `metric='weight_kg', value=5`. Inserting a second 4kg catch does not change the row.
- After insert of a longer largemouth than the recorded length PR, the length PR row updates; weight PR row unchanged.
- After user A's first catch ever, `user_badges` has a `first_catch` row.
- Badge re-grant attempt is silently ignored due to `unique(angler_id, badge_code)`.
- RLS guard: user B selecting from `personal_records` for user A's id returns zero rows; same for `user_badges`.
- RLS guard: any user can `select * from badges` and see all seeded definitions.

**Verification:**
- Migration runs in Supabase SQL Editor. `select count(*) from badges` returns 5.

---

- U2. **PR + badge data layer — domain models, repositories, providers**

**Goal:** Expose typed read access to `personal_records`, `badges`, `user_badges` and a "what just got produced by this insert" lookup.

**Requirements:** R1, R10.

**Dependencies:** U1.

**Files:**
- Create: `lib/features/storytelling/domain/personal_record.dart`
- Create: `lib/features/storytelling/domain/badge.dart` (definitions) + `user_badge.dart`
- Create: `lib/features/storytelling/data/storytelling_data_source.dart`
- Create: `lib/features/storytelling/data/storytelling_repository.dart`
- Create: `lib/features/storytelling/data/storytelling_repository_provider.dart`
- Test: `test/features/storytelling/storytelling_repository_test.dart`

**Approach:**
- `PersonalRecord` value: `id, anglerId, speciesId, speciesLabel?, metric (enum), value, catchId, achievedAt`.
- `Badge` definition value: `code, title, description, iconName, predicate, params`.
- `UserBadge` value: `id, anglerId, badgeCode, earnedAt, sourceCatchId, definition (joined Badge)`.
- Repository:
  - `Future<List<PersonalRecord>> myPersonalRecords()` ordered desc by `achievedAt`.
  - `Future<List<Badge>> allBadges()`.
  - `Future<List<UserBadge>> myUserBadges()`.
  - `Future<SaveOutcome> saveOutcomeFor(catchId)` — joined query that returns any PRs achieved with `catch_id = ?` and any user_badges with `source_catch_id = ?`.
- Providers as `FutureProvider`s following the M2/M3/M4 shape.
- `SaveOutcome` is a small value `{ List<PersonalRecord> newPRs, List<UserBadge> newBadges, bool get isCelebratory => newPRs.isNotEmpty || newBadges.isNotEmpty }`.

**Patterns to follow:**
- `lib/features/catches/data/catches_repository.dart` — repository shape with a `*_data_source.dart` thin wrapper.
- `lib/features/tournaments/data/tournaments_repository.dart` — joined query patterns.

**Test scenarios:**
- Recording fake data source returns canned rows; repository maps DTOs correctly.
- Empty `myUserBadges()` returns empty list, not null.
- `SaveOutcome.isCelebratory` true when at least one PR or badge present, false otherwise.
- `saveOutcomeFor(unknownId)` returns empty `SaveOutcome` cleanly.
- Error path: data source throws → repository wraps in `NetworkFailure`.

**Verification:**
- `flutter test test/features/storytelling/storytelling_repository_test.dart` green.

---

- U3. **Celebration screen + save-flow hookup**

**Goal:** After a catch save that produced PRs or badges, route to a full-screen celebration takeover. Otherwise keep the existing snackbar+pop flow.

**Requirements:** R4, R10.

**Dependencies:** U2.

**Files:**
- Create: `lib/features/storytelling/presentation/celebration_screen.dart`
- Create: `lib/features/storytelling/presentation/widgets/celebration_headline.dart`
- Modify: `lib/features/catches/presentation/catch_log_screen.dart` (`_save` success path)
- Modify: `lib/core/router/app_router.dart` (add `/celebrate/:catchId` route)
- Test: `test/features/storytelling/celebration_screen_test.dart`

**Approach:**
- After `catchesRepository.create(...)` returns the new `Catch`, the save path now: (a) reads `saveOutcomeFor(catch.id)`, (b) if `isCelebratory`, navigates to `/celebrate/${catch.id}` replacing the form; else snackbar+pop as today.
- `CelebrationScreen` consumes the `saveOutcome` provider for the given catch id. Renders:
  - Hero photo (first photo from the catch).
  - Headline: "New PR!" or "Badge unlocked!" depending on outcome.
  - Subhead: "{species} — {value}" for PR; "{badge title}" for badge.
  - Two CTAs: "Share card" (primary, navy filled) → triggers U8's share flow; "Done" (text) → pops to the home tab.
- Multiple new PRs / badges: stack them as a swipeable PageView with a dot indicator.
- Haptic: heavy impact on enter, medium on share-tap.

**Patterns to follow:**
- Existing full-screen routes (`/log`, `/tournaments/:id`) for non-shell navigation pattern.
- `lib/features/tournaments/presentation/widgets/phase_banner.dart` — hero-pill + content composition.

**Test scenarios:**
- Save path: when `saveOutcomeFor` returns `isCelebratory=true`, the screen pumps and finds the headline + Share card CTA.
- Save path: when `saveOutcomeFor` returns empty, the screen is not pushed; existing snackbar+pop fires.
- Multiple outcomes render as a PageView; dots count matches PR+badge total.
- "Done" button pops to `/home` (not back to the log form).

**Verification:**
- `flutter test test/features/storytelling/celebration_screen_test.dart` green. Manual smoke: log a catch big enough to be a first-ever PR; celebration appears.

---

- U4. **Badge wall on Me tab**

**Goal:** Show all seeded badges as a grid on the Me tab — earned in color, unearned as greyed silhouettes — each tappable to a description sheet.

**Requirements:** R5, R10.

**Dependencies:** U2.

**Files:**
- Modify: `lib/features/me/presentation/me_screen.dart`
- Create: `lib/features/storytelling/presentation/widgets/badge_wall.dart`
- Create: `lib/features/storytelling/presentation/widgets/badge_tile.dart`
- Create: `lib/features/storytelling/presentation/widgets/badge_description_sheet.dart`
- Test: `test/features/storytelling/badge_wall_test.dart`

**Approach:**
- Combine `allBadges()` and `myUserBadges()` providers; map each definition to "earned: bool" + "earnedAt" if present.
- 3-column `GridView` of `BadgeTile`s. Earned: filled icon in navy, title below. Unearned: same icon at low alpha, title also faded.
- Tap a tile → modal bottom sheet with title + description + earned-on date or "Locked — {hint copy}".
- Loading: shimmer / skeleton placeholder.
- Empty (no badges seeded — should never happen post-U1): friendly message, no crash.

**Patterns to follow:**
- Existing Me screen layout.
- M2 friends list grid for spacing density.

**Test scenarios:**
- 5 seeded badges + 0 earned: 5 tiles, all greyed.
- 5 seeded badges + 2 earned: 5 tiles, 2 colored.
- Tapping a tile opens the description sheet.
- Locked tile description shows the hint copy ("Catch a fish before 7am" for sunrise_warrior).

**Verification:**
- `flutter test test/features/storytelling/badge_wall_test.dart` green.

---

- U5. **Streaks — current + longest, derived**

**Goal:** Compute a current fishing-day streak and the user's longest streak from `myCatchesProvider` and surface them on the Me tab.

**Requirements:** R6, R10.

**Dependencies:** None (independent of storytelling DB tables).

**Files:**
- Create: `lib/features/storytelling/application/streak_provider.dart`
- Create: `lib/features/storytelling/presentation/widgets/streak_chip.dart`
- Modify: `lib/features/me/presentation/me_screen.dart`
- Test: `test/features/storytelling/streak_provider_test.dart`

**Approach:**
- `Streak` value: `{ current: int, longest: int }`.
- `streakProvider` watches `myCatchesProvider`. Pure-Dart computation:
  1. Map each catch's `caughtAt.toLocal()` to its date (`DateTime(year, month, day)`).
  2. Deduplicate to a sorted set of fishing-day dates.
  3. `current` = consecutive days back from `today.local` (or `today - 1` if no catch today — soft reset per origin doc "soft, resets gracefully"); 0 if last fishing day is older than yesterday.
  4. `longest` = max run of consecutive days in the set.
- `StreakChip` shows current as a navy pill, longest as a small grey caption underneath ("longest 12d").

**Patterns to follow:**
- `statsTimeOfDayProvider` shape — `Provider<AsyncValue<...>>` against `myCatchesProvider`.

**Test scenarios:**
- Empty catches → `Streak(current: 0, longest: 0)`.
- One catch today → `current: 1, longest: 1`.
- 3 distinct fishing days back-to-back ending today → `current: 3, longest: 3`.
- Same as above but the most-recent fishing day is 2 days ago → `current: 0, longest: 3` (gap of >1 day breaks current; soft).
- Two non-overlapping streaks of 4 and 7 → `longest: 7`, `current` follows whichever ends today.
- Local-day boundary: catch at 11pm and another at 1am next day count as 2 distinct fishing days (uses `.toLocal()` date).

**Verification:**
- `flutter test test/features/storytelling/streak_provider_test.dart` green.

---

- U6. **Catch comparison context line on detail screen**

**Goal:** Show a one-line context like "3rd biggest largemouth this year" or "biggest catch on Lake Mendota" beneath the catch headline.

**Requirements:** R7, R10.

**Dependencies:** None server-side; reads from existing `myCatchesProvider` for the comparison.

**Files:**
- Create: `lib/features/storytelling/application/catch_comparison_provider.dart`
- Create: `lib/features/storytelling/presentation/widgets/catch_comparison_line.dart`
- Modify: `lib/features/catches/presentation/catch_detail_screen.dart`
- Test: `test/features/storytelling/catch_comparison_test.dart`

**Approach:**
- Provider keyed on `catchId`. Watches `myCatchesProvider`. Filters to same species + same year, sorted by `weightKg` desc with null-last. Returns a small value `{ rank: int?, total: int, isAllTime: bool }` where `rank` is 1-based position; `null` when this catch has no measurable weight (then we try length).
- Widget renders nothing when `rank == null` or `rank > 3`. When `rank in [1,2,3]`: "{ordinal} biggest {species} this year". When `isAllTime` and `rank == 1`: "biggest {species} ever".
- Inserted between the headline and the measurement row in the detail screen.

**Patterns to follow:**
- Existing detail screen `_Headline` / `_MeasurementRow` composition.

**Test scenarios:**
- Single largemouth catch → rank 1, "biggest largemouth this year" rendered.
- Three largemouth catches in same year, this is the 2nd biggest → "2nd biggest largemouth this year".
- This catch ranks 5th of 5 → widget returns nothing (no clutter for low ranks).
- This catch has null weight + null length → widget returns nothing.
- Catch is from a different year → only catches in this catch's year are compared.

**Verification:**
- `flutter test test/features/storytelling/catch_comparison_test.dart` green.

---

- U7. **Share card composition + PNG export + system share sheet**

**Goal:** From the catch detail screen, an action exports a branded share card as PNG and hands it to the system share sheet.

**Requirements:** R8, R10.

**Dependencies:** U6 (the share card includes the comparison line when present).

**Files:**
- Modify: `pubspec.yaml` (add `share_plus: ^10.0.0`)
- Create: `lib/features/storytelling/presentation/widgets/share_card.dart`
- Create: `lib/features/storytelling/application/share_card_export.dart` (RepaintBoundary capture + temp-file write + `share_plus` invocation)
- Modify: `lib/features/catches/presentation/catch_detail_screen.dart` (add the SliverAppBar action)
- Test: `test/features/storytelling/share_card_test.dart`

**Approach:**
- `ShareCard` widget renders at fixed 1080×1920 via `MediaQuery` override and `FittedBox`. Layout: photo top 60%, navy footer with species pill, weight + length pills, location label (or "Secret spot"), small "Fishing with Friends" wordmark bottom.
- Export flow: build the card off-screen via an `Overlay` or a transient route, wrap in `RepaintBoundary` with a `GlobalKey`, await one frame, call `boundary.toImage(pixelRatio: 1.0)`, encode PNG, write to `path_provider` temp dir, call `Share.shareXFiles([XFile(path)])`.
- Loading state on the share button while capturing (~200–500ms typical).
- Privacy: secret-spot catches show "Secret spot" instead of coordinates; never leak GPS in the image.

**Patterns to follow:**
- Existing detail screen's `actions:` slot in `SliverAppBar`.
- Tournament submit-action pattern for "build a sheet, do work, snackbar on result."

**Test scenarios:**
- Widget builds the card with all fields (species, weight, length, location label).
- Secret-spot catch: card shows "Secret spot", not lat/lng.
- Catch with no GPS: card shows "Location not set", no error.
- Capture flow returns a non-null PNG bytes blob in a widget test (skip the actual `share_plus` IPC; assert the bytes were produced).
- Catch missing weight + length: card still renders without error, pills omitted.

**Verification:**
- `flutter test test/features/storytelling/share_card_test.dart` green. Manual smoke on a real device: tap share, share sheet appears with image preview.

---

- U8. **Year-in-Review screen — paged animated cards**

**Goal:** A `/year-in-review` route that shows a swipeable PageView of static animated cards summarizing the user's year: top catches, biggest, most-caught species, days fished, biggest trip, friend leaderboard.

**Requirements:** R9, R10.

**Dependencies:** None server-side. Reads `myCatchesProvider`, `friendsCatchesProvider`, `tripsProvider` (existing from M2).

**Files:**
- Create: `lib/features/storytelling/application/year_in_review_provider.dart`
- Create: `lib/features/storytelling/presentation/year_in_review_screen.dart`
- Create: `lib/features/storytelling/presentation/widgets/yir_card.dart` (base)
- Create: `lib/features/storytelling/presentation/widgets/yir_top_catches_card.dart`
- Create: `lib/features/storytelling/presentation/widgets/yir_biggest_card.dart`
- Create: `lib/features/storytelling/presentation/widgets/yir_species_card.dart`
- Create: `lib/features/storytelling/presentation/widgets/yir_days_card.dart`
- Create: `lib/features/storytelling/presentation/widgets/yir_friend_leaderboard_card.dart`
- Modify: `lib/core/router/app_router.dart` (add `/year-in-review` route)
- Modify: `lib/features/me/presentation/me_screen.dart` (add Year-in-Review entry button)
- Test: `test/features/storytelling/year_in_review_test.dart`

**Approach:**
- `yearInReviewProvider` returns a `YearInReviewSummary` value composed of: top 5 catches by weight in current calendar year; biggest single catch; species count + most-caught species; days-fished count; biggest trip (by total weight); friend leaderboard (top 3 friends by catch count this year).
- Year window: rolling "last 365 days" per origin doc open-question hint ("rolling … available any time"). Better in v1 — works mid-year.
- Each `Yir*Card` is a full-screen card with a hero element + supporting copy. Enter animation: simple fade + slide-up via `AnimatedSwitcher` or `TweenAnimationBuilder`.
- PageView with a dots indicator at top.
- Empty case: when no catches in window, single card "Log a catch this year to unlock your review."
- The whole screen is screenshot-friendly — no transient UI on top.

**Patterns to follow:**
- Existing `tournament_detail_screen.dart` for a multi-section provider-driven page.
- Onboarding-style flow patterns are an analogue but unused here so far.

**Test scenarios:**
- Provider with 5 catches → returns the top 5 sorted by weight desc; biggest = top 1; species count = distinct species.
- Provider with 0 catches in window → returns an empty-marker summary; screen renders the empty card.
- Days fished counts distinct local-days from `caughtAt.toLocal()`.
- Friend leaderboard with 0 friends returns empty; card renders graceful empty state.
- Page navigation: 6 cards present in default state; dots indicator updates on swipe.

**Verification:**
- `flutter test test/features/storytelling/year_in_review_test.dart` green.

---

- U9. **Documentation pass + storytelling learning entry**

**Goal:** Update parent docs and capture the server-side-trigger decision so future contributors don't try to reach for a client-side detection rewrite.

**Requirements:** R10.

**Dependencies:** U1–U8.

**Files:**
- Modify: `docs/SUPABASE_SETUP.md` (add 0009 to runlist with a one-line note)
- Modify: `README.md` (Feature status table — flip M5 entries to ✅)
- Create: `docs/solutions/2026-05-01-storytelling-server-detection.md`

**Approach:**
- Learning entry documents: why server-side trigger over client logic (offline-safety in M6); why declarative seeded badges over a runtime DSL (low-churn, five badges fits in SQL); the predicate enum + params pattern; "When to revisit" guidance.
- README: "PRs / badges / streaks / share cards / Year-in-Review" row → ✅ M5.

**Test scenarios:**
- N/A — pure docs.

**Verification:**
- `flutter analyze` clean. `flutter test` green.

---

## System-Wide Impact

- **Interaction graph:** new providers join `myCatchesProvider` and `friendsCatchesProvider` for derived stories; the catch save path adds a `saveOutcomeFor` read after insert. None of the existing M0–M4 paths change shape — they grow new consumers, not new state.
- **Error propagation:** new providers surface as `AsyncValue` with the existing snackbar/empty-state patterns. The save flow's celebration route gracefully degrades to the existing snackbar+pop on `saveOutcomeFor` error — the celebration is best-effort.
- **State lifecycle risks:** the celebration screen is a root-level route, not a shell child — popping it lands on the home tab. Verified via the U3 test scenarios.
- **API surface parity:** `catches` table unchanged. Three new tables, none referenced by existing M0–M4 reads. RLS preserved.
- **Integration coverage:** `test_integration/friends_only_rls_test.dart` should be extended in U1 to assert that user B cannot read user A's `personal_records` or `user_badges` rows. M5 owns this extension.
- **Unchanged invariants:** all 0001 + 0007 RLS policies remain authoritative.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Server-side trigger silently fails to evaluate a predicate (e.g., enum mismatch). | Trigger function returns `null` on unknown predicate names rather than raising; missing predicates produce no badges, never crash a catch insert. Smoke-test all 5 seeded badges in U1's verification. |
| Share card rendering produces blank PNG on Android due to `RepaintBoundary` race. | Standard `await Future.delayed(Duration(milliseconds: 100))` after frame-render, or use `WidgetsBinding.instance.endOfFrame`. Documented in `share_card_export.dart`. |
| `share_plus` API drift between v9 and v10. | Pin to `^10.0.0` and the latest minor. Surface used (`Share.shareXFiles`) is stable. |
| Year-in-Review screen perf on low-end Android — 6 cards each with photo loads. | Use `cached_network_image` which is already in `pubspec.yaml` from M1. Lazy-load offscreen pages in the PageView. |
| Streak provider drifts because user device time is wrong. | Document: streaks use device `.toLocal()`. Server-time isn't used because that would create timezone-mismatch confusion ("I fished today but it shows tomorrow's date"). |
| Trigger evaluation slows down catch inserts. | Trigger work is O(1) for PR (single upsert per metric) + O(B) for badges where B = badge count (5 in v1). Even at 100 badges in v3, trigger time stays under typical insert latency. |
| New PR achieved via update of an existing catch (not insert). | Trigger fires on `INSERT OR UPDATE`. Documented in U1 verification. |

---

## Phased Delivery Within M5

Suggested merge order on `feat/m5-storytelling`:

1. **U1** (schema 0009) — must be first. Includes the trigger contract every later unit depends on.
2. **U2** (data layer) — depends on U1.
3. **U3** (celebration screen + save hook) — depends on U2.
4. **U5** (streaks) — independent of U1–U4; can run in parallel.
5. **U4** (badge wall) — depends on U2.
6. **U6** (catch comparison) — independent; can run anywhere after U2.
7. **U7** (share card) — depends on U6 (uses comparison line in card).
8. **U8** (Year-in-Review) — independent of U1–U7 except for the Me-tab integration; lands toward the end so the tab settles once.
9. **U9** (docs) — last.

**Stop scope at M5.** M6 plan launches separately when M5 ships.

---

## Documentation / Operational Notes

- After M5 lands, `docs/SUPABASE_SETUP.md` runlist gains 0009 with: "storytelling schema — `personal_records`, `badges`, `user_badges`, RLS, AFTER-INSERT trigger on `catches` for PR + badge detection. **Required** — without it the celebration screen never fires."
- `README.md` "Feature status": M5 row flips to ✅.
- New learning entry at `docs/solutions/2026-05-01-storytelling-server-detection.md` covering server-side trigger vs client logic, predicate-enum vs DSL, "when to revisit."

---

## Sources & References

- **Origin document:** `docs/brainstorms/fishing-with-friends-v1-requirements.md` (Section C — Storytelling layer)
- **Parent plan:** `docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md`
- **Predecessor plans:** M1–M4 plans in `docs/plans/`.
- **Schema baseline:** `supabase/migrations/0001_init.sql` through `supabase/migrations/0008_auto_profile_on_signup.sql`.
- **External:** `share_plus` (`^10.0.0`), Flutter `RepaintBoundary` capture pattern, Spotify Wrapped / Apple Music Replay as visual references for Year-in-Review.
