---
title: "feat: M4 — Catch Map + Stats deepening"
type: feat
status: active
date: 2026-05-01
origin: docs/brainstorms/fishing-with-friends-v1-requirements.md
parent_plan: docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md
---

# feat: M4 — Catch Map + Stats deepening

## Summary

Replace the M0 Catch Map placeholder with a real OpenStreetMap-backed `flutter_map` view that renders own pins + friend pins, supports a heatmap toggle, suppresses Secret Spot exposure, and is aware of Marine Protected Areas. Replace the M0 Stats placeholders with a time-of-day heatmap of own catches, a vs-friends activity comparison, and a conditions correlation card stubbed pending M6 conditions auto-fill.

This is the "polish makes it feel like a product" milestone: the data is already in the database after M1–M3; M4 turns it into spatial and temporal stories.

Branch off `feat/m3-tournaments` as `feat/m4-map-and-stats` (stacked-PR pattern, same as M1→M0 → M2→M1 → M3→M2). Stop scope at M4; M5 storytelling layer plans separately.

---

## Problem Frame

The M0 plan established the 8-tab nav with `Map` and `Stats` as placeholders. M1 (catch persistence) and M2 (trips, feed, friends) populated `catches` with real lat/lng + `secret_spot` flag, plus a working friend graph. M3 (tournaments) further validated the snapshot-on-submit privacy pattern. We now have:

- Real own + friend catch data with usable location columns (raw GPS for owner, RLS-nulled when `secret_spot=true` for friends).
- A `friendIdsProvider` that exposes the accepted-friend uid list for any view.
- A working `CatchesRepository.getFriendsCatches(friendIds)` that returns friend rows from `catches_friend_view`.

What's missing: a real map widget, a real stats surface, and a few things that haven't existed in any milestone yet — Marine Protected Area awareness, heatmap rendering, and a friends-comparison visualization.

The risk this milestone owns: **information leakage through display**. The friends-view already nulls `location` for secret-spot rows at the DB level (`supabase/migrations/0001_init.sql:catches_friend_view`), but the map layer still has to honor a stricter rule — never render a friend's catch as an exact pin on land if the underlying spot was a secret one. RLS is a backstop, not the only fence.

---

## Requirements

- R1. Map renders own catches as exact navy pins (`AppColors.navy`) when GPS is present.
- R2. Map renders accepted friends' catches as green pins (`AppColors.success`) when friend-view location is non-null (i.e., the friend did not mark Secret Spot).
- R3. "Show Friends" toggle hides all friend pins / friend-heatmap density without affecting own pins.
- R4. Heatmap mode replaces individual pin markers with a density gradient. Default-on for friends; own catches always render as exact pins regardless of mode (per origin doc spec).
- R5. Secret Spot suppression: a friend catch with `secret_spot=true` (location nulled in friend-view) never appears as an exact pin or in the heatmap layer. Own secret-spot catches still render exactly to the owner.
- R6. Marine Protected Area suppression: when a catch's raw GPS falls inside a bundled MPA polygon, the displayed point is offset to the nearest non-MPA water within ~1km. Raw coordinates remain stored and unchanged in the DB.
- R7. Conditions overlay placeholder visible in map chrome (wind / temp / tide labels) but does not fetch live data — gates on M6 conditions auto-fill.
- R8. Stats screen shows a 24-hour-of-day heatmap of own catches (count per hour-bucket).
- R9. Stats screen shows a vs-friends comparison ("you out-fished N% of friends this month") computed from own + friend catches over a rolling 30-day window.
- R10. Stats screen shows a conditions correlation placeholder card framed for M6 fill — with a clear empty state, not a fake chart.
- R11. App still passes `flutter analyze` clean and `flutter test` green after every M4 unit lands.
- R12. Friends-only RLS visibility holds — no schema or UI change in M4 may regress the policies in `0001_init.sql` or the security-definer helpers in `0007_tournament_rls_recursion_fix.sql`.

**Origin actors carried forward:** A1 Recreational angler (primary map + stats consumer), A2 Tournament participant (sees friends on map during a tournament weekend).

---

## Scope Boundaries

### Deferred for later

*(Carried from origin and parent plan — M5+ work.)*

- All of M5 (storytelling: PRs, badges, streaks, share cards) and beyond.
- Year-in-Review animated reel.
- Catch journal long-form notes.

### Outside this product's identity

*(Carried verbatim from origin.)*

- Public map / public spots / community water reports.
- Sharing exact GPS to non-friends through any surface.
- License or regulation enforcement (we surface MPA awareness *only* as a privacy/display nudge, not as enforcement).

### Deferred to Implementation

