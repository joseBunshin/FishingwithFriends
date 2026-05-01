---
title: "feat: M1 — real catch persistence end-to-end"
type: feat
status: active
date: 2026-05-01
origin: docs/brainstorms/fishing-with-friends-v1-requirements.md
---

# feat: M1 — real catch persistence end-to-end

## Summary

Wire the existing M0 catch-log form to Supabase Storage and the `catches` table, expose a Riverpod-backed `CatchesRepository`, and surface real catches across Home (Recent Catches), the Catches grid, and a new Catch detail screen — all guarded by the friends-only RLS policies already in place. Photos upload first under a client-generated catch UUID so the DB insert stays atomic; signed URLs are cached per path with a 1-hour TTL. M1 ends with an integration test that proves the friends-only read path against the dev Supabase project.

---

## Problem Frame

After M0, the app looks like the product but stores nothing. The Save Catch button shows a snackbar and pops the screen. Home / Catches / detail can't show real data because there isn't any. M1 turns the v1 wedge from "looks like a logbook" into "is a logbook" — every later milestone (trips, tournaments, social feed, map, stats, share cards, offline) lands on top of M1's data layer (see origin: Goals R3–R5; v1 plan Phased Delivery M1).

---

## Requirements

- R1. A signed-in angler can submit the M0 catch-log form and persist a catch with up to 5 photos to Supabase.
- R2. Persisted catches render on Home (Recent Catches), Catches grid, and a new Catch detail screen.
- R3. Photos are stored in the private `catches` bucket and surfaced via signed URLs only — never via public URLs.
- R4. A friend can read another friend's catches; a non-friend gets zero rows. Secret Spot strips GPS from the friend-side view but not from the owner.
- R5. The catch-log Save flow is atomic from the user's perspective: success → catch is in the list; failure → user sees an error and the form data is preserved.
- R6. Geolocator can populate the location field on demand; Secret Spot stays independent of the captured GPS.
- R7. App still passes `flutter analyze` clean and `flutter test` green; an opt-in integration suite proves the friends-only RLS contract end-to-end against the dev Supabase project.

**Origin actors:** A1 Recreational angler (primary — drives the catch-log + Home / Catches / detail surfaces).

---

## Scope Boundaries

### Deferred for later

*(Carried verbatim from origin — product/version sequencing.)*

- Photo species ID, voice-note transcription, tournament brackets (v1.5).
- Community water reports, public spots, web release, admin dashboard (v2).
- AI lure / depth / time suggestions, Apple Watch / Wear OS, Reels-style feed (v3).

### Outside this product's identity

*(Carried verbatim from origin — positioning rejection.)*

- Public network / public catch feed.
- Marketplace or in-app gear sales.
- Fishing-license tracking or regulation enforcement.
- Prize disbursement or payments inside tournaments.

### Deferred to Follow-Up Work

*Plan-local — implementation work intentionally split into other M-plans.*

- **Trips** as a catch parent (M2). M1 lets a catch live at the top level; the optional `trip_id` FK lands when M2 introduces `trips`.
- **Activity feed** showing friends' catches as a chronological list with reactions / comments (M2). M1 only proves the *read* path is friends-only; the social UI is M2.
- **Realtime subscriptions** on the catches table (M3 alongside tournament leaderboards). M1 refetches on screen-focus and on pop-back from Save.
- **Offline-first sync queue + photo retry** (M6). M1 surfaces upload / insert errors immediately; orphaned photos on failed inserts are not cleaned up in M1.
- **Conditions auto-fill** from the weather / tide API (M6). The `conditions` JSONB stays default-empty for now.
- **Activity event for friend feeds** (M2 — likely a `feed_events` insert trigger).
- **Voice notes / audio attachments** (v1.5 per origin). The Notes field stays text-only.

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/catches/presentation/catch_log_screen.dart` — M0 form already captures `_weightKg`, `_lengthCm`, species, date, time, location text, notes, rig, secret spot, C&R, and a `List<XFile>` of photos. The `_save()` method has a `// TODO(M1)` placeholder.
- `lib/core/supabase/supabase_providers.dart` — `supabaseClientProvider`, `currentUserProvider`, `authStateChangesProvider`. Repository providers compose on top.
- `lib/core/error/app_exception.dart` — `AppException`, `AuthFailure`, `ValidationFailure`, `NetworkFailure`. Repository should map Supabase errors into these.
- `lib/core/units/units.dart` — canonical metric helpers; the form already converts to kg / cm before reaching the persistence layer.
- `lib/features/home/domain/home_metrics.dart` + `lib/features/home/presentation/home_screen.dart` — `homeMetricsProvider` is currently a placeholder `Provider<HomeMetrics>`; M1 swaps it for an async provider that derives from real catches.
- `lib/features/catches/presentation/catches_screen.dart` — placeholder grid; rebuilt in M1/U7.
- `supabase/migrations/0001_init.sql` — `catches` table (with PostGIS `location`, `photo_paths text[]`, `secret_spot bool`, RLS policies friends-only).
- `supabase/migrations/0002_storage_policies.sql` — owner full-access + friends-read on the `catches` bucket. Path convention is `<angler_id>/...`; M1 extends to `<angler_id>/<catch_id>/<index>.<ext>`.
- `supabase/migrations/0003_units_and_species.sql` — canonical metric columns + species seed + `conditions` JSONB. `catches_friend_view` recreated; M1 extends it again with the new columns.

