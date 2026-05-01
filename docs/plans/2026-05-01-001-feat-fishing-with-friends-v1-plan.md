---
title: "feat: Fishing with Friends v1 launch"
type: feat
status: active
date: 2026-05-01
origin: docs/brainstorms/fishing-with-friends-v1-requirements.md
---

# feat: Fishing with Friends v1 launch

## Summary

Plan the Flutter + Supabase build of Fishing with Friends v1: a friends-only social angling app whose wedge is a beautiful logbook + live tournaments shipped together. This top-level plan details **Milestone M0** (visual system overhaul, 8-tab bottom nav, schema foundation) end-to-end, and sketches the remaining seven milestones (M1–M7) as phased delivery so the order of work is committed without speculatively planning units that depend on code that doesn't exist yet. Each later milestone earns its own focused plan when its predecessor lands.

---

## Problem Frame

The current Flutter scaffold compiles and authenticates against Supabase, but it does not look or feel like the product the screenshots in `Assests/` and the requirements doc describe: blue-gradient chrome instead of navy + off-white, four tabs instead of eight, no Stats / Map / Friends / Me surfaces, dummy "secret spot" toggle without `Catch & Release`, unit storage that conflates display and persistence. Every later milestone (real catches, trips, tournaments, social, map, stats, share cards, offline) lands on top of these foundations, so getting M0 right is the unblock for everything else (see origin: `docs/brainstorms/fishing-with-friends-v1-requirements.md`).

---

## Requirements

- R1. App's visual identity matches the Lovable references — navy primary, warm-orange accent, off-white surface, white rounded cards, no gradient chrome.
- R2. Bottom navigation exposes 8 destinations (Home / Catches / Log / Stats / Tourneys / Map / Friends / Me) with the Log tab carrying the catch-creation entry point.
- R3. Catch logging supports both Secret Spot (privacy) and Catch & Release (ethics) as independent toggles.
- R4. Length / weight inputs offer per-field unit toggles (in / cm and lb / kg) while persistence stores canonical metric.
- R5. Species table distinguishes freshwater / saltwater / both, and is seeded with a v1-launch list covering both water types.
- R6. App still passes `flutter analyze` with zero issues and `flutter test` green after every M0 unit lands.
- R7. (Carried from origin) Friends-only RLS visibility holds — no schema or UI change in M0 may regress the policies in `supabase/migrations/0001_init.sql`.

**Origin actors:** A1 Recreational angler, A2 Tournament participant, A3 Tournament creator, A4 Admin (species curation).

---

## Scope Boundaries

### Deferred for later

*(Carried verbatim from origin — product/version sequencing.)*

- Photo species ID / on-device ML, voice-note transcription, tournament brackets / divisions (v1.5).
- Community water reports, public spots, web release target, admin dashboard (v2).
- AI lure / depth / time suggestions, Apple Watch / Wear OS, Reels-style feed (v3).

### Outside this product's identity

*(Carried verbatim from origin — positioning rejection.)*

- Public network / public catch feed (this is not Fishbrain).
- Marketplace or in-app gear sales.
- Fishing-license tracking or regulation enforcement (legal liability surface).
- Prize disbursement or payments inside tournaments (regulated).

### Deferred to Follow-Up Work

*Plan-local — implementation work intentionally split across other milestone plans.*

- All of M1 (catch persistence) through M7 (store submission). Each milestone receives its own `/ce-plan` when its predecessor lands. Phased Delivery below sketches their order and intent so this plan is anchored, but the implementation-unit detail is deferred.
- Replacing the running `flutter run -d chrome` web build is not part of M0 — keep web available as a development convenience only, never as a release surface.

---

## Context & Research

### Relevant Code and Patterns