- **Conditions overlay live data.** R7 ships a static placeholder. The Open-Meteo + NOAA Tides edge function lands in M6 and will populate `catches.conditions`. M4 wires the UI shape so M6 only flips a data binding.
- **My Waters favorites.** Origin doc Section F lists "My Waters" as a quick-log default-location helper. That's a Log-tab feature, not Map-tab; defer to M5/M6 polish.
- **Personal map heatmap on Stats screen.** Origin doc Section G mentions this explicitly. The Stats screen R8/R9/R10 gets time-of-day, vs-friends, and conditions placeholder; the personal map heatmap is itself the Map tab in heatmap mode, so we link to `/map` from Stats rather than duplicate the surface.

### Outside this milestone's scope

- M5+ storytelling, M6 offline + conditions API, M7 onboarding & store submission. Each gets its own `/ce-plan` when its predecessor lands. **Do not enumerate M5+ units in this plan.**

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/map/presentation/map_screen.dart` — current placeholder; the `_showFriends` switch + `_Legend` are good UX bones to keep.
- `lib/features/stats/presentation/stats_screen.dart` — current placeholder cards; the `_StatsPlaceholderCard` shape is the right card chrome to keep for the conditions placeholder.
- `lib/features/catches/domain/catch.dart` — already exposes `latitude`, `longitude`, `hasLocation`, `secretSpot`. No domain change needed.
- `lib/features/catches/data/catches_repository.dart:getFriendsCatches` — returns friend rows via `catches_friend_view`. Already handles secret-spot null at the DB layer.
- `lib/features/catches/data/catches_repository_provider.dart` — has `myCatchesProvider`. Needs a sibling `friendsCatchesProvider` (M4 adds it; the only existing consumer of `getFriendsCatches` is the feed, which uses a different read shape via `feed_repository`).
- `lib/features/friends/data/friends_repository_provider.dart:friendIdsProvider` — exposes accepted-friend uids. Map data layer reads this.
- `lib/core/theme/app_colors.dart` — `navy`, `success`, `mist`, `paper` tokens already in place.
- `lib/core/theme/app_spacing.dart` — `radiusMd`, `radiusLg`, padding tokens used throughout. M4 chrome reuses unchanged.

### Institutional Learnings

- `docs/solutions/` does not exist yet (parent plan flagged this). M4 ends with one new entry: `docs/solutions/2026-05-01-mpa-display-suppression.md` capturing the bundled-GeoJSON + nudge approach so future contributors don't try to reach for a runtime API.

### External References

- **flutter_map** (`^7.0.2` at time of writing) — Leaflet-style Flutter package. OSM is the default tile provider via `TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: ['a','b','c'])`. OSM tile usage policy requires a real `User-Agent`; for a small private-beta app this is acceptable. If usage scales beyond v1.5 we move to Mapbox or self-hosted tiles.
- **NOAA Marine Protected Areas Inventory** — public-domain dataset of US MPAs. Full shapefile download is large (~200MB unprocessed). For a v1 mobile bundle we ship a curated, simplified GeoJSON (US National Marine Sanctuaries + a handful of state MPAs adjacent to common saltwater fisheries) preprocessed offline to <2MB compressed. Source URL: `https://marineprotectedareas.noaa.gov/dataanalysis/mpainventory/`.
- **Point-in-polygon** — simple ray-casting algo, ~30 lines of pure Dart. No `turf_dart` dependency required for v1; the dataset is small enough that a hand-rolled implementation passes any test we throw at it. Brought in only if the heatmap clustering needs more spatial primitives in M4.5+.
- **Material 3 Stats charting** — Flutter has no first-party charting widget. For a "good-enough, no dependency" shape, M4 hand-draws the time-of-day heatmap as a 24-cell `GridView` with opacity-bound color stops; vs-friends as a horizontal stacked bar. No third-party charting package is added in M4 — keeps the bundle and dependency surface lean. If charts grow more diverse in M5 storytelling, `fl_chart` is the candidate.

---

## Key Technical Decisions