### Institutional Learnings

- `docs/solutions/` does not yet contain a learning entry. M1 ends with a new entry capturing the photo-upload-before-insert ordering and the signed-URL caching pattern, both of which other features (avatar uploads, tournament chat photos) will reuse.

### External References

- Supabase Storage — `from(bucket).upload(path, file)` returns the storage path; `createSignedUrl(path, expiresIn)` returns a short-lived URL (used per spec section 6: "All media served via temporary signed URLs"). Local pattern is sufficient — no external research dispatched.
- `cached_network_image` is already a dep; using it in tile renderers means signed-URL refresh during scroll is cheap.

---

## Key Technical Decisions

- **Client-generated catch UUID, photos uploaded before insert.** The catch's UUID is generated in Dart (`Uuid().v4()`) and used as the storage subfolder *and* the inserted `catches.id`. Photos upload first; the row insert references `photo_paths` with the already-uploaded paths. If the insert fails, the photos are orphaned in storage — accepted in M1, reaped in M6's sync / cleanup pass. Rationale: keeps the DB insert atomic, avoids the two-phase commit a server-generated id would force.
- **Storage path:** `<angler_id>/<catch_id>/<index>.<ext>`. Compatible with `0002_storage_policies.sql`'s owner-folder check (`(storage.foldername(name))[1] = angler_id`). Friends read via `are_friends(...)` in the storage policy and via signed URLs minted by the owner's session.
- **Signed-URL TTL = 3600s (1 hour).** Cached in a Riverpod `signedUrlProvider.family<String, String>` keyed by storage path; refreshed lazily when expired. One hour is well below the `cached_network_image` default disk-cache window, and Supabase signed URLs default to 60s — explicit TTL is required.
- **Repository per feature, providers wrap repository.** `CatchesRepository` does the Supabase calls and returns domain types; Riverpod `AsyncNotifierProvider`s expose the methods to the UI (`myCatchesProvider`, `friendsCatchesProvider`, `catchByIdProvider.family`).
- **Domain `Catch` is immutable, freezed-style hand-rolled.** Avoid pulling in `freezed` codegen for one model in M1 — manual `copyWith` + `==` is fine. `freezed` enters the build later when models multiply.
- **`catch_and_release` and `rig` get real columns.** The M0 form captured both. Stuffing them in `notes` or a JSON blob would haunt search and reporting later — better to give them columns now (migration `0004`).
- **No realtime in M1.** `catches` reads refetch on screen-focus and after Save. Realtime is M3 alongside tournament leaderboards (which is when its operational cost actually pays off).
- **Friends-only RLS validated via Dart integration test, not a SQL fixture.** A Dart test using `supabase_flutter` is closer to production behavior than a `psql` script. Gated behind `FWF_INTEGRATION=true` env var so `flutter test` default stays unit-only.
- **Map view of pins is M4, not M1.** M1 surfaces *list* views (Home, Catches grid, detail). The Map screen stays placeholder.

---

## Open Questions

### Resolved During Planning

- *Generate catch UUID client- or server-side?*: client. Atomic insert with known photo paths.
- *Where do `catch_and_release` + `rig` live?*: real columns on `catches` (migration `0004`).
- *How long are signed URLs valid?*: 3600s. Lazy refresh.
- *Realtime subscription in M1?*: no. Defer to M3.
- *How does the friends-feed query run?*: `select ... from catches_friend_view where angler_id in (<friend ids>)` — RLS already filters non-friend rows; the view nulls out `location` for Secret Spot rows. View gets recreated in `0004` to expose the new columns.
- *Photo cleanup on insert failure?*: accept orphans in M1. M6 sync queue reaps.
- *cached_network_image vs Image.network?*: `cached_network_image` — already a dep, gives free disk cache + placeholder + error builder.