- `lib/core/theme/app_colors.dart` — current palette (lake / sky / sunrise) needs replacing.
- `lib/core/theme/app_theme.dart` — Material 3 builder; safe to keep architecture, swap tokens.
- `lib/core/theme/app_gradients.dart` — gradient helpers used by sign-in + catch-log; will lose most callers in M0.
- `lib/core/router/app_router.dart` — `GoRouter` with `ShellRoute`; 4 tabs + `logCatch` as a non-tab route. Needs to become 8 tabs with Log as a tab.
- `lib/core/router/app_shell.dart` — `NavigationBar` + center-docked `FloatingActionButton`. Needs to become a flat 8-tab `NavigationBar` (Log is a tab, not a FAB) per Lovable screenshots.
- `lib/features/auth/presentation/sign_in_screen.dart` — gradient background to remove.
- `lib/features/catches/presentation/catch_log_screen.dart` — already media-first; needs unit toggles, dual privacy toggles, conditions/rig fields scaffolded for M1.
- `supabase/migrations/0001_init.sql` — `catches.weight_lb` / `catches.length_in` to be migrated to canonical metric in M0; `species` table to be enriched with `water_type` and seeded.

### Institutional Learnings

- `docs/solutions/` does not yet exist for this repo. M0 ends with a learnings entry capturing any non-obvious decisions (units canonicalization, 8-tab nav rationale).

### External References

- Material 3 NavigationBar — Flutter docs note 3–5 destinations is the recommended max; we are intentionally exceeding that to match Lovable parity. Mitigation: compact icon-only labels at small breakpoints + a thorough widget-test pass to catch overflow.
- Open-Meteo + NOAA Tides — free, no-key APIs chosen for M6 (deferred); flagged here so M0 schema for `catches` is forward-compatible (`conditions` JSONB column added).

---

## Key Technical Decisions

- **8 tabs, no FAB.** Lovable's nav is 8 equally-weighted destinations including a `+ Log` tab. Implementing as a regular tab (not a FAB) matches the screenshot and is simpler to maintain. Risk: NavigationBar rendering at small widths — addressed by compact labels and a widget test.
- **Persist measurements in canonical metric** (`weight_kg` numeric, `length_cm` numeric). Display converts per user preference. Avoids dual-write bugs and unit drift the moment we have multiple clients (mobile, future web). One-time migration acceptable because no real catch rows exist yet.
- **Both Secret Spot and Catch & Release** — origin spec had only Secret Spot; Lovable had only C&R. They model different concerns (privacy vs ethics) and both belong (see origin: Key Decisions / Privacy).
- **Species table gets `water_type` enum** (`freshwater`, `saltwater`, `both`) and a seed migration. Saltwater catches require species-aware tide UX downstream (M4), so this metadata is foundational.
- **Theme = palette swap, not architecture rebuild.** Keep `AppTheme.light()` / `dark()` builder shape; only the tokens and a few component overrides change. Gradients survive only as an optional accent on celebratory PR / share-card moments (M5).
- **Plan structure: M0-detailed, M1–M7 phased.** Trying to enumerate units across all of v1 today produces speculative units against code that does not exist. Each later milestone gets its own `/ce-plan` when M0 ships.

---

## Open Questions

### Resolved During Planning

- *8 tabs vs collapsed nav:* keep all 8 to match Lovable; ship compact labels and rely on widget tests at small breakpoints to catch overflow.
- *Per-input vs global units:* per-input toggle (matches Lovable) for UX, but **persistence is canonical metric** to keep the data model clean.
- *FAB vs tab for Log:* tab. Center-docked FAB created an awkward gap and changes the source of truth for Lovable parity.
- *Migrate vs dual-write the unit columns:* migrate cleanly. Zero production data, zero compatibility cost.

### Deferred to Implementation