- **`flutter_map` + OSM tiles, not Mapbox.** Origin doc deferred vendor selection to planning. Picking OSM avoids: token-management overhead, a vendor account, and a paid tier for a friends-only app with low map traffic. The cost: tile-quality is fine but not stunning; if the visual direction needs richer tiles later, swapping to Mapbox is a one-package change confined to `MapScreen`'s `TileLayer` config.
- **Friend-pin location source: `catches_friend_view`, not raw `catches`.** RLS already enforces secret-spot null on the friend-view, so the map data layer has belt-and-suspenders: rendering only rows whose `latitude != null` is sufficient to honor secret-spot. The map *additionally* never renders a friend pin when `secretSpot=true` defensively, even if location somehow leaked.
- **Heatmap rendering: client-side density grid, not a Mapbox heatmap layer.** Build a simple lat/lng → bin map at zoom-time, render bins as semi-transparent navy/green polygons via `flutter_map`'s `PolygonLayer`. Friends-only-app scale (<1000 catches typical) means this is cheap. Avoids any heatmap-shader dependency.
- **MPA dataset: bundled GeoJSON, not runtime API.** Privacy display rule must work offline. Bundle ~1–2MB simplified GeoJSON as `assets/geo/mpa_simplified.geojson` and load on first map open into a `MpaService` cache. Doesn't preclude a v1.5 swap to a runtime fetch with caching.
- **MPA "nearest non-MPA" algorithm: 8-direction search step, not full Voronoi.** When a point is inside an MPA polygon, walk outward 0.005° (~500m) at a time in N/NE/E/SE/S/SW/W/NW until a step lands outside *all* MPA polygons. Caps at 8 iterations (~4km offset); if no escape found, fall back to hiding the pin and surfacing the catch only in heatmap density. Pure Dart; deterministic for a given input.
- **Stats charts: hand-built, no third-party charting package.** Three small visualizations don't justify a dependency. Reassess in M5 if PR / share-card screens want richer chart shapes.
- **vs-Friends comparison window: rolling 30 days, not calendar month.** Calendar months produce a "1st of the month" cliff where the comparison resets to noise. Rolling 30 days reads as "this month" colloquially and avoids ranking artifacts on day 1.
- **Conditions overlay placeholder: visible chip strip, no live data.** Three pill chips in the map app-bar showing `Wind —`, `Tide —`, `Temp —` with em-dash placeholders. Communicates "this is coming" without faking data. M6's edge function flips the binding.
- **No new migrations in M4.** R12 is honored by adding zero schema changes. Map and stats are pure read-side features against M0–M3 schema.

---

## Open Questions

### Resolved During Planning

- *Map vendor — flutter_map vs Mapbox vs Google Maps:* `flutter_map` + OSM. No vendor lock, no token, matches Lovable's Leaflet aesthetic, free at v1 scale.
- *Heatmap dependency vs hand-roll:* hand-roll. Friends-only scale, no perf concern, no dependency.
- *MPA dataset shape — runtime fetch vs bundled:* bundled simplified GeoJSON. Offline-first ethos.
- *vs-friends window:* rolling 30 days.
- *Stats charting library:* none. Hand-build three visualizations.
- *Schema changes:* none.

### Deferred to Implementation

- *Exact MPA GeoJSON curation* — which polygons make the v1 bundle is an offline preprocessing task done during U3 implementation. The plan calls for a US-coastal subset under 2MB; the implementer picks the specific polygons and documents the source query.
- *Heatmap bin size at different zoom levels* — start at 0.01° (~1km) bins; tune live during implementation. The math is one constant.
- *Whether vs-friends shows percentile or raw count when the user has zero friends* — show an empty state ("Add friends to compare") in U6.
- *Whether the map zoom level persists across navigations* — first ship with no persistence; if it feels janky, add a Riverpod `mapCameraProvider` that survives tab switches. Trivially additive later.
- *Conditions placeholder copy* — implementer picks final microcopy during U4.

---

## High-Level Technical Design

> *Directional guidance for review, not implementation specification.*

```
M4 surface graph
─────────────────────────────────────────────────────────────────

      myCatchesProvider ─┐
      friendsCatchesProvider ─┐
                              ├──► mapPointsProvider
      friendIdsProvider ─┘    │     │
      mpaServiceProvider ─────┤     │
                              │     ├─ apply secret-spot filter
                              │     ├─ apply MPA suppress + offset
                              │     └─ tag own/friend pin color
                              │
                              ▼
                          MapScreen
                          ┌─────────────────────────────────────┐
                          │  AppBar: title + conditions chips   │
                          │  Toggle row: Friends ⏵︎ Heatmap ⏵︎     │
                          │  ┌──────────────────────────────┐   │
                          │  │  flutter_map                 │   │
                          │  │   TileLayer (OSM)            │   │
                          │  │   PolygonLayer (heatmap)     │   │
                          │  │   MarkerLayer (pins)         │   │
                          │  └──────────────────────────────┘   │
                          │  Legend (Yours / Friends)            │
                          └──────────────────────────────────────┘

      myCatchesProvider ─────► statsTimeOfDayProvider ──► HourHeatmap card
      myCatchesProvider ─┐
      friendsCatchesProvider ─┤───► statsVsFriendsProvider ──► VsFriendsCard
      friendIdsProvider ─┘                                  (top % framing)
                                                            (window: rolling 30d)

      static                ──► ConditionsCorrelationPlaceholderCard
                                                            (empty state, M6 hookup later)

────────────────────────────────────────────────────────────────
No schema changes. No new tables. No new migrations.
Bundle additions: assets/geo/mpa_simplified.geojson  (<2MB)
Dep additions:    flutter_map: ^7.0.2
                  latlong2:    ^0.9.1   (flutter_map peer)
```

---

## Implementation Units

- U1. **Add `flutter_map` dependency + bundle the MPA dataset asset**

**Goal:** Wire the package and bundle the simplified MPA GeoJSON so subsequent units have map tiles and polygon data to render against.

**Requirements:** R1, R6, R11.