### Deferred to Implementation

- *Exact pixel sizes for the Catches grid tile.* Settles on first device run.
- *Image compression / resize before upload.* `image_picker` already has `imageQuality: 92, maxWidth: 2400`. Whether we need additional compression depends on observed upload times — defer.
- *Whether `friendsCatchesProvider` paginates in M1 or returns the full list.* Probably no pagination at v1 friend-graph sizes (≤ ~200); revisit when friend counts grow.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
Save Catch flow (success path)
──────────────────────────────────────────────────────────────────

  CatchLogScreen._save()
       │
       ▼
  saveCatchControllerProvider.create(input)
       │
       ▼
  generate catchId = Uuid().v4()
       │
       ▼
  for each photo i in 0..N-1:                  ┐
      uploadResult = supabase.storage           │  if any
        .from('catches')                        │  fails →
        .upload('<angler_id>/<catchId>/<i>.<ext>', file)
                                                 │  error,
      photoPaths.add(uploadResult.path)         │  abort.
                                                 ┘
       │
       ▼
  supabase.from('catches').insert({
      id: catchId,
      angler_id: auth.uid,
      species_label: input.species,
      length_cm: input.lengthCm,
      weight_kg: input.weightKg,
      caught_at: input.caughtAt,
      location: input.gpsPoint,    -- nullable
      secret_spot: input.secretSpot,
      catch_and_release: input.catchAndRelease,
      notes: input.notes,
      rig: input.rig,
      photo_paths: photoPaths,
  })
       │
       ▼
  invalidate(myCatchesProvider, homeMetricsProvider)
  haptic.heavyImpact()
  navigate /catches/<catchId>


Read flow (Home / Catches / Detail)
──────────────────────────────────────────────────────────────────

  myCatchesProvider           friendsCatchesProvider          catchByIdProvider(id)
        │                            │                                │
        ▼                            ▼                                ▼
  select * from catches        select * from                    select * from catches_friend_view
  where angler_id = uid        catches_friend_view              where id = ? (RLS handles auth)
  order by caught_at desc      where angler_id in
                               (<accepted friend ids>)
        │                            │                                │
        └────────────────────────────┴──────────────┬─────────────────┘
                                                    ▼
                                          List<Catch> domain models
                                                    │
                                                    ▼
              ┌─────────────────────────────────────┴──────────────────────────────┐
              ▼                                                                    ▼
   CatchTile (in grid / Recent Catches)                                  CatchDetailScreen
              │                                                                    │
              ▼                                                                    ▼
    signedUrlProvider(photoPaths[0])                          for each photoPath:
              │                                                  signedUrlProvider(path) → signed URL
              ▼                                                  CachedNetworkImage(url)
    CachedNetworkImage(url)