- *App icon / launch screen art:* M7 polish. M0 keeps the Flutter default.
- *Exact navy hex / orange hex* — sampled from screenshots (`#102B47` / `#F08948`), but final tokens may shift after a designer pass; tokens are isolated so the change cost is one file.
- *Whether Log tab uses a slightly larger icon for emphasis* — confirmed visually after the first run; isolate behind `AppSpacing.iconLg` so adjustment is a one-line change.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
M0 surface graph
─────────────────────────────────────────────────────────────────

  Sign-In ──┐
            ▼
        AppShell  (8-tab NavigationBar, no FAB)
            │
   ┌────────┼────────┬────────┬─────────┬──────┬─────────┬─────┐
   ▼        ▼        ▼        ▼         ▼      ▼         ▼     ▼
  Home    Catches   Log     Stats    Tourneys  Map     Friends  Me
   │        │        │        │         │      │         │      │
   │        │        ▼        │         │      │         │      │
   │        │   CatchLogScreen│         │      │         │      │
   │        │   (media-first, │         │      │         │      │
   │        │    Secret Spot  │         │      │         │      │
   │        │    + C&R, unit  │         │      │         │      │
   │        │    toggles)     │         │      │         │      │
   │        │                 │         │      │         │      │
   ▼        ▼                 ▼         ▼      ▼         ▼      ▼
  stat    catches grid     species    pie+bar  trny    pin    profile
  tiles   (placeholder)    breakdown  charts   list    map    + signout
        │                  (mock)     (mock)  (Lovable
        │                                      shape)
        ▼
   recent catches list
   (placeholder until M1)

  All screens render off-white surface, navy primary, orange accent.
  No gradients on chrome.

────────────────────────────────────────────────────────────────
Schema delta (M0):
  catches.weight_lb  -> weight_kg
  catches.length_in  -> length_cm
  catches.conditions JSONB         (forward-compat for M6 weather/tide)
  species.water_type ENUM(freshwater, saltwater, both)
  species seed: ~30 common species
```

---

## Implementation Units

- U1. **Replace visual tokens with the navy + orange system**

**Goal:** Swap palette, gradients, and theme overrides so every existing screen renders against navy primary, orange accent, and off-white surface.

**Requirements:** R1, R6.

**Dependencies:** None.

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_gradients.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/widget_test.dart` (extend existing token test)

**Approach:**
- Replace lake / sky / sunrise tokens with `navy = #102B47`, `orange = #F08948`, `paper = #F5F7FA`, `mist = #E2E8F0`, `card = #FFFFFF`. Keep semantic accessors (`primary`, `secondary`, `surface`, `error`).
- Reduce `AppGradients` to one `celebration` gradient reserved for PR / share-card moments later. Remove `water` / `dawn` / `surface` exports since their callers are about to lose them.
- In `AppTheme._build`: cards become flat with soft single shadow on white; `inputDecorationTheme` fill becomes `paper`; `appBarTheme` background becomes `paper`; `navigationBarTheme.indicatorColor` keeps navy with low alpha.
- Keep dark theme — invert surfaces to `ink` and adjust accent legibility.

**Patterns to follow:**
- `AppTheme._build` composition pattern; don't introduce new theme architectures.

**Test scenarios:**
- Happy path: `AppColors.navy.toARGB32()` and `AppColors.orange.toARGB32()` return the expected ARGB values.
- Happy path: `AppTheme.light().colorScheme.primary == AppColors.navy`; `secondary == AppColors.orange`; `surface == AppColors.paper`.
- Edge case: `AppTheme.dark()` builds without throwing and produces a `ColorScheme` whose `primary` differs from `surface` (legibility guard).

**Verification:**
- `flutter analyze` clean. Existing tests green. Theme tokens show new values in any built widget.

---

- U2. **Reshape navigation to 8 tabs with Log as a tab**

**Goal:** Replace the 5-destination shell + center FAB with a flat 8-destination `NavigationBar` matching Lovable. Add empty placeholder screens for Stats, Map, Me.

**Requirements:** R2, R6.

**Dependencies:** U1 (so the new nav renders against the new tokens).

**Files:**
- Modify: `lib/core/router/app_shell.dart`
- Modify: `lib/core/router/app_router.dart`
- Create: `lib/features/home/presentation/home_screen.dart` (move existing `feed_screen.dart` content here under a new name)
- Create: `lib/features/stats/presentation/stats_screen.dart`
- Create: `lib/features/map/presentation/map_screen.dart`
- Create: `lib/features/me/presentation/me_screen.dart` (rename of `profile_screen.dart` for Lovable parity)
- Delete (or keep as alias re-export): `lib/features/social/presentation/feed_screen.dart`, `lib/features/profile/presentation/profile_screen.dart`
- Test: `test/router/app_shell_test.dart`