**Dependencies:** None.

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/geo/mpa_simplified.geojson` (preprocessed offline from NOAA MPA Inventory; US-coastal subset, <2MB)
- Create: `assets/geo/README.md` (documents source, simplification method, refresh procedure)
- Test: none — pure dependency add

**Approach:**
- Add `flutter_map: ^7.0.2` and `latlong2: ^0.9.1` to `dependencies`.
- Add `assets/geo/` to `flutter.assets` in `pubspec.yaml`.
- Generate `mpa_simplified.geojson` offline: download NOAA MPA Inventory shapefile → filter to US-coastal MPAs (National Marine Sanctuaries + key state MPAs near common saltwater fisheries) → simplify polygons (Douglas-Peucker tolerance ~100m) → export GeoJSON → gzip-compatible plain JSON. Ship the resulting file under 2MB.
- `assets/geo/README.md` records the source URL, the filter criteria used, and how to regenerate (one-paragraph runbook). This is what makes the asset reproducible by a future contributor.

**Patterns to follow:**
- `pubspec.yaml` already lists `assets: - .env`. Extend the assets array — keep alphabetical order if any drift exists.

**Test scenarios:**
- Verification: `flutter pub get` succeeds; `flutter analyze` reports zero new issues; the asset loads via `rootBundle.loadString('assets/geo/mpa_simplified.geojson')` in a quick smoke check.

**Verification:**
- `flutter pub get` clean, `flutter analyze` clean, `flutter test` still green.

---

- U2. **Map data layer — `friendsCatchesProvider` + `mapPointsProvider`**

**Goal:** Expose two new Riverpod providers: a friends-only catches stream for the map (parallel to `myCatchesProvider`), and a `mapPointsProvider` that combines own + friends + applies secret-spot + MPA filtering into the displayable point set.

**Requirements:** R1, R2, R3, R5, R6, R12.

**Dependencies:** U1 (depends on `latlong2` for the `LatLng` type used in `MapPoint`), U3 (depends on `MpaService` for the MPA suppression rule).

**Files:**
- Create: `lib/features/map/domain/map_point.dart`
- Create: `lib/features/map/data/map_points_provider.dart`
- Modify: `lib/features/catches/data/catches_repository_provider.dart` (add `friendsCatchesProvider`)
- Test: `test/features/map/map_points_provider_test.dart`

**Approach:**
- `MapPoint` is a small immutable value: `{ catchId, displayLatLng, source: own|friend, isSecretSpot, isInMpa, isMpaShifted }`. Pure data; no widgets.
- `friendsCatchesProvider` watches `friendIdsProvider`, calls `catchesRepository.getFriendsCatches(friendIds)`, returns `List<Catch>`. Empty list when no friends.
- `mapPointsProvider` (a `Provider<AsyncValue<List<MapPoint>>>`) waits on both my-catches and friends-catches, applies in order:
  1. **Drop catches with no GPS.**
  2. **Drop friend catches with `secretSpot=true`** (defensive — RLS already nulls location for these; this is belt-and-suspenders).
  3. **Apply MPA shift** via injected `MpaService.shiftIfInMpa(latLng)` — owner sees own catches shifted too (privacy applies symmetrically).
  4. **Tag** each as own/friend, secret-spot, mpa-shifted (for diagnostics/dev overlay only).

**Patterns to follow:**
- `lib/features/feed/data/feed_repository_provider.dart:activityFeedProvider` — exact same pattern of `friendIdsProvider.valueOrNull ?? const []` + repository call.
- `myCatchesProvider` for shape parity.

**Test scenarios:**
- Happy path: `mapPointsProvider` with 1 own catch (with GPS) and 1 friend catch (with GPS, non-secret) returns 2 `MapPoint`s, one tagged own + one tagged friend.
- Secret-spot suppression: friend catch with `secretSpot=true` is filtered out even when location is non-null in the test fixture (defensive guard works).
- No-GPS suppression: own catch with `latitude=null` is filtered out.
- MPA shift: own catch whose lat/lng falls inside the test MPA polygon comes back with `displayLatLng` ≠ raw lat/lng and `isMpaShifted=true`.
- Empty state: with no friends and no own catches, returns `[]`, not error.
- Error path: `getFriendsCatches` throws → `mapPointsProvider` exposes `AsyncError` (Riverpod's standard error path).

**Verification:**
- `flutter test test/features/map/map_points_provider_test.dart` green. `flutter analyze` clean.

---

- U3. **`MpaService` — bundled-GeoJSON loader + point-in-polygon + nearest-non-MPA shift**

**Goal:** A pure-Dart service that loads `assets/geo/mpa_simplified.geojson` once, exposes `bool isInMpa(LatLng)` and `LatLng shiftIfInMpa(LatLng)`, and is injectable into providers and tests via Riverpod.

**Requirements:** R6, R12.

**Dependencies:** U1.

**Files:**
- Create: `lib/features/map/data/mpa_service.dart`
- Create: `lib/features/map/data/mpa_service_provider.dart`
- Test: `test/features/map/mpa_service_test.dart`
- Test fixture: `test/fixtures/mpa_test_polygons.geojson`

**Approach:**
- `MpaService` is an interface with two implementations: `BundledMpaService` (loads from `rootBundle`) and a future-proof seam for tests (`InMemoryMpaService` constructed from a fixture string).
- On first access: parse GeoJSON `FeatureCollection` → flatten into `List<List<LatLng>>` (each ring = one MPA polygon outer boundary; ignore inner-ring holes for v1 simplicity — false positives in MPAs-with-cutouts are still privacy-correct).
- `isInMpa(p)`: ray-casting algorithm, O(N polygons × edges). Warm-start cached after first call.
- `shiftIfInMpa(p)`: if not in MPA, return `p` unchanged. If in MPA, walk 8 compass directions in 0.005° increments for up to 8 iterations; return first step that's outside all polygons. If no escape after 8 steps, return raw `p` and let `mapPointsProvider` mark this catch heatmap-only by surfacing `isMpaShifted=false` + `isInMpa=true` (a downstream rendering rule that already exists per R6).
- Provider: `mpaServiceProvider = Provider<MpaService>((ref) => BundledMpaService());` — constructed lazily; the first `isInMpa` call triggers the asset load via a `_loaded` future.

**Patterns to follow:**
- `lib/core/supabase/supabase_providers.dart` shape — keep service classes private to their feature folder, expose only via providers.

**Test scenarios:**
- Happy path: a point clearly outside any polygon returns `isInMpa=false` and `shiftIfInMpa(p) == p`.
- Happy path: a point clearly inside the test polygon returns `isInMpa=true` and `shiftIfInMpa(p) != p` and `isInMpa(shifted) == false`.
- Edge case: a point exactly on a polygon edge returns deterministic boolean (don't care which, but must not throw).
- Edge case: a point inside an MPA where all 8 escape steps are *also* inside another MPA (constructed fixture) returns `p` unchanged — graceful degradation.
- Concurrency: two concurrent `isInMpa` calls both succeed without double-loading the asset (the `_loaded` future is shared).
- Error path: malformed GeoJSON in the fixture throws a clear `FormatException` from the service constructor — no silent failure.

**Verification:**
- `flutter test test/features/map/mpa_service_test.dart` green. `flutter analyze` clean.

---

- U4. **`MapScreen` rewrite — `flutter_map` + pins + heatmap toggle + conditions placeholder**

**Goal:** Replace the M0 placeholder with a real OpenStreetMap-backed map showing pins (own navy, friend green), a heatmap mode toggle, and a conditions placeholder chip strip.

**Requirements:** R1, R2, R3, R4, R7.

**Dependencies:** U1, U2, U3.

**Files:**
- Modify: `lib/features/map/presentation/map_screen.dart`
- Create: `lib/features/map/presentation/widgets/map_controls.dart`
- Create: `lib/features/map/presentation/widgets/conditions_chip_strip.dart`
- Create: `lib/features/map/presentation/widgets/heatmap_layer.dart`
- Test: `test/features/map/map_screen_test.dart`

**Approach:**
- Top app bar keeps title; trailing slot becomes a `ConditionsChipStrip` (three pills: Wind / Tide / Temp, all em-dash placeholders).
- Below the app bar: a control row with two toggles (`Show Friends`, `Heatmap mode`) replacing the M0 single-toggle row. Heatmap toggle defaults ON (per origin spec).
- Body: `flutter_map` with `MapOptions(initialCenter: ..., initialZoom: 4)`. Initial center = average of own catches if any, else continental US fallback.
- `TileLayer` uses OSM URL template + the required `userAgentPackageName: 'com.bunshin.fishingwithfriends'`.
- Layers stack:
  1. `TileLayer` (OSM tiles)
  2. `HeatmapLayer` (custom widget — when heatmap mode ON, builds bins from `mapPointsProvider`, renders semi-transparent polygons at 0.01° bin size, distinct colors for own (navy) vs friend (green) bins; when OFF, renders nothing)
  3. `MarkerLayer` (always rendered for own catches as exact pins; for friend catches only when heatmap mode is OFF)
- Legend reused from M0, slightly repositioned (bottom-left card overlay, not above-map row).
- Tap on a pin → `context.push('/catch/${catchId}')` (existing route from M2/M3).
- Loading state: subtle linear progress in app-bar bottom; map still renders OSM tiles. Error state: friendly snackbar; map still usable with whatever points loaded.

**Patterns to follow:**
- `lib/features/tournaments/presentation/tournament_detail_screen.dart` — pattern for a screen that subscribes to a provider, handles AsyncValue states, and lays out a multi-layer body.
- Existing `_Legend` and `_Dot` widgets in M0's `map_screen.dart` survive — extract into `widgets/legend.dart`.

**Test scenarios:**
- Happy path: `MapScreen` builds with `mapPointsProvider` returning 2 points (1 own + 1 friend, heatmap OFF) → finds 2 markers in the widget tree.
- Heatmap mode ON: friend point becomes a polygon bin; own point stays a marker. Asserted via finder counts.
- Show Friends OFF + Heatmap ON: only own pins visible, no friend bins.
- Show Friends OFF + Heatmap OFF: only own pins visible, no friend pins.
- Empty state: zero points in the provider → map renders OSM tiles + legend + an empty-state pill ("Log a catch to see your pins"); no crash.
- Loading state: provider in `AsyncLoading` → linear progress shows, OSM tiles still rendered.
- Error state: provider in `AsyncError` → snackbar fires once, map otherwise functional.
- Edge case: `flutter_map` widget tree renders at 320pt width without overflow (golden / `MediaQuery.size` constrained).
- Conditions strip: renders three em-dash placeholder chips and is *not* tappable (no live data binding).

**Verification:**
- `flutter test test/features/map/map_screen_test.dart` green. Manual smoke: tab to Map, see OSM tiles + own pins + friend pins (with the seeded test data from M1–M3), toggle Heatmap and Friends, observe transitions.

---

- U5. **Stats: time-of-day heatmap card**

**Goal:** Replace the M0 "Time-of-day Heatmap" placeholder with a real 24-cell visualization of own-catch counts per hour-of-day.

**Requirements:** R8, R11.

**Dependencies:** None (independent of U1–U4; can run in parallel).

**Files:**
- Modify: `lib/features/stats/presentation/stats_screen.dart`
- Create: `lib/features/stats/application/stats_time_of_day_provider.dart`
- Create: `lib/features/stats/presentation/widgets/hour_heatmap_card.dart`
- Test: `test/features/stats/hour_heatmap_test.dart`

**Approach:**
- `statsTimeOfDayProvider` watches `myCatchesProvider`, returns a `List<int>` of length 24 (count per hour bucket, local timezone, derived from `caughtAt.toLocal().hour`).
- `HourHeatmapCard` is a `Card` containing a 24-cell horizontal strip (`Row` of `Expanded` cells, or a 6×4 `GridView` for tighter fit). Each cell's color = navy with alpha = `count / max(counts)`. Cells with count=0 render a faint outline so the bucket is still visible.
- Below the strip: tick labels `12a · 6a · 12p · 6p`.
- Empty state: `myCatchesProvider` returns 0 catches → card shows "Log catches to see your hours" copy with no strip.

**Patterns to follow:**
- M0's `_StatsPlaceholderCard` chrome (icon + title + subtitle + content area).
- `myCatchesProvider` consumption pattern from M1's catch list screens.

**Test scenarios:**
- Happy path: provider with 3 catches at hours 6, 6, 18 returns `[0,0,0,0,0,0,2,0,...,0,1,0,...]`.
- Empty state: provider with 0 catches returns 24 zeros and the widget renders the empty-state copy.
- Timezone: a catch with `caughtAt = 2026-04-01T03:00:00Z` and the device set to America/New_York (UTC-4) bucketizes to hour 23 (11pm), not hour 3 — verifies the `.toLocal()` step is honored.
- Widget: tapping the card does nothing (no nav target in v1; this is a static viz). Asserted by absence of an `InkWell` consuming taps.

**Verification:**
- `flutter test test/features/stats/hour_heatmap_test.dart` green. `flutter analyze` clean.

---

- U6. **Stats: vs-friends comparison card**

**Goal:** Show a single-card "you out-fished N% of friends this month" view computed from own + friend catches over a rolling 30-day window.

**Requirements:** R9, R12.

**Dependencies:** U2 (reuses `friendsCatchesProvider`).

**Files:**
- Modify: `lib/features/stats/presentation/stats_screen.dart` (insert the new card)
- Create: `lib/features/stats/application/stats_vs_friends_provider.dart`
- Create: `lib/features/stats/presentation/widgets/vs_friends_card.dart`
- Test: `test/features/stats/vs_friends_test.dart`

**Approach:**
- `statsVsFriendsProvider` watches `myCatchesProvider`, `friendsCatchesProvider`, and `friendIdsProvider`. Computes:
  - `myCount` = own catches with `caughtAt > now - 30d`.
  - `friendCounts` = `Map<friendId, int>` over the same window.
  - `percentile` = (number of friends I beat or tie) / (total friends), or `null` when there are zero friends.
- `VsFriendsCard` shows:
  - Headline: "You out-fished {N}% of friends this month."
  - Subhead: "{myCount} catches in the last 30 days · {friendCount} friends compared."
  - A small horizontal bar chart: one navy bar (you) + one neutral bar per friend (sorted descending). Bars hand-drawn via `LinearProgressIndicator` or a `Container(width: ratio × maxWidth)`.
- Empty state with zero friends: `VsFriendsCard` renders "Add friends to compare your month" with an action chip routing to `/friends`.
- Empty state with zero own catches: "Log a catch this month to compare" with an action chip routing to `/log`.

**Patterns to follow:**
- The existing `myCatchesProvider` + `friendsCatchesProvider` consumption pattern; `Provider` (not `FutureProvider`) wrapping `AsyncValue.guard` for clean composition.
- The action-chip empty-state pattern from M2 feed empty state.

**Test scenarios:**
- Happy path: 5 own catches in the last 30 days; friend A has 3, friend B has 8, friend C has 4 in the same window → `myCount=5`, friend ranks `[B:8, A:3, C:4]`, you beat A and C (2 of 3), tie nobody → percentile = 67%. Headline reads "67%".
- Edge case: 5 own catches, friend has 5 catches → percentile counts the tie as a beat (≥), so 100%.
- Empty state, no friends: returns `null` percentile; widget renders the "Add friends" empty state with an action chip to `/friends`.
- Empty state, no own catches: percentile is `0%` but the widget surfaces the "Log a catch" empty state instead of "0%".
- Window boundary: a catch at exactly `now - 30d - 1s` is excluded; at `now - 30d + 1s` is included. Inclusive cutoff confirmed in test.
- Window boundary: catches in the future (`caughtAt > now`) are excluded.

**Verification:**
- `flutter test test/features/stats/vs_friends_test.dart` green. Smoke test on the device: with seeded friend catches, verify the percentile reads sensibly.

---

- U7. **Stats: conditions correlation placeholder card**

**Goal:** Add a third Stats card for "Conditions correlation" framed for M6 fill — a clear empty state, not a fake chart.

**Requirements:** R10.

**Dependencies:** None.

**Files:**
- Modify: `lib/features/stats/presentation/stats_screen.dart`
- Create: `lib/features/stats/presentation/widgets/conditions_correlation_card.dart`

**Approach:**
- Reuse the M0 `_StatsPlaceholderCard` shape but with explicit empty-state framing: title "Conditions correlation", subtitle "Coming with auto-fill weather + tide", body shows `Icons.thermostat_outlined` over `"We'll surface 'your top catches: falling tide + 65–72°F water' once weather + tide auto-fill ships."` Subtle `Chip(label: 'Available in M6')` at the bottom.
- No data binding. Pure stateless widget.

**Patterns to follow:**
- M0 `_StatsPlaceholderCard` directly.

**Test scenarios:**
- Widget builds without error in light + dark themes.
- Renders the expected microcopy and the M6 chip.

**Verification:**
- `flutter analyze` clean. Manual smoke: Stats tab shows three cards (hour heatmap, vs-friends, conditions placeholder).

---

- U8. **Documentation pass + learning entry**

**Goal:** Update parent docs and capture the MPA suppression decision so future contributors understand the bundled-GeoJSON + nudge approach.

**Requirements:** R11.

**Dependencies:** U1–U7.

**Files:**
- Modify: `docs/SUPABASE_SETUP.md` (no migration changes in M4; add a M4 status line under "Run the migrations" that says no new migration is required)
- Modify: `README.md` (Feature status table — flip Catch Map and Stats deepening to ✅)
- Create: `docs/solutions/2026-05-01-mpa-display-suppression.md`

**Approach:**
- The learning entry documents: why bundled GeoJSON over runtime API (offline-first); why hand-rolled point-in-polygon over a dep (small dataset, pure Dart); why the 8-direction-step nearest-non-MPA over Voronoi (simplicity, deterministic, good enough for v1); the licensing note (NOAA MPA Inventory is public-domain US Government work).
- `README.md` Feature status — Catch Map: pin + heatmap + MPA awareness ✅. Stats: time-of-day + vs-friends + conditions placeholder ✅.

**Test scenarios:**
- Verification only: docs render in GitHub markdown without broken anchors; the learning entry includes a "When to revisit" line covering when to swap to a runtime MPA service.

**Verification:**
- `flutter analyze` clean. `flutter test` green.

---

## System-Wide Impact

- **Interaction graph:** `mapPointsProvider` joins `myCatchesProvider` + `friendsCatchesProvider` + `mpaServiceProvider`. `statsVsFriendsProvider` joins `myCatchesProvider` + `friendsCatchesProvider`. None of these touch the catch creation path, RLS, or the tournament leaderboard. Catch detail screen unchanged.
- **Error propagation:** new providers surface as `AsyncValue` and follow the existing pattern (loading → progress, error → snackbar + degraded UI). No new exception types.
- **State lifecycle risks:** `MpaService` loads ~2MB on first `isInMpa` call. First map open will see a brief load (cached after that); `mapPointsProvider` is wrapped to wait on the `_loaded` future. No risk of double-load.
- **API surface parity:** zero schema changes. `catches_friend_view` already nulls location for secret-spot rows (added in M2/0001). RLS unchanged.
- **Integration coverage:** `test_integration/friends_only_rls_test.dart` already validates the friend-view secret-spot null behavior at the DB level. M4 doesn't extend this file — the friends-view contract is unchanged. The new map data-layer tests live as widget/unit tests.
- **Unchanged invariants:** RLS policies in `0001_init.sql` and the security-definer helpers in `0007_tournament_rls_recursion_fix.sql` remain authoritative; M4 introduces no migrations.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| OSM tile usage policy violation if map traffic spikes. | Friends-only app at v1 scale (≤100 users in private beta) is well within OSM's free-tier guidance. Add a real `userAgentPackageName` per OSM policy. If we exceed limits, swap `TileLayer` to Mapbox in one file. |
| MPA bundled GeoJSON grows past the 2MB target. | Curate harder during U1: keep only US National Marine Sanctuaries + state MPAs adjacent to common saltwater fisheries. Defer national-park overlays and freshwater protected areas to v1.5. The asset README documents the curation rules so a future contributor can re-extract. |
| `flutter_map` v7 API drift between when the plan is written and when U4 implements. | Pin to `^7.0.2` in U1; if breaking changes appear, drop to a fixed minor version. The widget surface is small (`FlutterMap`, `MapOptions`, `TileLayer`, `MarkerLayer`, `PolygonLayer`) and stable across recent v7 minors. |
| Heatmap polygon rendering at high zoom levels reveals exact-bin coordinates that imply Secret-Spot suppressed catches. | The heatmap layer reads from `mapPointsProvider`, which has *already* filtered out secret-spot rows at the data layer. The heatmap can never bin a row that wasn't in its input. Verified by the U2 test "secret-spot suppression". |
| `MpaService` first-load on map open causes perceptible jank on low-end Android. | Asset is small (~2MB), parsing is fast (<200ms on a Pixel 3a). If felt, move the load to app boot via `ref.read(mpaServiceProvider).warmUp()` from `main.dart` after auth. Trivially additive. |
| vs-friends card's percentile reads wrong when friend-graph and catch-graph are out of sync (e.g., friend was unfriended mid-window). | Provider reads current `friendIdsProvider` and only counts catches from currently-accepted friends. A removed friend simply drops out of the comparison. Documented in the U6 test scenarios. |
| Bundled GeoJSON licensing — confirm public-domain. | NOAA MPA Inventory is US-Government-produced work, public domain (17 USC 105). The U8 learning entry records this with a citation and the source URL. |

---

## Phased Delivery Within M4

M4 has internal dependencies but most units can ship in any order after U1. Suggested merge order on `feat/m4-map-and-stats`:

1. **U1** (deps + assets) — must be first.
2. **U3** (`MpaService`) — independent of U2, can be parallel.
3. **U2** (data providers) — depends on U1 + U3.
4. **U4** (MapScreen) — depends on U2 + U3.
5. **U5 + U6 + U7** (Stats cards) — U5 + U7 fully independent; U6 depends on U2's `friendsCatchesProvider`.
6. **U8** (docs + learning) — last, after all others land.

**Stop scope at M4.** M5 plan launches separately when M4 ships.

---

## Documentation / Operational Notes

- After M4 lands, `docs/SUPABASE_SETUP.md` needs a one-line note that M4 introduces no new migration. Real change is in client code only.
- `README.md` "Feature status" table: Catch Map (pins + heatmap + MPA awareness) ✅, Stats (time-of-day + vs-friends + conditions placeholder) ✅.
- New learning entry at `docs/solutions/2026-05-01-mpa-display-suppression.md` covering the bundled-GeoJSON + nudge approach, the licensing note, and "When to revisit" (move to runtime if dataset grows past 5MB or if international MPAs become required).
- Remind the implementer in U4: OSM tiles require a real `userAgentPackageName` (`com.bunshin.fishingwithfriends`) — failing to set this is a tile-fetch ban risk.

---

## Sources & References

- **Origin document:** `docs/brainstorms/fishing-with-friends-v1-requirements.md`
- **Parent plan:** `docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md`
- **Predecessor plans:** `docs/plans/2026-05-01-002-feat-m1-catch-persistence-plan.md`, `docs/plans/2026-05-01-003-feat-m2-trips-and-feed-plan.md`, `docs/plans/2026-05-01-004-feat-m3-tournaments-plan.md`
- **Visual reference:** `Assests/Screenshot 2026-05-01 134224.jpg` (Catch Map shape), `Assests/Screenshot 2026-05-01 134148.jpg` (Stats shape).
- **Schema baseline (no changes in M4):** `supabase/migrations/0001_init.sql` through `supabase/migrations/0008_auto_profile_on_signup.sql`.
- **External:** flutter_map (`^7.0.2`), latlong2 (`^0.9.1`), NOAA Marine Protected Areas Inventory (public domain, US Government, https://marineprotectedareas.noaa.gov/dataanalysis/mpainventory/), OpenStreetMap tile usage policy.