```

---

## Implementation Units

- U1. **Schema migration `0004` — `catch_and_release` + `rig` columns + view recreate**

**Goal:** Give the M0 form's two captured-but-unstored fields real homes and republish `catches_friend_view` so reads see them.

**Requirements:** R5, R7.

**Dependencies:** None.

**Files:**
- Create: `supabase/migrations/0004_catch_metadata.sql`

**Approach:**
- `alter table public.catches add column catch_and_release boolean not null default false;`
- `alter table public.catches add column rig text;`
- `drop view public.catches_friend_view; create or replace view public.catches_friend_view as select ... including the two new columns;` (column list grows).
- Wrap in transaction.
- Re-run smoke select to confirm view returns expected columns.

**Patterns to follow:**
- `supabase/migrations/0003_units_and_species.sql` (transaction, view recreate).

**Test scenarios:**
- Happy path: migration applies cleanly to a project that already ran `0001`–`0003`.
- Happy path: `select catch_and_release, rig from catches_friend_view` returns the new columns (when at least one row exists; otherwise `\d catches_friend_view` lists them).
- Edge case: re-running the migration is idempotent — it isn't strictly here, but `add column if not exists` keeps it safe.

**Verification:**
- Migration runs green in the Supabase SQL Editor.
- New columns present on `catches` and `catches_friend_view`.

---

- U2. **Catch domain model + DTO mapping**

**Goal:** Define the immutable `Catch` domain type and the `CatchInput` write-side type, plus the `_fromRow` / `_toRow` conversions used by the repository.

**Requirements:** R1, R5.

**Dependencies:** None.

**Files:**
- Create: `lib/features/catches/domain/catch.dart`
- Create: `lib/features/catches/domain/catch_input.dart`
- Create: `lib/features/catches/data/catch_dto.dart`
- Test: `test/features/catches/domain/catch_test.dart`

**Approach:**
- `Catch`: id, anglerId, speciesLabel, speciesId?, weightKg?, lengthCm?, caughtAt, latitude?, longitude?, secretSpot, catchAndRelease, notes?, rig?, photoPaths, conditions (Map<String,dynamic>), createdAt, updatedAt. Immutable, manual `copyWith`, `==`, `hashCode`.
- `CatchInput`: the fields the catch-log form gathers, before persistence (no id, no createdAt).
- `catch_dto.dart`: `Catch.fromRow(Map<String,dynamic>)` and `Map<String,dynamic> toInsertRow(CatchInput, {required String anglerId, required String catchId})`. PostGIS `location` round-trips as `'SRID=4326;POINT(<lng> <lat>)'` text — keep mapping isolated here so the geometry encoding doesn't leak to the UI.

**Patterns to follow:**
- Existing immutable value object: `lib/features/home/domain/home_metrics.dart`.

**Test scenarios:**
- Happy path: `Catch.fromRow` round-trips an inserted row (all required + optional columns).
- Happy path: `toInsertRow` produces the expected map for a representative `CatchInput` including PostGIS-formatted `location`.
- Edge case: `secret_spot=true` still serializes location into the row (RLS / view, not DTO, hides it from friends).
- Edge case: `caughtAt` round-trips with timezone (ISO8601 UTC string in / `DateTime` UTC out).
- Edge case: `weightKg` and `lengthCm` are nullable; `null` round-trips cleanly.
- Edge case: `photoPaths` empty list serializes correctly (Postgres `text[]` empty literal).

**Verification:**
- `flutter analyze` clean. `flutter test test/features/catches/domain/catch_test.dart` green.

---

- U3. **`CatchesRepository` + photo storage helper**

**Goal:** Single repository that owns Supabase Storage uploads and `catches` table reads / writes, returning domain types and mapping Supabase errors into `AppException` subclasses.

**Requirements:** R1, R3, R4, R5, R7.

**Dependencies:** U1 (migration), U2 (domain types).

**Files:**
- Create: `lib/features/catches/data/catches_repository.dart`
- Create: `lib/features/catches/data/photo_storage.dart`
- Create: `lib/features/catches/data/catches_repository_provider.dart`
- Create: `lib/features/catches/data/signed_url_provider.dart`
- Test: `test/features/catches/data/catches_repository_test.dart`

**Approach:**
- `PhotoStorage`: `Future<String> upload(XFile, {required String anglerId, required String catchId, required int index})` returns the storage path; `Future<String> signedUrl(String path)` returns a 3600s URL.
- `CatchesRepository(SupabaseClient client, PhotoStorage storage)` exposes:
  - `Future<Catch> create(CatchInput, {required String anglerId})` — generates `catchId = uuid`, uploads photos sequentially, then inserts the row. Returns the persisted `Catch`.
  - `Future<List<Catch>> getMine()` — `select * from catches where angler_id = auth.uid order by caught_at desc`.
  - `Future<List<Catch>> getFriendsCatches()` — `select * from catches_friend_view where angler_id in (...)` — RLS already restricts to the calling user's friends; the view nulls out `location` for Secret Spot.
  - `Future<Catch?> getById(String id)` — reads from `catches` if owner, falls back to `catches_friend_view` if friend, returns null on RLS denial. Implementation: try `catches`, catch `PostgrestException` and try the view.
- `signedUrlProvider`: `FutureProvider.family<String, String>` keyed by storage path, with `keepAlive: true` and a TTL-aware refresh (regenerates if older than 50 minutes — slightly under the 60-minute Supabase TTL).
- `catchesRepositoryProvider`: `Provider<CatchesRepository>` composing `supabaseClientProvider` + a `PhotoStorage` instance.
- Map Supabase `StorageException`/`PostgrestException`/`AuthException` into `NetworkFailure` / `AuthFailure` / `AppException` so the UI layer never sees raw Supabase types.

**Execution note:** Test-first for the repository's create path — write a failing happy-path test that asserts photo upload precedes the row insert (verified via mock call ordering). The ordering invariant is privacy-load-bearing (no row references unuploaded paths).

**Patterns to follow:**
- Use `supabase_flutter`'s `client.storage.from('catches').upload(...)` and `.createSignedUrl(...)`.
- Throw / map exceptions as in `lib/features/auth/presentation/sign_in_screen.dart` (which already handles `AuthException` / generic `Exception`).

**Test scenarios:**
- Happy path: `create` with 2 photos uploads both, then inserts a row referencing both paths. Assert call order via a recording mock client.
- Happy path: `getMine` returns rows ordered by `caught_at desc`.
- Happy path: `getFriendsCatches` returns rows from the view; Secret Spot rows have `null` location.
- Happy path: `getById(id)` returns the catch when owner; returns the friend-view version when friend; returns `null` when neither.
- Error path: photo upload fails on photo 2 → `create` throws `NetworkFailure`, no row inserted.
- Error path: row insert fails after photos uploaded → `create` throws `NetworkFailure`. *No cleanup of orphan photos in M1 — documented and accepted.*
- Error path: `auth.currentUser == null` → `create` throws `AuthFailure` *before* attempting upload.
- Edge case: zero photos in input → `create` throws `ValidationFailure('At least one photo is required')`. (UI also enforces this — the repository is the source of truth.)
- Edge case: `signedUrlProvider` returns the same URL on repeated reads within TTL; refreshes after the 50-minute simulated lapse (test with a `Clock` injection).

**Verification:**
- All scenarios green. `flutter analyze` clean.

---

- U4. **Save Catch controller + location provider + wire `CatchLogScreen`**

**Goal:** Replace the `// TODO(M1)` placeholder in `CatchLogScreen._save()` with a Riverpod async controller that drives the upload + insert + post-save navigation, and wire the "use my location" button to a real `LocationService`.

