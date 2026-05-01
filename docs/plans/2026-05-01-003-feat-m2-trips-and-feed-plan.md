---
title: "feat: M2 — Trips + Activity Feed + Friend graph completion"
type: feat
status: active
date: 2026-05-01
origin: docs/brainstorms/fishing-with-friends-v1-requirements.md
---

# feat: M2 — Trips + Activity Feed + Friend graph completion

## Summary

Introduce **Trips** as an optional parent of catches, complete the **friend graph** (search by username + send / accept / reject requests), and surface a friends-only **Activity Feed** on the Home tab with catch cards, reactions, and flat comments with `@mention` highlighting. Builds on M0/M1 by reusing the same Riverpod async-repository pattern, the same friends-only RLS visibility model, and the same `signedUrlProvider` for photo display. No realtime, no notifications UI, no friend-profile screens — those are scoped to M3 / M6 / a focused follow-up respectively.

---

## Problem Frame

After M1 the app saves real catches and renders them for the owner, but the social loop is closed: there's no way to find friends, accept requests, or see anyone else's catches. The storytelling wedge stays half-realized — a beautiful logbook with no audience. M2 closes the loop by completing the friend graph and surfacing the friends-only feed that was the second half of the v1 wedge bet (see origin: Goals R2–R3, Product Thesis).

Trips arrive in the same milestone because most fishing happens in *sessions*, not isolated single catches — and grouping catches by trip is the foundation that M5's trip-summary share cards and M4's trip-shaped map heatmaps will build on.

---

## Requirements