**Approach:**
- 8 destinations in order: Home / Catches / Log / Stats / Tourneys / Map / Friends / Me.
- `Log` is a `NavigationDestination` whose `onDestinationSelected` pushes `/log` (no shell child for Log; the catch-log screen takes over the screen).
- Drop `floatingActionButton` from `Scaffold`; haptic on tab change stays.
- Update `AppRoutes` constants (`home`, `catches`, `logCatch`, `stats`, `tourneys`, `map`, `friends`, `me`) and `initialLocation` to `/home`.
- Compact labels at small widths via `NavigationBarThemeData.labelTextStyle` resolver — already in theme.

**Patterns to follow:**
- The existing `AppShell` `_NavTab` pattern; expand the list and re-use.

**Test scenarios:**
- Happy path: `AppShell` renders exactly 8 `NavigationDestination`s in the documented order.
- Happy path: tapping the `Log` destination triggers navigation to `/log` (assert via a router-aware test, e.g., a fake `GoRouter` or `pumpWidget` with a real `GoRouter`).
- Happy path: deep-linking to `/stats` lands on the Stats placeholder with the Stats tab selected.
- Edge case: at 320pt width, the `NavigationBar` does not overflow (golden / `tester.pumpWidget` with `MediaQuery.size` constrained).

**Verification:**
- `flutter analyze` clean. Manual smoke: every tab renders its placeholder. Sign-in → Home → tap each tab → no crashes.

---

- U3. **Build the Home tab layout (stat tiles + recent catches placeholder)**

**Goal:** Match the Lovable Home screen — top action chips ("Log a Catch", "View Catches"), 2×2 stat tiles (Total Catches, Total Weight, Species, Biggest), Recent Catches list. Stats and list show empty/mock data until M1 binds real catches.

**Requirements:** R1, R2, R6.

**Dependencies:** U1, U2.

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Create: `lib/features/home/presentation/widgets/stat_tile.dart`
- Create: `lib/features/home/presentation/widgets/action_chips.dart`
- Test: `test/features/home/home_screen_test.dart`

**Approach:**
- `StatTile` is a card with icon-pill + label + bold value. Reusable in M5 for PR pages.
- Empty state: when there are no catches, the Recent Catches section shows a friendly empty-state card with a "Log your first catch" CTA that navigates to `/log`.
- No data binding yet — accept zeroed `HomeMetrics` value object as input. M1 will swap in a Riverpod provider.

**Patterns to follow:**
- Existing `feed_screen.dart` placeholder card pattern, but cards become photo-first hero cards in M2 once feed data lands.

**Test scenarios:**
- Happy path: `HomeScreen(metrics: HomeMetrics.empty())` renders 4 stat tiles with `0` values and an empty-state CTA.
- Happy path: `HomeScreen(metrics: HomeMetrics(totalCatches: 1, totalWeightKg: 226.8, species: 1, biggest: ...))` renders the values formatted in user units (verify `500.0 lbs` and `1` shown when user pref = imperial).
- Happy path: tapping the empty-state CTA pushes `/log`.