**Requirements:** R1, R2, R5, R6.

**Dependencies:** U2, U3.

**Files:**
- Create: `lib/features/catches/application/save_catch_controller.dart`
- Create: `lib/features/catches/application/location_service.dart`
- Modify: `lib/features/catches/presentation/catch_log_screen.dart`
- Test: `test/features/catches/application/save_catch_controller_test.dart`
- Test: `test/features/catches/presentation/catch_log_screen_test.dart` (extend existing M0 test)

**Approach:**
- `saveCatchControllerProvider` is an `AsyncNotifierProvider<SaveCatchController, void>` that exposes a `submit(CatchInput input)` method. State is `AsyncLoading` while uploading, `AsyncError` on failure (UI surfaces `error.message`), `AsyncData(null)` on success — the screen pops to `/catches/<id>` via the returned id (passed back via a controller-owned completer or a result-typed AsyncValue).
- On success: invalidate `myCatchesProvider`, `homeMetricsProvider`, `friendsCatchesProvider`. Push `/catches/:id` (replaces the pop, so back-button returns to the previous tab).
- `LocationService`: thin wrapper over `geolocator` — `Future<LatLng?> currentPosition({Duration timeout})`. Permission flow uses `geolocator`'s built-in checker; if denied, return `null` and let the UI keep the manual location field.
- Update `CatchLogScreen`: `_save` calls `ref.read(saveCatchControllerProvider.notifier).submit(input)` and `await`s the resulting `AsyncValue`. Show a loading overlay while submitting; show a snackbar on error with retry. Wire the "use my location" button.

**Execution note:** Keep the existing `_useTallViewport` helper in widget tests; new tests follow the same pattern.

**Patterns to follow:**
- Existing form pattern in `catch_log_screen.dart` (preserve the `Form` key + validators).
- `AsyncNotifier` pattern from Riverpod 2.6 docs.

**Test scenarios:**
- Happy path: `submit` with valid input + 1 photo → controller transitions Idle → Loading → Data, navigates to detail route. Assert `myCatchesProvider` is invalidated.
- Happy path: `_useTallViewport` smoke — Save button submits, screen pops to detail.
- Error path: repository throws `NetworkFailure` → controller surfaces `AsyncError`, screen shows snackbar, form data preserved.
- Error path: repository throws `AuthFailure` → controller surfaces `AsyncError` and triggers a re-auth (in M1 just navigates back to `/sign-in`).
- Edge case: user taps Save twice rapidly → second tap is ignored while controller is `AsyncLoading`.
- Integration: `LocationService.currentPosition` permission denied → returns `null`; UI keeps the manual location field; Save still works without GPS (Secret Spot is independent).
- Integration: weight-only input (no length) — repository accepts it (length_cm nullable per schema).