- R1. A signed-in angler can search for another angler by username (case-insensitive substring) and send a friend request.
- R2. The recipient sees pending friend requests on the Friends tab and can accept or reject. RLS already prevents self-approval / cross-user inserts (no schema change needed).
- R3. After mutual acceptance, both users see each other's catches in the Activity Feed and via the existing `catches_friend_view` paths from M1.
- R4. An angler can start a Trip from the Catch-Log flow; subsequent saves attach to the active trip until the user ends it. Trips are optional — catches can still be standalone.
- R5. A Trip detail screen shows: cover photo (auto = first catch's first photo), title, body of water, start/end timestamps, total catches, total weight, top species, list of catches, and tagged companions.
- R6. The Home tab Activity Feed shows up to 50 most recent catches from friends + self in reverse chronological order, with reactions and comments inline.
- R7. A user can react to a catch with one of five reaction kinds (🎣 🔥 👊 🤯 🤝). Each user has at most one reaction per catch (toggle to clear).
- R8. A user can comment on a catch. Comments are flat (no threads). Comment text supports `@username` visual highlighting.
- R9. Friend requests, accepts, reactions, and comments insert rows into the existing `notifications` table for the recipient — the bell-icon UI is M6, but the data is captured now.
- R10. Friends-only RLS holds for every new surface: trips, comments, reactions, feed reads. The U8 RLS integration test from M1 is extended with new assertions for the new tables.
- R11. App still passes `flutter analyze` clean and `flutter test` green; the integration suite continues to be opt-in via `FWF_INTEGRATION=true`.

**Origin actors:** A1 Recreational angler (primary — drives all M2 social surfaces), A2 Tournament participant (secondary — only relevant when an M2 trip later flows into an M3 tournament; not blocking).

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

- **Realtime subscriptions** on feed / reactions / comments (M3, alongside tournament leaderboards). M2 refetches on screen-focus and on pull-to-refresh. Reactions appear instantly for the *acting* user via optimistic update; other viewers see them after refresh.
- **Notification UI** — the bell, the sheet, mark-as-read (M6 alongside push). M2 only inserts rows.
- **Friend profile screens** — tap a friend's avatar / @mention to see their catch grid. Visual highlighting on `@mention` ships in M2; the navigation target is a small follow-up plan (`docs/plans/2026-05-XX-feat-friend-profile-plan.md` to be authored on demand).
- **Auto-detect trips** from temporal proximity (multiple catches within an hour, same lat/lng cluster). v1.5 per origin doc.
- **Trip share cards / Year-in-Review trip slides** — M5.
- **Comment threading / replies** — out for v1; flat list only.
- **Comment editing / deletion** — out for v1. The author can delete their *own* comment; others can't edit. Deleting is in-scope; editing is not.
- **Pagination beyond the most-recent 50** — M2 returns the latest 50 feed items. If user research shows people scroll past 50, paginate in a follow-up.

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/catches/data/catches_repository.dart` + `catches_data_source.dart` — the repository / data-source split. M2 mirrors this for trips, friends, comments, reactions.
- `lib/features/catches/data/catches_repository_provider.dart` — Riverpod provider shape: `Provider<Repository>` + `FutureProvider<Domain>`. Same pattern for trips / friends / feed.
- `lib/features/catches/application/save_catch_controller.dart` — `AsyncNotifier<void>` with `submit()` returning a domain object on success. M2 controllers (trip create, friend request, comment submit, reaction toggle) follow the same pattern.
- `lib/features/catches/presentation/widgets/catch_card.dart` — photo-first tile with hero. Feed reuses + extends with reaction/comment bottom row.
- `lib/features/home/data/home_metrics_provider.dart` — derived provider pattern. Feed provider derives from a friends-list provider similarly.
- `lib/features/friends/presentation/friends_screen.dart` (M0 placeholder) — gets fully wired in M2.
- `supabase/migrations/0001_init.sql` — `friendships` table + RLS already covers M2's friend-graph requirements. **No schema change needed for friendships.** New tables added in M2/U1.
- `supabase/migrations/0003_units_and_species.sql` + `0004_catch_metadata.sql` — pattern for extending the `catches_friend_view` when columns change.

### Institutional Learnings

- `docs/solutions/2026-05-01-catch-persistence.md` — photo-upload-before-insert ordering. **Reused in M2/U7** for trip cover photo (which is just a reference to a catch's photo, not a new upload — but the same atomic-insert principle applies).
- M1 commit history establishes the AsyncValue + override pattern for widget tests: virtualized ListView wrappers need `binding.setSurfaceSize`, error-state overrides go through `Future.error`, and `cached_network_image` calls force `pump()` rather than `pumpAndSettle()`.

### External References

- Supabase Postgrest `.or(...)` and `.in_(...)` filters used for the feed query (catches whose angler_id is in the friend-list-plus-self). Local pattern in M1 is sufficient.

---

## Key Technical Decisions

- **Trip is optional, not required.** `catches.trip_id` is a nullable FK. M2 changes nothing for catches saved without an active trip — they continue to land standalone.
- **Single active trip per user at a time.** A user starts a trip → it's marked `is_active=true` for that user → all subsequent saves attach to it → user ends it → `is_active=false`. Active state is a per-user singleton in the DB (partial unique index on `trips(angler_id) where is_active`), so the catch-log form can resolve "current active trip" with a simple read. Two devices for the same user → last-active-wins (acceptable in v1; race-resolved by the partial-unique index — second insert raises a constraint violation that the controller surfaces as "you already have an active trip").
- **Reactions = single enum kind per `(catch_id, user_id)` row.** Toggle semantics: tapping the same kind clears; tapping a different kind upserts. One unique constraint, no row-counting drift.
- **Comments are flat + plain text + tombstone delete.** Soft-delete (`deleted_at` timestamp) so we can render "[deleted]" placeholders if a future thread / quote feature needs the row to still exist. Hard delete is fine but it makes thread-resilience harder later — soft-delete costs one nullable column.
- **`@mention` is text-only in M2.** Comments store the raw text; the renderer detects `@\w+` and styles those substrings. No FK to profiles, no notification trigger from `@mention` itself in M2 — comment notifications already cover the recipient (the catch owner). `@mentioned` users *not* the catch owner getting their own mention notification is M6.
- **Feed query reads from `catches_friend_view`** (recreated in M0/U6, M1/U1) plus a `union all` with own catches. Friends-only RLS already enforces per-row visibility; the view nulls Secret Spot location.
- **Notifications are write-only in M2 — no UI consumes them.** Rows are inserted via Supabase row triggers on `friendships`, `feed_reactions`, `comments`. The DB function shape matches what M6 will ingest.
- **Optimistic reaction toggle.** The actor sees their reaction immediately; if the insert fails the UI rolls back with a snackbar. Comments are not optimistic — too-easy to mis-render; user waits for round-trip.

---

## Open Questions

### Resolved During Planning

- *Trip detection: explicit vs auto-time-window?* → explicit in M2. v1.5 may add auto-detect on top.
- *Reaction kinds and how many?* → 5 emoji per origin doc. One per user per catch; toggle to clear.
- *Comment threads vs flat?* → flat in v1. Soft-delete to leave threading possible later.
- *Where do feed rows come from?* → `catches_friend_view` + own `catches`, not a separate `feed_events` table. Avoids the dual-write headache; the view + the friend graph already give us the right rows. If feed cardinality / per-row enrichment makes this slow at v2 scale, materialize then.
- *Pagination strategy?* → cursor on `caught_at desc` with a 50-row page. Refresh resets the cursor. M2 only renders page 1; "load more" is a follow-up.
- *Real-time?* → no in M2. M3 layers realtime onto the leaderboard; same pattern can extend to feed there.
- *@mention notification rows in M2?* → no. Catch-owner already notified by comment trigger; mentioning a *different* user gets its own notification in M6 alongside push.

### Deferred to Implementation

- *Whether the Activity Feed lives at the bottom of the Home tab or replaces the Recent Catches placeholder section entirely.* Decided during U8 once the Home layout is rendered against real friend data.
- *Exact @mention regex.* Username characters are alphanumeric + underscore (3–30 chars per profiles CHECK). Settle the precise regex when writing the highlighter widget.
- *Trip cover photo selection rule when multiple catches have multiple photos.* M2 = "first catch's first photo." A best-photo heuristic (largest fish, highest engagement) is M5 share-card territory.
- *Whether single-tap on a feed card should open the catch detail or the trip detail when the catch is part of a trip.* Decide once both screens are wired — cover both with widget tests.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
M2 surface graph
─────────────────────────────────────────────────────────────────

  Friends tab                 Home tab                Catch Log
       │                         │                       │
       │                         ▼                       │
       │            activityFeedProvider                  │ "Start a Trip"
       │                  │                               │      │
       │                  ▼                               ▼      │
       │       FeedRepository                  TripsRepository ◀─┘
       │            │                                │
       ▼            ▼                                ▼
  FriendsRepository                            tripsRepositoryProvider
       │
       ▼
  ┌────┴────┐
  search    requestor                          activeTripProvider
  │         │                                  (per-user singleton)
  ▼         ▼
  list      acceptor / rejecter

  Schema delta (M2):
  ─────────────────
  trips                    (id, angler_id, title, body_of_water,
                             cover_photo_path, started_at, ended_at,
                             is_active, created_at, updated_at)
  trip_participants        (trip_id, angler_id, status)         -- companions
  feed_reactions           (catch_id, user_id, kind, created_at) UNIQUE pair
  comments                 (id, catch_id, author_id, body,
                             deleted_at, created_at, updated_at)
  catches.trip_id          (nullable FK)

  Triggers (DB → notifications row):
  ────────────────────────────────
  AFTER INSERT on friendships         → notify addressee (kind: friend_request)
  AFTER UPDATE on friendships
       (status pending → accepted)    → notify requester (kind: friend_accepted)
  AFTER INSERT on feed_reactions       → notify catch.angler_id (kind: reaction)
  AFTER INSERT on comments             → notify catch.angler_id (kind: comment)
                                         (skip if author == owner)


Activity Feed query
─────────────────────────────────────────────────────────────────

  current user uid = X
  accepted friend ids = (select addressee where requester=X and status=accepted)
                      ∪ (select requester where addressee=X and status=accepted)

  visible_catches =
    SELECT * FROM catches_friend_view WHERE angler_id IN (friend_ids)
    UNION ALL
    SELECT * FROM catches WHERE angler_id = X

  ORDER BY caught_at DESC
  LIMIT 50

  -- RLS already filters non-friend rows. The view nulls Secret Spot location.
  -- One round trip per feed render; reaction + comment counts arrive via a
  -- secondary aggregate query keyed by catch_id list.
```

---

## Implementation Units

- U1. **Migration `0005` — trips, trip_participants, feed_reactions, comments + notification triggers**

**Goal:** New tables for trips and social interactions plus the row triggers that write into `notifications`. RLS policies that match the friends-only model already in place.

**Requirements:** R3, R4, R5, R7, R8, R9, R10, R11.

**Dependencies:** None.

**Files:**
- Create: `supabase/migrations/0005_trips_and_social.sql`

**Approach:**
- `trips`: id (uuid pk), angler_id (fk profiles, cascade), title, body_of_water, cover_photo_path (nullable, set on first catch), started_at (default now()), ended_at (nullable), is_active (boolean default true), created_at, updated_at.
- Partial unique index `idx_trips_one_active_per_angler ON trips(angler_id) WHERE is_active`. Enforces the single-active-trip-per-user invariant.
- `trip_participants`: trip_id, angler_id, status enum ('invited','accepted','declined'). Composite PK (trip_id, angler_id).
- `feed_reactions`: catch_id, user_id, kind text constrained by check ('rod','fire','fist','mind','handshake'), created_at. Composite PK (catch_id, user_id).
- `comments`: id (uuid pk), catch_id, author_id, body (text not null, length ≤ 2000), deleted_at (nullable), created_at, updated_at.
- Add column `catches.trip_id` (nullable fk trips, on delete set null). Index on `(angler_id, trip_id)`.
- Recreate `catches_friend_view` to include `trip_id`.
- RLS:
  - `trips`: select if angler is owner OR mutual friend. Insert / update only owner. Delete only owner.
  - `trip_participants`: select if owner of trip OR is the participant. Insert by owner only. Update (accept/decline) by participant only.
  - `feed_reactions`: select if reacting user OR catch owner OR mutual friend of catch owner. Insert / delete by reacting user. Update not allowed.
  - `comments`: select if author OR catch owner OR mutual friend of catch owner. Insert by self. Update only by author and only `deleted_at` (i.e. soft-delete). No body edits in v1.
- Triggers:
  - `tg_notify_friend_request` AFTER INSERT on friendships when status='pending' → insert notification row for addressee (kind 'friend_request').
  - `tg_notify_friend_accepted` AFTER UPDATE on friendships when NEW.status='accepted' AND OLD.status='pending' → insert notification for requester.
  - `tg_notify_reaction` AFTER INSERT on feed_reactions → insert notification for catch's angler_id (skip if user_id = angler_id).
  - `tg_notify_comment` AFTER INSERT on comments → insert notification for catch's angler_id (skip if author_id = angler_id).

**Patterns to follow:**
- `supabase/migrations/0004_catch_metadata.sql` for the view-recreate pattern.
- `supabase/migrations/0001_init.sql` for the RLS policy DSL.

**Test scenarios:**
- Happy path: migration applies cleanly to a project that has run 0001..0004.
- Happy path: inserting a `trips` row succeeds for the owner; selecting from another non-friend returns zero rows.
- Happy path: inserting a second `trips` row with `is_active=true` for the same `angler_id` raises a unique-constraint violation.
- Happy path: inserting a `feed_reactions` row triggers a `notifications` row for the catch owner; same row inserted by the catch owner does NOT trigger.
- Happy path: inserting a friendship transitions the addressee's `notifications` count by 1; updating to `accepted` transitions the requester's count by 1.
- Edge case: comments soft-delete sets `deleted_at`; row remains; non-author cannot update.
- Integration: full RLS sweep — A inserts trip + reactions + comments; B (friend) reads them; C (stranger) gets zero rows on every table.

**Verification:**
- Migration runs green in Supabase SQL Editor.
- `\d catches_friend_view` shows `trip_id`. `\d trips`, `\d trip_participants`, `\d feed_reactions`, `\d comments` all show expected columns + RLS enabled.
- Trigger inserts visible in `notifications` after sample DML.

---

- U2. **Domain models + DTOs for Trip, Comment, Reaction**

**Goal:** Immutable domain objects + row mappers for the four new tables / extended catch.

**Requirements:** R3, R4, R5, R7, R8, R11.

**Dependencies:** U1.

**Files:**
- Create: `lib/features/trips/domain/trip.dart`
- Create: `lib/features/trips/domain/trip_input.dart`
- Create: `lib/features/trips/data/trip_dto.dart`
- Create: `lib/features/feed/domain/comment.dart`
- Create: `lib/features/feed/domain/reaction.dart`
- Create: `lib/features/feed/data/comment_dto.dart`
- Create: `lib/features/feed/data/reaction_dto.dart`
- Modify: `lib/features/catches/domain/catch.dart` (add nullable `tripId` field, copyWith / == / hashCode)
- Modify: `lib/features/catches/domain/catch_input.dart` (add `tripId` field — defaults null)
- Modify: `lib/features/catches/data/catch_dto.dart` (round-trip `trip_id`)
- Test: `test/features/trips/domain/trip_test.dart`
- Test: `test/features/feed/domain/comment_test.dart`
- Test: `test/features/feed/domain/reaction_test.dart`
- Test: `test/features/catches/domain/catch_test.dart` (extend with trip_id round-trip)

**Approach:**
- Mirror the M1 catch domain pattern: `@immutable` class, manual `copyWith` / `==` / `hashCode`, no freezed yet (keep one model multiplicity threshold; revisit at the end of M2).
- `Trip`: id, anglerId, title, bodyOfWater, coverPhotoPath, startedAt, endedAt (nullable), isActive, createdAt, updatedAt.
- `TripInput`: title, bodyOfWater (optional initially — can be set later when first catch lands).
- `Comment`: id, catchId, authorId, body, deletedAt (nullable), createdAt, updatedAt. `isDeleted` getter.
- `Reaction`: catchId, userId, kind (enum: rod / fire / fist / mind / handshake), createdAt.
- `ReactionKind` enum has a stable string serialization (lowercase id) and a display emoji + label for UI.

**Patterns to follow:**
- `lib/features/catches/domain/catch.dart`, `lib/features/catches/data/catch_dto.dart`.

**Test scenarios:**
- Happy path: each DTO round-trips a representative row.
- Edge case: `Trip` with `endedAt = null` round-trips as still-active.
- Edge case: `Comment` with `deletedAt` set is `isDeleted == true`; `body` still readable for tombstone rendering.
- Edge case: `Reaction.kind` serializes to / from the canonical string set; unknown string → throws ArgumentError (test the validator).
- Edge case: `Catch.fromRow` round-trips a row with `trip_id` populated.
- Edge case: `Catch.fromRow` with `trip_id` absent yields `tripId == null`.

**Verification:**
- `flutter analyze` clean. New tests + extended catch test green.

---

- U3. **`TripsRepository` + extend `CatchesRepository` with active-trip awareness**

**Goal:** Trip CRUD repository (start, end, get active, get by id, get participants) plus a tripId pass-through on `CatchesRepository.create`.

**Requirements:** R4, R5.

**Dependencies:** U1, U2.

**Files:**
- Create: `lib/features/trips/data/trips_data_source.dart`
- Create: `lib/features/trips/data/trips_repository.dart`
- Create: `lib/features/trips/data/trips_repository_provider.dart`
- Modify: `lib/features/catches/data/catches_repository.dart` (accept optional `tripId` in `create`)
- Modify: `lib/features/catches/data/catch_dto.dart` (include `trip_id` in insert row)
- Test: `test/features/trips/data/trips_repository_test.dart`
- Test: `test/features/catches/data/catches_repository_test.dart` (extend — verifies trip_id is forwarded)

**Approach:**
- `TripsDataSource`: insertTrip, endActiveTrip, selectActiveTrip(anglerId), selectTripById(id), selectMine.
- `TripsRepository`: orchestrates. `startTrip(input)` raises `ValidationFailure` if there's already an active trip; `endTrip(id)` sets `is_active=false`, `ended_at=now()`. Returns updated `Trip`.
- `activeTripProvider`: `FutureProvider<Trip?>` keyed off `currentUserProvider`. Used by the catch-log form to know whether to attach a trip_id.
- `CatchesRepository.create` gains an optional `tripId` parameter; falls through to `CatchDto.toInsertRow` which includes `trip_id` when non-null.
- Map `PostgrestException` (especially the partial-unique-index violation) into `ValidationFailure('You already have an active trip — end it before starting a new one.')`.

**Execution note:** Test-first for `startTrip` against an active-trip-already-exists scenario; the partial-unique-index is the privacy-irrelevant but data-integrity-load-bearing invariant.

**Patterns to follow:**
- `lib/features/catches/data/catches_repository.dart` for the Repository / DataSource split + AppException mapping.

**Test scenarios:**
- Happy path: `startTrip` with no active trip → returns `Trip` with `isActive=true`.
- Happy path: `endTrip` flips `isActive=false` and stamps `endedAt`.
- Happy path: `getActiveTrip` returns the live trip.
- Edge case: `getActiveTrip` returns null when none active.
- Error path: `startTrip` when one is already active throws `ValidationFailure` with a friendly message; no row inserted.
- Error path: Postgrest network error maps to `NetworkFailure`.
- Integration: `CatchesRepository.create(input, tripId: t.id)` stores `trip_id`; subsequent read includes it.

**Verification:**
- All scenarios green. `flutter analyze` clean.

---

- U4. **`FriendsRepository` — search, request, accept, reject, list**

**Goal:** Wrap the existing `friendships` table for the M2 friend-graph UI: search profiles by username, send / accept / reject requests, list friends + pending requests.

**Requirements:** R1, R2, R3.

**Dependencies:** None (`friendships` schema lands in `0001`; `profiles_username_idx` exists since M0). Logically follows U2 only because it imports the domain `Profile` shape, which we introduce here as a new lightweight value object.

**Files:**
- Create: `lib/features/friends/domain/profile.dart`
- Create: `lib/features/friends/domain/friendship.dart`
- Create: `lib/features/friends/data/friends_data_source.dart`
- Create: `lib/features/friends/data/friends_repository.dart`
- Create: `lib/features/friends/data/friends_repository_provider.dart`
- Test: `test/features/friends/data/friends_repository_test.dart`

**Approach:**
- `Profile`: id, username, displayName, avatarPath (nullable). Read-only — write happens via dedicated profile flow later.
- `Friendship`: requesterId, addresseeId, status (`pending` / `accepted` / `blocked`), createdAt, updatedAt.
- `FriendsDataSource`: searchProfiles(query, limit), insertFriendship, updateStatus, deleteFriendship, selectAcceptedFriends(uid), selectPendingIncoming(uid), selectPendingOutgoing(uid).
- `FriendsRepository`: composes the data source. Search uses `ilike` on `profiles.username`; rejects empty / 1-char queries.
- `friendIdsProvider`: `Provider<AsyncValue<List<String>>>` exposing accepted friend uids — feed query depends on this.

**Patterns to follow:**
- `lib/features/catches/data/catches_repository.dart` for AppException mapping.
- `friendships` RLS policies in `0001_init.sql` are the contract — repository calls map cleanly to allowed operations.

**Test scenarios:**
- Happy path: `search('silent')` returns profiles whose username starts with or contains `silent` (case-insensitive).
- Happy path: `sendRequest(addresseeId)` inserts a row with status='pending' and the current user as requester.
- Happy path: `accept(friendship)` updates status to 'accepted' when the current user is the addressee.
- Happy path: `reject(friendship)` deletes the row.
- Happy path: `acceptedFriends` returns both directions of the graph (requester=me OR addressee=me, status=accepted).
- Error path: `sendRequest` when friendship row already exists (re-request) raises a meaningful `ValidationFailure` ("You've already sent a request" / "You're already friends").
- Error path: empty query throws `ValidationFailure('Enter at least 2 characters')`.
- Edge case: search excludes the current user from results.

**Verification:**
- All scenarios green. `flutter analyze` clean.

---

- U5. **Friends screen — wired to `FriendsRepository`**

**Goal:** Replace the M0 placeholder Friends screen with the real flow: header showing the user's own `@username`, search input that returns profile rows, "Send request" button per result, list of incoming pending requests with Accept / Reject, list of accepted friends with a remove (×) action.

**Requirements:** R1, R2.

**Dependencies:** U4.

**Files:**
- Modify: `lib/features/friends/presentation/friends_screen.dart`
- Create: `lib/features/friends/presentation/widgets/friend_search_field.dart`
- Create: `lib/features/friends/presentation/widgets/friend_row.dart`
- Create: `lib/features/friends/presentation/widgets/pending_request_row.dart`
- Create: `lib/features/friends/application/friends_controller.dart`
- Test: `test/features/friends/presentation/friends_screen_test.dart`
- Test: `test/features/friends/application/friends_controller_test.dart`

**Approach:**
- Three sections: My Username (with copy), Find Anglers (search input + results list), Incoming requests (only shown when count > 0), My Friends (count + list).
- `FriendsController` is an `AsyncNotifier<void>` — exposes `sendRequest`, `acceptRequest`, `rejectRequest`, `removeFriend`. Optimistic UI: list items grey out while the action is in flight, snackbar on error.
- Search input debounced (~300 ms), results in a list below the input. Each result row has a Send Request affordance unless friendship already exists or the row is the current user (filtered by `FriendsRepository`).
- Pending-incoming row has prominent Accept (filled) + Reject (text) buttons.
- Accepted friend row has a leading avatar / handle and a trailing × that prompts a confirm dialog before deleting.

**Patterns to follow:**
- `lib/features/catches/application/save_catch_controller.dart` for the AsyncNotifier / submit / state.isLoading guard pattern.
- `lib/features/me/presentation/me_screen.dart` for chrome consistency.

**Test scenarios:**
- Happy path: typing 3+ chars surfaces 1+ result row (after a debounce simulated by `tester.pump(Duration(milliseconds: 300))`).
- Happy path: tapping Send Request triggers controller and the row's affordance changes to "Pending".
- Happy path: Accept on a pending-incoming row moves it from incoming list → friends list.
- Happy path: Reject removes the row from incoming list.
- Error path: send-request failure shows a snackbar; the row's affordance reverts.
- Edge case: empty search input shows the friends list only (no results section).
- Edge case: removing a friend opens a confirm dialog; cancelling does not call the repository.

**Verification:**
- `flutter analyze` clean. Manual smoke: sign in → tap Friends → search by your other test user → send request → switch user → accept → first user sees the new friend.

---

- U6. **`ActivityFeedRepository` + `activityFeedProvider`**

**Goal:** Read path that returns the most recent 50 catches from friends + self, plus aggregated reaction/comment counts and the current user's own reaction kind per catch.

**Requirements:** R6, R7, R8.

**Dependencies:** U1, U2, U4.

**Files:**
- Create: `lib/features/feed/domain/feed_item.dart`
- Create: `lib/features/feed/data/feed_data_source.dart`
- Create: `lib/features/feed/data/feed_repository.dart`
- Create: `lib/features/feed/data/feed_repository_provider.dart`
- Test: `test/features/feed/data/feed_repository_test.dart`

**Approach:**
- `FeedItem` wraps a `Catch` plus aggregate fields: `reactionCounts` (Map<ReactionKind,int>), `myReaction` (ReactionKind?), `commentCount` (int).
- `FeedDataSource.selectFeed(currentUserId, friendIds, limit)` runs two queries:
  1. `SELECT * FROM catches_friend_view WHERE angler_id IN (friend_ids) UNION ALL SELECT * FROM catches WHERE angler_id = currentUserId` — ordered by caught_at desc, limited to 50.
  2. For the resulting catch ids: `SELECT catch_id, kind, count(*) FROM feed_reactions GROUP BY catch_id, kind`, plus `SELECT catch_id, count(*) FROM comments WHERE deleted_at IS NULL GROUP BY catch_id`, plus `SELECT catch_id, kind FROM feed_reactions WHERE user_id = currentUserId AND catch_id IN (...)`.
- `FeedRepository.getFeed()` composes data into `List<FeedItem>`. Errors propagate as `NetworkFailure`.
- `activityFeedProvider`: `FutureProvider<List<FeedItem>>` that watches `friendIdsProvider` (from U4) + `currentUserProvider` and refetches when either changes or after the user posts a reaction / comment.

**Patterns to follow:**
- M1 `CatchesRepository.getFriendsCatches` for the friends-list-driven query shape.

**Test scenarios:**
- Happy path: returns up to 50 catches in caught_at desc order.
- Happy path: each item's `reactionCounts` aggregates correctly (e.g. catch with two 🎣 + one 🔥 reports `{rod: 2, fire: 1}`).
- Happy path: `myReaction` is non-null only when the current user has reacted to that catch.
- Happy path: `commentCount` excludes soft-deleted comments.
- Edge case: empty friend list returns only own catches.
- Edge case: catches with `secret_spot=true` and a non-self angler have `location == null`.
- Error path: Postgrest error from any of the three sub-queries surfaces as `NetworkFailure`.

**Verification:**
- All scenarios green; `flutter analyze` clean.

---

- U7. **Trip create / view UI — start, view, end**

**Goal:** Catch-Log gets a "Start a Trip" entry point above the photo target. Active trip surfaced as a banner across the top of Catch-Log + Catches tabs. New `/trips/:id` screen renders the Trip detail (cover photo, title, water, dates, totals, list of catches, companions placeholder).

**Requirements:** R4, R5.

**Dependencies:** U2, U3, U6.

**Files:**
- Create: `lib/features/trips/application/trip_controller.dart`
- Create: `lib/features/trips/presentation/start_trip_sheet.dart`
- Create: `lib/features/trips/presentation/active_trip_banner.dart`
- Create: `lib/features/trips/presentation/trip_detail_screen.dart`
- Create: `lib/features/trips/presentation/widgets/trip_summary_card.dart`
- Modify: `lib/features/catches/presentation/catch_log_screen.dart` (banner + start-trip CTA)
- Modify: `lib/features/catches/application/save_catch_controller.dart` (forward `tripId` to repo when active trip exists)
- Modify: `lib/core/router/app_router.dart` (add `/trips/:id`)
- Test: `test/features/trips/application/trip_controller_test.dart`
- Test: `test/features/trips/presentation/trip_detail_screen_test.dart`

**Approach:**
- `TripController` (`AsyncNotifier<void>`): `start({title, bodyOfWater})`, `end()`. Exposes the active-trip stream via the existing `activeTripProvider`.
- `StartTripSheet` is a bottom sheet with two fields (Title, Body of Water) + Start button.
- `ActiveTripBanner` watches `activeTripProvider`. When active: shows trip title + count of catches today + "End Trip" link (with confirm). When inactive: hidden.
- Catch-Log adds an entry above the photo target: when no active trip → "Start a Trip" outlined button that opens `StartTripSheet`. When active → banner with the active trip name + "Catches saved here will join the trip."
- `TripDetailScreen` reads `tripByIdProvider.family<Trip?, String>`. Renders cover photo (first catch's first photo via `signedUrlProvider`), trip headline, summary stats (count, total weight, top species — derived client-side), a vertical list of `CatchCard`s.
- Save flow: `SaveCatchController.submit` reads `activeTripProvider` before calling `repo.create` so the saved catch attaches to the active trip when present.

**Patterns to follow:**
- `lib/features/catches/presentation/catch_log_screen.dart` for chrome.
- M1 hero-tagged `CatchCard` reuse on the trip detail screen.

**Test scenarios:**
- Happy path: tapping Start a Trip with valid input transitions banner to active state.
- Happy path: a catch saved while active stamps `trip_id` on the catch row.
- Happy path: ending the trip clears the banner; subsequent saves are standalone.
- Edge case: starting a second trip while one is active surfaces the controller's `ValidationFailure` as a snackbar.
- Edge case: trip detail with zero catches yet shows "Catches will appear as you log them."
- Edge case: trip with multiple catches uses the first's first photo as the cover.

**Verification:**
- After Save in U7, the catch detail (M1) shows the trip banner if attached. Tapping the banner navigates to `/trips/:id`.

---

- U8. **Activity Feed UI on the Home tab**

**Goal:** Replace the M0 / M1 Recent Catches placeholder card with a real, scrollable Activity Feed of `FeedItem`s, each rendered as a slightly-expanded `CatchCard` with author header (avatar + handle) + reaction/comment row at the bottom.

**Requirements:** R6.

**Dependencies:** U6, U9 (reaction/comment widgets — but the feed renders them as a leaf so U9 is technically a sibling unit; we can land U8 with a stubbed reactions row that U9 fills in if dependency ordering becomes painful).

**Files:**
- Create: `lib/features/feed/presentation/feed_item_card.dart`
- Create: `lib/features/feed/presentation/widgets/feed_item_header.dart`
- Modify: `lib/features/home/presentation/home_screen.dart` (replace `_RecentCatchesPlaceholder` + `_EmptyRecentCatches` with the live feed; keep stat tiles)
- Test: `test/features/feed/presentation/feed_item_card_test.dart`
- Test: `test/features/home/home_screen_test.dart` (extend to assert feed rendering)

**Approach:**
- `FeedItemCard` composes the existing M1 `CatchCard` (photo + species pill + meta) and adds:
  - Header strip (author avatar + handle + caught_at relative time + "(your catch)" badge if it's mine).
  - Footer row (reactions + comment count) — the reactions row is the U9 widget, placed here by composition.
- The Home tab below the stat tiles becomes a sliver list of `FeedItemCard`s. Pull-to-refresh invalidates `activityFeedProvider`. Empty state ("No catches in your feed yet — log one or add a friend") only shown when both my catches and friends' catches are empty.
- Stat tiles (M0/U3 + M1/U5) stay above; the feed scrolls with them as one column.

**Patterns to follow:**
- `lib/features/catches/presentation/widgets/catch_card.dart` for tile layout.
- `lib/features/home/presentation/home_screen.dart` for the existing AsyncValue handling pattern.

**Test scenarios:**
- Happy path: feed of 3 items renders 3 cards with correct authors.
- Happy path: own catch shows "(your catch)" badge.
- Happy path: tapping a card pushes `/catches/:id`.
- Edge case: empty feed shows the friendly empty-state with a "Find anglers" CTA that pushes the Friends tab.
- Edge case: friend's catch with `secret_spot=true` has no location row in the card.
- Error path: feed-load failure surfaces an inline error tile with Retry.

**Verification:**
- After signing in with two test users who are friends, both see each other's catches on Home.

---

- U9. **Reactions + comments — full UI: react picker, reaction count row, comment list, comment composer**

**Goal:** Render reactions + comments inline on `FeedItemCard` (in the feed) and at the bottom of the catch detail screen. Tapping a reaction kind toggles it for the current user with optimistic update; the comment composer commits a row and refreshes the comment list.

**Requirements:** R7, R8.

**Dependencies:** U2, U6, U8 (the feed card is where the reaction strip lives).

**Files:**
- Create: `lib/features/feed/data/reactions_data_source.dart`
- Create: `lib/features/feed/data/reactions_repository.dart`
- Create: `lib/features/feed/data/comments_data_source.dart`
- Create: `lib/features/feed/data/comments_repository.dart`
- Create: `lib/features/feed/data/feed_writers_provider.dart`
- Create: `lib/features/feed/application/reaction_controller.dart`
- Create: `lib/features/feed/application/comment_controller.dart`
- Create: `lib/features/feed/presentation/widgets/reaction_strip.dart`
- Create: `lib/features/feed/presentation/widgets/reaction_picker_sheet.dart`
- Create: `lib/features/feed/presentation/widgets/comment_list.dart`
- Create: `lib/features/feed/presentation/widgets/comment_composer.dart`
- Create: `lib/features/feed/presentation/widgets/comment_body_text.dart`
- Modify: `lib/features/catches/presentation/catch_detail_screen.dart` (mount comment list + composer at the bottom)
- Modify: `lib/features/feed/presentation/feed_item_card.dart` (mount reaction strip + comment count chip)
- Test: `test/features/feed/application/reaction_controller_test.dart`
- Test: `test/features/feed/application/comment_controller_test.dart`
- Test: `test/features/feed/presentation/widgets/comment_body_text_test.dart`

**Approach:**
- `ReactionsRepository.toggle(catchId, kind)`: fetches the user's existing reaction (cached on FeedItem), then upserts (different kind) or deletes (same kind). Returns the new state for optimistic UI.
- `CommentsRepository.post(catchId, body)`: validates body is non-empty + ≤ 2000 chars, inserts.
- `CommentsRepository.softDelete(commentId)`: updates `deleted_at` (only succeeds for author per RLS).
- `ReactionController` and `CommentController` are `AsyncNotifier<void>` with `submit` / `toggle` methods.
- `ReactionStrip` (the row at the bottom of the card) shows up-to-3 active kinds with their counts; tap any chip to toggle, tap a "+" chip to open the picker sheet for the full set.
- `ReactionPickerSheet` is a bottom sheet with the five emojis at large size; tap → toggle → close.
- `CommentList`: chronological list, shows author handle + body (with `@mention` highlighting) + relative timestamp + tombstone "[deleted]" placeholder for soft-deleted rows. Self-authored rows get a delete affordance.
- `CommentComposer`: text field + Send button at the bottom of the catch detail. Disabled while in flight.
- `CommentBodyText` widget detects `@\w{3,30}` and renders those substrings styled (semibold, primary color). Tap is a no-op in M2; M2.5 wires the friend-profile route.

**Patterns to follow:**
- M1 `SaveCatchController` for AsyncNotifier shape.
- M0/M1 widget tests use `pump()` rather than `pumpAndSettle()` when network images load.

**Test scenarios:**
- Happy path: toggling 🎣 on a catch I haven't reacted to → row inserted; UI shows 🎣 with count 1.
- Happy path: tapping 🎣 again → row deleted; UI count drops.
- Happy path: tapping 🔥 when I had 🎣 → row updated; UI flips to 🔥 with same total count.
- Happy path: posting a comment "Nice fish @silentfisher100" inserts row; comment renders with `@silentfisher100` highlighted.
- Happy path: deleting my own comment renders "[deleted]" tombstone; the underlying row keeps its created_at.
- Edge case: empty comment body cannot be submitted (Send button disabled until `body.trim().isNotEmpty`).
- Edge case: comment body 2001 chars rejected with snackbar; 2000 succeeds.
- Error path: reaction toggle fails → optimistic update reverts + snackbar.
- Error path: trying to delete someone else's comment is filtered by RLS → repository raises `AppException` mapped from PostgrestException.

**Verification:**
- Sign in as A. Friend's catch on the feed → tap 🎣 → row shows count 1 → switch to friend's account → see the reaction notification row in `notifications` table (UI for it lands in M6).
- Sign in as A → catch detail of friend's catch → post comment → switch user → see comment + notification row.

---

## System-Wide Impact

- **Interaction graph:** `friendIdsProvider` becomes the dependency root for the feed; invalidating it (after friend accept/reject/remove) cascades into `activityFeedProvider`. Reaction / comment toggles invalidate just `activityFeedProvider` (cheap re-fetch, page-1 only).
- **Error propagation:** repository layer continues to map Supabase exceptions into `AppException` subclasses. Controllers surface them via `AsyncError.error.message` exactly like M1's `SaveCatchController`. Optimistic updates always carry their own rollback.
- **State lifecycle risks:** the partial-unique-index-driven single-active-trip rule is the new invariant of M2. If a second device starts a trip while the first is open, the second insert raises and the controller surfaces a friendly error — verified in U3 tests.
- **API surface parity:** no public APIs change. The schema gains four tables and one column; views recreated; RLS extended.
- **Integration coverage:** U10 (new in this list — see below) extends the M1 RLS integration test to assert the new tables hold the friends-only contract.
- **Unchanged invariants:** `0001_init.sql` friendships RLS, `0002` storage policies, M0–M1 catch-create / catch-read / signed-URL paths all stay intact. Trip-attached catches still go through the same upload-before-insert ordering from `docs/solutions/2026-05-01-catch-persistence.md` — only the inserted row gains an extra column.

---

- U10. **Extend friends-only RLS integration test for trips, reactions, comments**

**Goal:** Add four assertions to the existing `test_integration/friends_only_rls_test.dart`:
- Friend C reads A's trip; stranger B does not.
- Friend C can react to A's catch; stranger B's insert is blocked by RLS.
- Friend C can comment on A's catch; stranger B's insert is blocked.
- Reaction insert by friend C produces a `notifications` row owned by A.

**Requirements:** R3, R7, R8, R10.

**Dependencies:** U1, U3 (data source — used as a write helper), U6 (also for read).

**Files:**
- Modify: `test_integration/friends_only_rls_test.dart`

**Approach:**
- Reuse the existing test setup (3 users, friendship between A↔C, no relation A↔B). Add a `setUpAll` helper that sets up an A-owned trip the new tests can read.
- Each new test signs in, attempts the operation, then asserts row counts via direct Postgrest reads.
- Tear-down extends to delete trips + reactions + comments touched by the test.

**Execution note:** Test-first — write the four assertions before declaring U10 complete; the surface only earns its existence by proving the contract.

**Patterns to follow:**
- The four tests already in `test_integration/friends_only_rls_test.dart` from M1/U8.

**Test scenarios:**
- Covers R10 / R3. Friend C reads A's trip row; stranger B sees zero rows.
- Covers R10 / R7. Friend C inserts a reaction on A's catch; stranger B's insert raises a Postgrest RLS denial.
- Covers R10 / R8. Friend C inserts a comment on A's catch; stranger B's insert raises a denial.
- Covers R9. Friend C's reaction triggers a `notifications` row whose `recipient_id = A.id` and `kind = 'reaction'`.

**Verification:**
- `FWF_INTEGRATION=true flutter test test_integration/friends_only_rls_test.dart` green for all eight assertions (M1 four + M2 four).

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Single-active-trip invariant could be violated by a buggy controller writing two rows in parallel. | Partial unique index makes the second insert raise; controller test U3 covers this explicitly. |
| Feed query performance at v2 friend-graph sizes (100+ friends, thousands of catches) is unknown. | M2 limits to last 50 + relies on caught_at btree. Pagination + indexed counts are a follow-up. |
| Optimistic reaction toggle creates a flicker if Supabase rejects (e.g. rate-limit). | Controller rollback + snackbar; tested explicitly in U9. |
| Comment soft-delete rows accumulate forever. | Acceptable for v1 — comments are cheap. Add a periodic purge in a M6+ task if storage matters. |
| `@mention` regex over-matches (e.g. emails). | Restrict to `@\w{3,30}` (matches profiles.username CHECK). Tested in U9. |
| Multi-device active trip collision. | Surface as `ValidationFailure`; UX shows a "you have an active trip on another device" message. |
| RLS triggers create circular notifications (A reacts to A's own catch → notifies A). | Trigger explicitly skips when `actor == owner`. Verified in U1 test scenarios. |

---

## Documentation / Operational Notes

- After M2 lands, `docs/SUPABASE_SETUP.md` adds `0005_trips_and_social.sql` to the run-list.
- `README.md` "Feature status" table flips Trips, Activity Feed, and Friends rows to ✅ M2.
- Capture a new learning entry `docs/solutions/2026-05-XX-feed-aggregates-pattern.md` after U6 lands — the pattern of (single primary query + N aggregate queries keyed off the result ids) will be reused for tournament leaderboards in M3 and stats in M4.
- Update `docs/solutions/2026-05-01-catch-persistence.md` with a "trips extension" note documenting that the same upload-before-insert pattern holds when a `trip_id` is included on the insert row.

---

## Sources & References

- **Origin document:** `docs/brainstorms/fishing-with-friends-v1-requirements.md`
- **Predecessor plans:** `docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md` (M2 sketch in Phased Delivery), `docs/plans/2026-05-01-002-feat-m1-catch-persistence-plan.md` (data-layer + Riverpod patterns reused).
- **Related code:** `lib/features/catches/data/catches_repository.dart`, `lib/features/catches/application/save_catch_controller.dart`, `lib/features/friends/presentation/friends_screen.dart`, `supabase/migrations/0001_init.sql` (friendships + RLS), `supabase/migrations/0004_catch_metadata.sql` (view-recreate pattern).
- **Visual references:** `Assests/Screenshot 2026-05-01 134240.jpg` (Friends tab — username display + search + friends list shape that M2 builds out).