**Verification:**
- Pixel-comparable to `Assests/Main Photo 1.jpg` (Recent Catches card image is mock — that's expected).

---

- U4. **Catch Log visual rebuild + dual privacy toggles + unit toggles**

**Goal:** Match the Lovable Log Catch form: dashed photo upload area, species dropdown, weight + lbs/kg toggle, length + in/cm toggle, date + time pickers, location field with GPS + Map buttons, "Additional Details" collapsible (notes / rig / conditions placeholder), Catch & Release toggle, Secret Spot toggle, large orange Save button. Persistence is still M1.

**Requirements:** R1, R3, R4, R6.

**Dependencies:** U1.

**Files:**
- Modify: `lib/features/catches/presentation/catch_log_screen.dart`
- Create: `lib/features/catches/presentation/widgets/photo_drop_target.dart`
- Create: `lib/features/catches/presentation/widgets/unit_toggle_field.dart`
- Create: `lib/features/catches/presentation/widgets/additional_details_section.dart`
- Create: `lib/core/units/units.dart`
- Test: `test/features/catches/catch_log_screen_test.dart`
- Test: `test/core/units/units_test.dart`

**Approach:**
- `Units` provides pure conversions (`lbToKg`, `kgToLb`, `inToCm`, `cmToIn`) and a `MeasurementSystem { metric, imperial }` enum. No persistence; UI controllers hold both displayed and metric values.
- `PhotoDropTarget` renders dashed border + camera icon when empty; carousel of thumbnails (max 5) when populated.
- `UnitToggleField` exposes `<TextField, lb|kg toggle>` or `<TextField, in|cm toggle>` with deterministic conversion when the toggle flips.
- `AdditionalDetailsSection` is a collapsible `ExpansionTile` containing notes (text) + rig/lure (chip + freeform). Conditions block is a sub-stub for M6.
- Two toggle rows at the bottom: `Catch & Release` and `Secret Spot`, each with its own subtitle copy and icon.
- Save button is full-width orange; haptic on tap (medium impact then heavy on success). Persistence still routes through the existing `// TODO(catches)` stub.

**Patterns to follow:**
- Existing `catch_log_screen` form pattern; expand within the same `Form` + `_save` shape.

**Test scenarios:**
- Happy path: form renders all required regions (photo target, species, weight + unit, length + unit, date, time, location, additional details, C&R toggle, Secret Spot toggle, Save button).
- Happy path: typing `1.5` with unit `kg` then flipping to `lb` displays `~3.3`.
- Happy path: toggling `Secret Spot` ON does not error; the value is captured into the form's outgoing payload.
- Error path: tapping Save without species shows validation error; tapping Save without a photo shows the existing snackbar.
- Edge case: pasting non-numeric into weight field is filtered by the existing input formatter.

**Verification:**
- Pixel-comparable to `Assests/Screenshot 2026-05-01 134126.jpg`. Both toggles independently controllable.

---

- U5. **Sign-In visual rebuild**

**Goal:** Replace the gradient hero treatment with the off-white + navy logo + centered card aesthetic so first impression matches Lovable.

**Requirements:** R1.

**Dependencies:** U1.

**Files:**
- Modify: `lib/features/auth/presentation/sign_in_screen.dart`

**Approach:**
- Wrap content in a plain `Scaffold` with `paper` background — drop the `AppGradients.water` decoration.
- Replace the white card with a transparent, edge-padded `Column`. Keep the icon + title + email/password + submit button.
- Primary button is navy filled; secondary action is text-style.

**Patterns to follow:**
- Existing form structure and validators.

**Test scenarios:**
- Test expectation: smoke widget test that screen builds without throwing under both light and dark themes (no logic changed, only chrome).

**Verification:**
- Visually compares cleanly to a typical SaaS-style sign-in card on light background.

---

- U6. **Schema: canonical metric measurements + species water type + seed**

**Goal:** Migrate `catches` to canonical metric, add `species.water_type`, and seed a v1-launch list of freshwater + saltwater species so M2/M3 surfaces have real data to render.

**Requirements:** R4, R5, R7.

**Dependencies:** None — runs in Supabase, parallel to the Flutter units above.

**Files:**
- Create: `supabase/migrations/0003_units_and_species.sql`

**Approach:**
- Add `species.water_type` column with enum `species_water_type ('freshwater', 'saltwater', 'both')`, default `freshwater`.
- Add `species.regions text[]` for future regional filtering (e.g., `{us-east-coast, gulf}` for saltwater).
- Rename `catches.weight_lb` → `weight_kg` and `catches.length_in` → `length_cm`. No data conversion needed (zero rows). Update CHECK constraints.
- Add `catches.conditions jsonb default '{}'::jsonb` for the M6 weather/tide cache (forward-compatible; no consumer in M0).
- Recreate `public.catches_friend_view` because column names change.
- Seed `species` table with ~30 entries split across water types: Largemouth Bass, Smallmouth Bass, Striped Bass, Rainbow Trout, Brown Trout, Brook Trout, Lake Trout, Walleye, Pike, Muskie, Bluegill, Crappie, Yellow Perch, Catfish (channel + flathead), Carp (freshwater); Snook, Redfish (Red Drum), Speckled Sea Trout, Striped Bass (saltwater entry), Tarpon, Permit, Bonefish, Snapper (mangrove + red), Grouper, Mahi-Mahi, Cobia, Spanish Mackerel, Bluefish, Flounder (saltwater).
- Indexes: `species_water_type_idx`, `species_common_name_idx (lower(common_name))`.

**Patterns to follow:**
- Same migration + RLS shape as `0001_init.sql` and `0002_storage_policies.sql`. Wrap in transaction.

**Test scenarios:**
- Happy path: migration applies cleanly against a fresh Supabase project after `0001` and `0002`.
- Happy path: `select count(*) from species where water_type = 'freshwater'` returns 15+; saltwater returns 14+.
- Happy path: `select water_type from species where common_name = 'Striped Bass'` returns either `both` or two rows distinguished by region (decide in migration; document choice in comment).
- Edge case: `insert into catches (..., weight_kg, length_cm, ...)` succeeds; the same call with `weight_lb` fails with column-not-found.
- RLS guard: after the migration, all existing policies in `0001_init.sql` still hold — re-run a read attempt as a non-friend angler against another user's catch and confirm zero rows.

**Verification:**
- Migration `Run` returns success in Supabase SQL Editor.
- Sample `select common_name, water_type from species order by water_type, common_name` returns the seeded list.
- Existing app still authenticates; no client code references `weight_lb` / `length_in` after U4 lands.

---

## System-Wide Impact

- **Interaction graph:** every Flutter screen depends on `AppTheme` and `AppColors`; a single token change ripples everywhere. Mitigated by U1 going first and the rest of M0 hot-reloading on top of it.
- **Error propagation:** unchanged — Supabase errors continue to surface as `AuthException`s and generic `Exception`s in the form layer.
- **State lifecycle risks:** none in M0. Riverpod tree shape unchanged.
- **API surface parity:** the schema rename from `weight_lb / length_in` to `weight_kg / length_cm` invalidates `catches_friend_view`; U6 recreates it. No client code references those columns yet (the catch-log screen has only a `// TODO(catches)` insert), so there's nothing to refactor.
- **Integration coverage:** M0 ends with no real catch persistence, so the integration story remains "auth + RLS + read placeholders." M1 owns the first end-to-end happy path test.
- **Unchanged invariants:** `0001_init.sql` RLS policies must still hold after `0003_units_and_species.sql` runs. The friend-only catch-read policy depends on column names but not on `weight_lb` / `length_in`, so no policy edits are needed; U6's verification re-asserts this by reading another user's catches as an unconfirmed friend and expecting zero rows.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| 8-tab `NavigationBar` overflows on narrow phones (e.g., older iPhone SE at 320pt). | U2 includes a widget test at 320pt, compact labels enabled, and a fallback to icon-only at small widths if the test fails. |
| Theme rebuild breaks one of the existing screens because of an implicit dependency on a removed gradient. | U1 lands first; subsequent units rebuild affected screens within the same milestone. `flutter analyze` + `flutter test` after each unit catches missing references. |
| Migration `0003` runs on a live Supabase project that has a stray catch row in it (e.g., from a manual smoke test). | Pre-flight `select count(*) from catches` before applying; if non-zero, a one-off DML converts via `weight_lb * 0.453592` and `length_in * 2.54` inside the same transaction. |
| Web dev server (`flutter run -d chrome`) breaks when paths or routes change. | Hot reload absorbs most edits; route-level changes need a hot restart, which the dev server supports. Web is dev-only — not a release blocker. |
| Lovable color hexes sampled by eye are slightly off. | Tokens isolated to `AppColors`; one-line correction once a designer signs off. |

---

## Phased Delivery

M0 is detailed above. M1–M7 are sketched here in order; each gets its own focused `/ce-plan` when its predecessor lands. Implementation-unit detail is intentionally deferred — premature unit-level planning against code that doesn't exist yet is speculation.

### M1 — Real catch persistence (1–2 weeks)

End-to-end: photo upload to private storage bucket → `catches` insert → signed-URL retrieval → render in My Catches grid + detail view. First Riverpod data layer (`CatchesRepository` + provider). Friends-only read path validated in an integration test. Closes R7 with running RLS.

### M2 — Trips + Activity Feed + Friend graph completion (2 weeks)

`trips` + `trip_participants` schema. Trip-mode UX in Log flow. Friends search / add / accept (already RLS-ready). Friends-only feed reads from `catches` joined with `trips`, with reactions + comments tables. The first feature where friends-only-feed becomes user-visible.

### M3 — Live Tournaments end-to-end (2–3 weeks)

Tournament creation form (Lovable shape), invite/join code, member approval, catch submission with creator approval, **Supabase Realtime leaderboard**, side pots, tournament chat thread. Closes the v1 wedge alongside M2 storytelling.

### M4 — Catch Map + Stats deepening (1–2 weeks)

`flutter_map` integration with own + friend pins, heatmap toggle, Secret Spot suppression rule, MPA dataset (NOAA Marine Protected Areas Inventory), conditions overlay placeholder. Stats: time-of-day heatmap, conditions correlation chart, vs-friends comparison. Most of the "polish makes it feel like a product" lands here.

### M5 — Storytelling layer (2 weeks)

`personal_records`, `badges`, `user_badges`, streaks. PR full-screen takeover screen + share card (PNG export). Year-in-Review reel as static animated cards (video composition deferred to v1.5). Branded share cards as the only friends-only growth surface.

### M6 — Offline-first + conditions auto-fill + push (2–3 weeks; highest-risk milestone)

`drift` (SQLite) local store, sync queue for catches and entries, photo upload retry. Open-Meteo + NOAA Tides Supabase edge function populates `catches.conditions` on insert. APNs + FCM via `firebase_messaging`. The infrastructural milestone — sequenced after UI is stable so we don't refactor twice.

### M7 — Onboarding, polish, store submission (1–2 weeks)

Avatar/handle pick, "find friends" by username, dark-mode pass, dynamic-type pass, app icon + launch screen, App Store Connect metadata, Play Console listing, App Store + Play Store privacy disclosures consistent with friends-only model + GPS / camera / mic permissions.

---

## Documentation / Operational Notes

- After M0 lands, `docs/SUPABASE_SETUP.md` needs a one-line update: the third migration (`0003_units_and_species.sql`) joins the run-list. M0 owns this update as part of U6.
- `README.md` "Feature status" table should be refreshed when M0 ships — Visual system / 8-tab nav / metric persistence / species seed flip from "—" to "✅".
- Capture in a new `docs/solutions/2026-05-01-units-canonicalization.md` learning entry: why metric in DB + per-input UI toggles is preferable to a global preference + dual-write — useful to future contributors who'll be tempted to add a `preferred_units` column.

---

## Sources & References

- **Origin document:** `docs/brainstorms/fishing-with-friends-v1-requirements.md`
- **Visual references:** `Assests/Main Photo 1.jpg`, `Assests/Screenshot 2026-05-01 134101.jpg`, `Assests/Screenshot 2026-05-01 134126.jpg`, `Assests/Screenshot 2026-05-01 134148.jpg`, `Assests/Screenshot 2026-05-01 134202.jpg`, `Assests/Screenshot 2026-05-01 134224.jpg`, `Assests/Screenshot 2026-05-01 134240.jpg`
- **Spec PDF:** `Fishing_With_Friends_Enterprise_Dev_Sheet.pdf` (Bunshin Studios v1.0) — superseded by origin doc for v1 scope.
- Supabase migrations to extend: `supabase/migrations/0001_init.sql`, `supabase/migrations/0002_storage_policies.sql`.
- Flutter NavigationBar 3–5 destinations guidance — Material 3 docs (intentionally exceeded for Lovable parity, mitigated by widget test + compact labels).