**Verification:**
- Manual: sign in → log catch with one photo → confirm row in Supabase Table Editor and signed-URL preview in detail screen.
- All tests green. `flutter analyze` clean.

---

- U5. **Real `homeMetricsProvider` derived from catches**

**Goal:** Replace the placeholder `Provider<HomeMetrics>` with an async provider that pulls from `myCatchesProvider` and computes total catches / total weight / unique species / biggest.

**Requirements:** R2.

**Dependencies:** U3.

**Files:**
- Create: `lib/features/home/data/home_metrics_provider.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`
- Test: `test/features/home/home_metrics_provider_test.dart`

**Approach:**
- `homeMetricsProvider` becomes a `Provider<AsyncValue<HomeMetrics>>` (or a `FutureProvider<HomeMetrics>`) derived from `myCatchesProvider`. Compute totals client-side; if catches list is empty, return `HomeMetrics.empty()`.
- `HomeScreen` switches over `AsyncValue` states: `loading` → shimmer/skeleton on the stat tiles, `error` → tiles read `--` plus a small inline error, `data` → the existing layout.
- Recent Catches list: when populated, render up to 5 most recent catches as the existing photo card pattern, using `signedUrlProvider` for the cover photo. Empty state stays as M0.

**Patterns to follow:**
- Existing `homeMetricsProvider` import-site in `home_screen.dart` (no new wiring needed; just swap the source).

**Test scenarios:**
- Happy path: zero catches → `HomeMetrics.empty()`.
- Happy path: three catches with weights `1.0, 2.0, 3.0` kg, two distinct species, biggest at species "Largemouth Bass" → `totalCatches=3, totalWeightKg=6.0, uniqueSpecies=2, biggestWeightKg=3.0, biggestSpecies='Largemouth Bass'`.
- Edge case: a catch with `null` weight contributes 0 to total weight but still counts in `totalCatches`.
- Edge case: provider invalidates when `myCatchesProvider` invalidates after a Save.

**Verification:**
- After Save in U4, Home reloads and shows the new totals + a fresh Recent Catches card.

---

- U6. **Catches grid renders real catches with signed URLs**

**Goal:** Replace the placeholder grid with a real, scrollable grid of the user's catches; each tile is photo-first with species label + weight overlay.

**Requirements:** R2, R3.

**Dependencies:** U3.

**Files:**
- Modify: `lib/features/catches/presentation/catches_screen.dart`
- Create: `lib/features/catches/presentation/widgets/catch_card.dart`
- Test: `test/features/catches/presentation/catches_screen_test.dart`

**Approach:**
- `CatchesScreen` consumes `myCatchesProvider`; switches on `AsyncValue` (loading / error / data with empty state).
- Top of screen carries the search field + species filter (UI placeholders — no filter logic in M1, just visible affordances; filtering wires up in M4 stats / map). Date range pickers similarly visible-but-inert in M1.
- Grid: 2 columns, square tiles, rounded corners. Each tile renders cover photo via `cached_network_image` with `signedUrlProvider`. Species label as a navy pill (top-left), weight + length as a small footer line. Tap → `/catches/:id` with hero animation tag = `catch-photo-<id>`.
- Empty state: same shape as Home empty CTA.

**Patterns to follow:**
- `lib/features/home/presentation/widgets/stat_tile.dart` shape for card chrome.
- Lovable references: `Assests/Screenshot 2026-05-01 134101.jpg` for layout.

**Test scenarios:**
- Happy path: provider returns 4 catches → grid shows 4 tiles in 2 columns.
- Happy path: tap a tile → router pushes `/catches/<id>`.
- Edge case: provider returns empty list → empty-state card with CTA to `/log`.
- Error path: provider returns `AsyncError` → grid renders an inline error tile with retry that calls `ref.refresh(myCatchesProvider)`.
- Edge case: `cached_network_image` error builder fires when signed URL minting fails → tile shows a placeholder fish silhouette.

**Verification:**
- After Save in U4, Catches tab shows the new catch as the leftmost tile.

---

- U7. **Catch detail screen with hero transition**

**Goal:** New screen at `/catches/:id` showing one catch in full — photo carousel (hero-tagged for transition from grid), species + weight + length, caught-at, location (if not Secret Spot), notes, rig, C&R badge.

**Requirements:** R2, R3, R4.

**Dependencies:** U3, U6.

**Files:**
- Create: `lib/features/catches/presentation/catch_detail_screen.dart`
- Create: `lib/features/catches/presentation/widgets/catch_photo_carousel.dart`
- Modify: `lib/core/router/app_router.dart` (new `AppRoutes.catchDetail = '/catches/:id'`).
- Test: `test/features/catches/presentation/catch_detail_screen_test.dart`

**Approach:**
- `catchByIdProvider.family<Catch?, String>` from U3 backs the screen. Loading → shimmer; error → empty state with "This catch isn't available" (covers RLS denial gracefully); data → full layout.
- `CatchPhotoCarousel`: `PageView` of full-bleed photos backed by `signedUrlProvider`. Hero tag `catch-photo-<id>` matches the grid tile so the transition flows.
- Below the carousel: species headline, weight + length pill row, caught-at line, location (string from reverse-geocoding the lat/lng later — for M1 just show "Location hidden" when Secret Spot, otherwise lat/lng coordinates), notes, rig, C&R badge if true.
- App bar transparent over the photo, then turns navy on scroll (standard collapsing pattern via `SliverAppBar` if it fits cleanly, else simple AppBar).

**Patterns to follow:**
- Existing `Card` chrome and typography.
- `Hero` widget pairing with the grid tile.

**Test scenarios:**
- Happy path: provider returns a catch with 3 photos → carousel renders 3 pages, species + weight + length present.
- Happy path: hero tag on the leading photo matches `catch-photo-<id>` (verifiable with `find.byType(Hero)` and inspecting `tag`).
- Edge case: catch has zero photos (shouldn't happen for owner since UI requires ≥1, but possible if friend's catch was migrated externally) → carousel shows a single placeholder page.
- Edge case: catch has Secret Spot — location row shows "Location hidden" instead of lat/lng. Owner's view of their *own* Secret Spot catch *does* show coordinates (origin doc: Secret Spot hides only from friends).
- Error path: provider returns `null` (RLS denial) → screen renders "This catch isn't available" with a back button.

**Verification:**
- After Save in U4, navigation to `/catches/<id>` shows the just-created catch with its photo, species, weight, length.

---

- U8. **Friends-only RLS integration test**

**Goal:** Prove end-to-end against the dev Supabase project that (a) friends see each other's catches, (b) non-friends see zero rows, (c) Secret Spot strips GPS for friends but not for the owner. This is the privacy contract the entire app rests on.

**Requirements:** R3, R4, R7.

**Dependencies:** U3.

**Files:**
- Create: `test_integration/friends_only_rls_test.dart`
- Modify: `pubspec.yaml` (only if a new dev_dep is needed; likely none — `supabase_flutter` covers it).
- Modify: `README.md` (add a "Running integration tests" section).
- Modify: `analysis_options.yaml` (exclude `test_integration/` from default analysis runs *only if* needed; default include is fine).

**Approach:**
- The test uses three throwaway test users (e.g., `rls-a@fwf-test.local`, `rls-b@fwf-test.local`, `rls-c@fwf-test.local`) created by the test setup against the dev Supabase project.
- Setup: sign up A, B, C if missing; ensure A↔C are accepted friends, A↔B are not friends.
- Test 1: as A, insert a catch with `secret_spot=false`; as C, query `catches_friend_view`; expect to find A's row with `location` populated.
- Test 2: as B, query `catches_friend_view`; expect zero rows for A.
- Test 3: as A, insert a catch with `secret_spot=true`; as C, query the view; expect to find the row but `location IS NULL`.
- Test 4: as A, query own `catches`; expect both rows including the Secret Spot one with `location` populated (owners always see their own GPS).
- Gate: skip all tests when `bool.fromEnvironment('FWF_INTEGRATION') == false` (default false). Document the env-var invocation in `README.md`.
- Cleanup: each test deletes its own inserted rows in tearDown so re-running is idempotent.

**Execution note:** Test-first — write the four assertions before wiring the data layer they will eventually exercise. The whole point of M1 is to prove this contract holds; failing tests up front prevent green-on-mock false confidence.

**Patterns to follow:**
- Standard Dart `test` with `setUpAll` / `tearDownAll`. No special `flutter_test` widget tooling needed — pure Dart-side calls into `supabase_flutter`.

**Test scenarios:**
- Covers R4. Test 1 — Friend C reads A's non-secret catch including GPS.
- Covers R4. Test 2 — Stranger B reads A's catches and sees zero rows.
- Covers R4. Test 3 — Friend C reads A's Secret Spot catch with NULL location.
- Covers R4. Test 4 — A reads own Secret Spot catch with full location.
- Edge case: A removes C as a friend mid-test → C's read returns zero rows on the next call (verifying RLS isn't cached client-side).

**Verification:**
- `FWF_INTEGRATION=true flutter test test_integration/friends_only_rls_test.dart` green.
- Default `flutter test` ignores the integration suite (env var unset).

---

## System-Wide Impact

- **Interaction graph:** `saveCatchControllerProvider` invalidates `myCatchesProvider`, `homeMetricsProvider`, and `friendsCatchesProvider` after a successful insert. Any future feature that listens to those providers (M2 feed, M5 PRs, M4 stats) inherits the refresh-on-Save behavior automatically.
- **Error propagation:** Repository maps Supabase exceptions into `AppException` subclasses (`NetworkFailure`, `AuthFailure`, `ValidationFailure`). The Save controller surfaces those to the form via `AsyncValue.error`. The form renders a localized snackbar with retry; auth errors send the user to `/sign-in`.
- **State lifecycle risks:** Photos uploaded then row insert fails → orphaned photos in storage. **Accepted in M1** — they're invisible to the user and reaped in M6's sync queue. Documented in `docs/solutions/2026-05-01-catch-persistence.md` (created in M1's wrap-up).
- **API surface parity:** No external API surface changes. The schema gains two columns + a view rebuild; the Dart `CatchInput` matches the form one-for-one so future M2 trip-mode catch creation can extend the same controller.
- **Integration coverage:** U8 is the cross-layer scenario — RLS + Storage policy + view + Dart client interaction. Mocked unit tests cannot prove this contract; only U8 can.
- **Unchanged invariants:** `0001_init.sql` RLS policies, `0002_storage_policies.sql` bucket policies, and the canonical metric columns from `0003` all stay intact. M1 only *consumes* them. The `species` table is untouched in M1.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Photo upload partial-failure leaves orphaned files. | Accept in M1; M6 sync queue reaps. Document in `docs/solutions/`. |
| Signed URL expiry mid-render (user lingers on detail > 1 hour). | `cached_network_image` plus `signedUrlProvider` lazy-refresh at 50-minute mark; on stale URL the image rebuild kicks fresh signing. |
| Dev Supabase project drift breaks integration tests. | Gate U8 behind `FWF_INTEGRATION` env var; document in `README.md`. CI pipeline (M7) runs against a dedicated test project. |
| Race condition between Save and screen unmount before navigation. | Controller `mounted` check before `context.go`; AsyncNotifier guards against `dispose` during in-flight call. |
| Geolocator permission denied at runtime breaks Save. | Save is independent of GPS — Secret Spot mode just nulls the location. UI surfaces the denial state but does not block submit. |
| `friendsCatchesProvider` returns large lists without pagination. | Acceptable at v1 friend-graph sizes (≤ ~200). Pagination is a M2 follow-up if friend graph density warrants it. |
| Two-tap Save submits twice. | Controller ignores submit while in `AsyncLoading`; tested in U4. |

---

## Documentation / Operational Notes

- After M1 lands, append to `docs/SUPABASE_SETUP.md`: `0004_catch_metadata.sql` joins the run-list.
- Append a new "Running integration tests" section to `README.md` covering `FWF_INTEGRATION=true` and the test-user setup.
- Capture in `docs/solutions/2026-05-01-catch-persistence.md`: the photo-upload-before-insert ordering (atomic insert), client-generated UUIDs, signed-URL TTL caching, accepted-orphan tradeoff. Future contributors benefit; M2 trip persistence and M5 PR share-card image generation reuse the pattern.
- Update `README.md` "Feature status" table — flip "Catch persistence" from "M1 (UI only)" to "✅ M1".
- No external monitoring change in M1 (Supabase dashboard + the integration suite are sufficient for this milestone).

---

## Sources & References

- **Origin document:** `docs/brainstorms/fishing-with-friends-v1-requirements.md`
- **Predecessor plan:** `docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md` (M1 Phased Delivery sketch)
- **Related code:** `lib/features/catches/presentation/catch_log_screen.dart`, `lib/core/supabase/supabase_providers.dart`, `lib/core/error/app_exception.dart`, `supabase/migrations/0001_init.sql`, `supabase/migrations/0002_storage_policies.sql`, `supabase/migrations/0003_units_and_species.sql`.
- **Visual references:** `Assests/Main Photo 1.jpg` (Recent Catches), `Assests/Screenshot 2026-05-01 134101.jpg` (Catches grid).
