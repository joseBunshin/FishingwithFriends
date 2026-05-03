---
title: "feat: M3 — Live Tournaments end-to-end"
type: feat
status: active
date: 2026-05-01
origin: docs/brainstorms/fishing-with-friends-v1-requirements.md
---

# feat: M3 — Live Tournaments end-to-end

## Summary

Build the full live-tournament loop: creators set up a tournament with rules and side pots, members join (invite or join-by-code), members submit existing catches as entries, creators approve members and entries, and a Supabase Realtime-backed leaderboard reorders for everyone watching as approvals roll in. A per-tournament chat thread and four phase states (Registration → Live → Closed) round out the experience. This is the second half of the v1 wedge — once it ships alongside M2's storytelling, the friends-only social loop and the competitive hook are both real.

---

## Problem Frame

After M2, friends can see each other's catches and react. But the *competitive* hook the wedge bet on is still placeholder: the Tourneys tab is a static card list, there's no way to create or join a tournament, and the spec's "leaderboard reordering live as catches submit" exists only on paper. M3 closes this loop and lights up the second growth surface: tournament invites are the single biggest reason to drag a friend into the app (see origin: Product Thesis, Goal 3).

---

## Requirements

- R1. A creator can set up a tournament with title, description, body of water, start/end timestamps, scoring metric (Total Weight | Biggest Fish | Most Catches | Longest Catch), optional species filter, and optional side pots.
- R2. A creator can invite friends; friends receive a pending membership row and a notification.
- R3. Anyone with the join code can request to join a tournament; the creator approves or rejects (RLS prevents creator self-approval — already in `0001_init.sql`).
- R4. A signed-in member can submit an existing catch they own as a tournament entry; the entry's catch metadata is denormalized at submission (so non-friend tournament fellows can read it without weakening catches RLS).
- R5. The creator approves or rejects each entry; only approved entries count toward the leaderboard.
- R6. The leaderboard reorders in real time as approvals land — for every viewer, not just the actor — via a Supabase Realtime subscription on `tournament_entries`.
- R7. A tournament has 0..N side pots, each with its own scoring metric and optional species filter; each side pot has its own leaderboard computed from the same approved-entries dataset.
- R8. A tournament chat thread is members-only, real-time, and supports flat soft-deletable messages (mirrors M2 comments).
- R9. A tournament has three phases derived client-side: **Registration** (`now < starts_at`), **Live** (`starts_at ≤ now ≤ ends_at` and not `is_closed`), **Closed** (`now > ends_at` OR `is_closed = true`). Members can only submit entries during Live.
- R10. New notification kinds capture tournament events: `tournament_invite`, `tournament_member_approved`, `tournament_member_rejected`, `tournament_entry_approved`, `tournament_entry_rejected`. Trigger functions write rows; bell UI lands in M6.
- R11. Friends-only RLS continues to hold for catches; tournament visibility is the *only* path that lets a non-friend read another angler's submitted catch (and even then only the snapshot fields denormalized onto `tournament_entries`).
- R12. App still passes `flutter analyze` clean and `flutter test` green; the integration suite extends the M1+M2 contract proof with tournament assertions.

**Origin actors:** A1 Recreational angler, A2 Tournament participant (primary for M3), A3 Tournament creator (primary for M3), A4 Admin (untouched by M3).

---

## Scope Boundaries

### Deferred for later

*(Carried verbatim from origin — product/version sequencing.)*

- Photo species ID, voice-note transcription, **tournament brackets / divisions** (v1.5).
- Community water reports, public spots, web release, admin dashboard (v2).
- AI lure / depth / time suggestions, Apple Watch / Wear OS, Reels-style feed (v3).

### Outside this product's identity

*(Carried verbatim from origin — positioning rejection.)*

- Public network / public catch feed.
- Marketplace or in-app gear sales.
- Fishing-license tracking or regulation enforcement.
- **Prize disbursement or payments inside tournaments** (regulated, defer indefinitely).

### Deferred to Follow-Up Work

*Plan-local — implementation work intentionally split into other M-plans.*

- **Recurring tournaments** ("every Saturday on Lake Michigan" auto-creates the next instance) — origin doc surfaces this; M3 ships single-instance only. Add a `recurrence` column and a Supabase scheduled function in M3.5.
- **Tournament cover photo** (auto = first approved entry's photo) — origin lists this; nice-to-have but defer to a polish PR.
- **Bell + push notifications** — M6. M3 only writes rows.
- **Realtime presence** ("🟢 fishing now" indicator next to active anglers) from origin — needs a separate presence channel; defer until M3 lands and we see if the UX needs it.
- **Tournament-shaped catch-log shortcut** ("log a catch into this tournament directly") — M3 requires submitting an existing catch. Direct-into-tournament logging is a UX shortcut for v1.5.
- **Brackets / divisions** (carried from origin's Deferred for later).
- **Public-link unfurl for join-by-code** — M3 generates the code; sharing is plain copy/paste. A `https://fwf.app/t/<code>` deep link is M7 onboarding polish.
- **Editing / deleting tournament after creation** — M3 lets the creator only update `is_closed` to end early. Title / dates / metric edits are deferred; if the creator gets it wrong, they delete and recreate.

---

## Context & Research

### Relevant Code and Patterns

- `supabase/migrations/0001_init.sql` — `tournaments`, `tournament_members`, `tournament_entries` tables and RLS already exist. M3 *extends* the schema (denormalization columns, side pots, chat, join_code) rather than replacing it.
- `supabase/migrations/0005_trips_and_social.sql` — pattern for adding tables + RLS + notification triggers in a single transaction. Reused.
- `lib/features/catches/data/catches_repository.dart` + `catches_data_source.dart` — Repository / DataSource split. M3 mirrors for tournaments / entries / chat.
- `lib/features/feed/data/feed_repository.dart` — the (single primary query + N aggregate queries keyed off the result ids) pattern. Side-pot leaderboard reuse.
- `lib/features/feed/application/reaction_controller.dart` — `AsyncNotifier<void>` with optimistic mutation + invalidation. Pattern reused for tournament actions.
- `lib/features/trips/presentation/active_trip_banner.dart` — banner pattern reused for tournament phase banner.
- `lib/features/feed/presentation/widgets/comment_list.dart` — comment list + composer pattern reused for tournament chat.
- `lib/core/supabase/supabase_providers.dart` — `supabaseClientProvider` is the entry point for the new Realtime channels.
- `lib/features/tournaments/presentation/tournaments_screen.dart` — current placeholder. M3 rewrites.

### Institutional Learnings

- `docs/solutions/2026-05-01-catch-persistence.md` — atomic-insert-with-attached-media pattern. Reused conceptually for tournament-entry submission: denormalize the catch fields onto the entry row at submission so the row is self-sufficient for tournament-fellow reads.

### External References

- Supabase Realtime Postgres Changes — `client.channel(name).onPostgresChanges(...).subscribe()` pattern. Filter by `eq` on `tournament_id`. The supabase_flutter package version ≥ 2.8 (already in pubspec) supports it natively. No external doc dispatch — local pattern is sufficient.
- Tournament chat is functionally identical to M2 comments at the data layer; only the parent FK changes (catch_id → tournament_id).

---

## Key Technical Decisions

- **Denormalize tournament_entries with snapshot fields** (`species_label`, `weight_kg`, `length_cm`, `photo_path`, `caught_at`). Cleanest way to expose the leaderboard to a non-friend tournament fellow without weakening `catches` RLS. Bonus: late edits to a catch don't retroactively change tournament standings — submission is a commitment.
- **Tournament phases are derived client-side**, not stored. `now < starts_at` → Registration; `starts_at ≤ now ≤ ends_at` and not `is_closed` → Live; otherwise Closed. The DB only carries the timestamps + a creator-toggleable `is_closed` boolean. Avoids backend cron + state-drift between scheduler and reality.
- **Single-leaderboard-per-tournament + N side-pot leaderboards**, all computed client-side from the approved-entries list. The same dataset feeds the main board (per `tournaments.metric`) and each side pot (per `tournament_side_pots.metric`). One read, many views.
- **Realtime: two channels per tournament detail screen** — one on `tournament_entries`, one on `tournament_chat_messages`. Each filters by `tournament_id` server-side. Channels tear down on screen dispose.
- **Realtime is additive — initial fetch still required**. The Realtime stream emits *changes*; we always do a `select * where tournament_id=…` first and merge events on top. (This is the supabase_flutter idiom — Realtime is not a replacement for read.)
- **Join code is 6-char uppercase hex**, generated server-side via a default expression on `tournaments.join_code`. Visible to creator only by RLS; copy-to-clipboard surfaces it for sharing.
- **Member-approval and entry-approval go through `update tournament_members.status` / `update tournament_entries.status`** — two simple state machines. Existing RLS in `0001` already prevents creators from self-approving (`creator_id <> tournament_members.angler_id`).
- **Tournament chat soft-deletes match M2 comments** — `deleted_at` nullable timestamp; tombstone renders inline.
- **Notification triggers extend the existing pattern** from `0005_trips_and_social.sql` — `security definer` functions inserting into `notifications` with kind enums extended in the same migration.
- **No optimistic UI for entry approval** — creator approves a catch, the leaderboard reorders for everyone after the round-trip. Optimistic is for self-actions (own reaction, own join request); approvals affect *other people's* visible state and shouldn't lie.

---

## Open Questions

### Resolved During Planning

- *Where does entry catch metadata live for non-friend tournament fellows?* → denormalized onto `tournament_entries` at submission.
- *How does the leaderboard recompute on approval?* → Realtime channel emits the row update; client merges into local list; client recomputes the sort.
- *Phases: stored or derived?* → derived client-side. `is_closed` is the only stored override.
- *Public tournaments?* → no, but join-by-code achieves the same outcome without a discovery surface (safer privacy).
- *Multiple side pots scoring against the same metric as the main board?* → allowed but pointless; UI will warn but not block.
- *Optimistic UI for member / entry approval?* → no. Optimistic is reserved for self-actions where the user owns the truth.
- *Can a creator submit their own catches as entries?* → yes, but RLS still prevents them from approving their own entry (creator_id <> entry.angler_id check).

### Deferred to Implementation

- *The exact channel name format.* `tournament:<id>:entries` vs `tournament:<id>` with table filter — settle when wiring U5.
- *Whether the Tournaments list shows past/closed tournaments by default or only active ones.* Decide once we see how cluttered it gets in dev.
- *Reconnection behavior when the device sleeps and the Realtime channel drops.* `supabase_flutter` auto-reconnects, but verify behavior on web first; if it's flaky, fall back to refetch-on-resume.

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
Tournament lifecycle (state diagram)
─────────────────────────────────────────────────────────────────

   ┌──────────────────────────────────────────────────────────┐
   │ Registration  (now < starts_at)                          │
   │                                                          │
   │  - Creator invites friends → tournament_members(pending) │
   │  - Anyone with code requests join → ditto                │
   │  - Creator accepts / rejects (RLS-blocks self-approve)   │
   │  - No entries can be submitted yet                       │
   └─────────────────────────────────┬────────────────────────┘
                                     │  starts_at reached
                                     ▼
   ┌──────────────────────────────────────────────────────────┐
   │ Live  (starts_at ≤ now ≤ ends_at, not is_closed)         │
   │                                                          │
   │  - Accepted members submit entries (catch_id → entry)    │
   │  - Snapshot of catch metadata copied onto entry row      │
   │  - Creator approves / rejects each entry                 │
   │  - Realtime channel pushes status changes to all viewers │
   │  - Leaderboard sort recomputed on each event             │
   │  - Side pots use the same dataset, different metric/filter│
   │  - Members chat in tournament thread                     │
   └─────────────────────────────────┬────────────────────────┘
                                     │  ends_at OR creator sets is_closed
                                     ▼
   ┌──────────────────────────────────────────────────────────┐
   │ Closed  (now > ends_at OR is_closed)                     │
   │                                                          │
   │  - No new entries; submit button is disabled             │
   │  - Final standings display; podium animation             │
   │  - Chat remains readable (and writable in v1 — debatable)│
   └──────────────────────────────────────────────────────────┘


Realtime data flow
─────────────────────────────────────────────────────────────────

  Tournament Detail screen mounts
            │
            ├─► initial fetch: TournamentEntriesRepository.listForTournament(t)
            │     → List<Entry> (approved + pending)
            │
            ├─► subscribe: supabase.channel('tournament:<t>:entries')
            │     .onPostgresChanges(table='tournament_entries',
            │                        filter='tournament_id=eq.<t>')
            │     → emits INSERT / UPDATE / DELETE payloads
            │
            └─► subscribe: supabase.channel('tournament:<t>:chat')
                  .onPostgresChanges(table='tournament_chat_messages',
                                     filter='tournament_id=eq.<t>')
                  → emits INSERT / UPDATE / DELETE payloads

  TournamentLiveStateNotifier (StateNotifier)
            │
            ├─ apply each Realtime event to local List<Entry>
            ├─ recompute leaderboard sort by tournament.metric
            ├─ recompute each side-pot leaderboard
            └─ widget rebuilds via Riverpod

  Screen unmount → channels.unsubscribe()


Schema delta (M3)
─────────────────────────────────────────────────────────────────

  tournaments
    + join_code text not null default lpad(to_hex((random()*4294967295)::bigint), 8, '0')
    + is_closed boolean not null default false

  tournament_entries
    + species_label text          -- snapshot at submit
    + weight_kg numeric(6,2)
    + length_cm numeric(6,2)
    + photo_path text             -- first photo, displayed on leaderboard
    + caught_at timestamptz
    + status enum('pending', 'approved', 'rejected') default 'pending'

  tournament_side_pots (new)
    id uuid pk
    tournament_id uuid fk -> tournaments
    name text
    metric tournament_metric  (existing enum + new 'biggest_single' value)
    species_filter text     -- nullable, scopes to that species_label
    created_at timestamptz

  tournament_chat_messages (new)
    id uuid pk
    tournament_id uuid fk -> tournaments
    author_id uuid fk -> profiles
    body text (1..2000)
    deleted_at timestamptz nullable
    created_at timestamptz
    updated_at timestamptz

  notification_kind enum + values:
    'tournament_invite', 'tournament_member_approved',
    'tournament_member_rejected', 'tournament_entry_approved',
    'tournament_entry_rejected'

  Triggers (notification writes):
    AFTER INSERT on tournament_members status='pending'
       → notify addressee 'tournament_invite'
    AFTER UPDATE on tournament_members status pending → accepted/rejected
       → notify angler (skip if angler_id == creator_id)
    AFTER UPDATE on tournament_entries status pending → approved/rejected
       → notify angler (skip if angler_id == creator_id)
```

---

## Implementation Units

- U1. **Migration `0006` — denormalize entries + chat + side pots + triggers**

**Goal:** Extend the existing tournament tables with snapshot columns + status, add the two new tables, extend the notification_kind enum, write five trigger functions, recreate any affected views.

**Requirements:** R1, R2, R3, R4, R5, R7, R8, R10, R11, R12.

**Dependencies:** None (extends `0001_init.sql` + `0005_trips_and_social.sql`).

**Files:**
- Create: `supabase/migrations/0006_tournaments_realtime.sql`

**Approach:**
- `alter table tournaments` — add `join_code text not null default lpad(to_hex((random()*x'FFFFFFFF'::bigint)::bigint), 8, '0')`, `is_closed boolean not null default false`. Add unique index on `(join_code)`.
- `alter table tournament_entries` — add `species_label text`, `weight_kg numeric(6,2)`, `length_cm numeric(6,2)`, `photo_path text`, `caught_at timestamptz`, `status text check (status in ('pending','approved','rejected')) not null default 'pending'`.
- `create table tournament_side_pots(...)` with FK + RLS mirroring tournaments policies (visible to creator + accepted members; insert/update/delete by creator only).
- `create table tournament_chat_messages(...)` with FK + RLS (members + creator can read; author writes; author soft-deletes via update on `deleted_at` only).
- Extend `notification_kind` enum with the five new values inside a `do $$ begin if not exists ... add value end $$;` block (PG12+ allows this in a transaction; new values aren't usable in same transaction but trigger function bodies are resolved at execute time, so trigger creation is safe — pattern from `0005`).
- Trigger functions:
  - `tg_notify_tournament_invite` AFTER INSERT on `tournament_members` when status='pending' → notify addressee.
  - `tg_notify_tournament_member_resolved` AFTER UPDATE on `tournament_members` when status changed pending → accepted | rejected → notify angler.
  - `tg_notify_tournament_entry_resolved` AFTER UPDATE on `tournament_entries` when status changed pending → approved | rejected → notify angler.

**Patterns to follow:**
- `supabase/migrations/0005_trips_and_social.sql` for the transaction shape, RLS DSL, and trigger pattern.

**Test scenarios:**
- Happy path: migration applies cleanly to a project that has run 0001..0005.
- Happy path: `select join_code from tournaments` for a fresh insert returns an 8-char hex string; the unique index rejects a duplicate.
- Happy path: inserting a `tournament_chat_messages` row with body = '' fails the CHECK; body of 2001 chars also fails.
- Happy path: setting `tournament_entries.status` from `pending` to `approved` triggers a notification row for the angler (skipped if angler_id == creator_id).
- Edge case: setting `tournament_entries.status` from `approved` back to `approved` (no-op update) does NOT write a duplicate notification.
- RLS guard: a non-member angler cannot read `tournament_chat_messages` for a tournament they're not in; a fellow accepted member can.
- RLS guard: creator can read all entries for their tournament; non-creator member can read all entries for tournaments where they're accepted.

**Verification:**
- Migration runs green in Supabase SQL Editor.
- `\d tournament_entries` shows the new columns + status; `\d tournament_chat_messages` and `\d tournament_side_pots` exist with RLS enabled.
- Sample DML triggers notification rows in the expected shape.

---

- U2. **Domain models + DTOs for Tournament, Member, Entry, ChatMessage, SidePot**

**Goal:** Immutable domain types + row mappers for the five tournament shapes plus an `EntryStatus` enum and a derived `TournamentPhase` enum.

**Requirements:** R1–R9, R12.

**Dependencies:** U1.

**Files:**
- Create: `lib/features/tournaments/domain/tournament.dart`
- Create: `lib/features/tournaments/domain/tournament_input.dart`
- Create: `lib/features/tournaments/domain/tournament_member.dart`
- Create: `lib/features/tournaments/domain/tournament_entry.dart`
- Create: `lib/features/tournaments/domain/tournament_side_pot.dart`
- Create: `lib/features/tournaments/domain/tournament_chat_message.dart`
- Create: `lib/features/tournaments/domain/tournament_phase.dart`
- Create: `lib/features/tournaments/data/tournament_dto.dart`
- Create: `lib/features/tournaments/data/tournament_member_dto.dart`
- Create: `lib/features/tournaments/data/tournament_entry_dto.dart`
- Create: `lib/features/tournaments/data/tournament_side_pot_dto.dart`
- Create: `lib/features/tournaments/data/tournament_chat_message_dto.dart`
- Test: `test/features/tournaments/domain/tournament_test.dart`
- Test: `test/features/tournaments/domain/tournament_phase_test.dart`
- Test: `test/features/tournaments/domain/tournament_entry_test.dart`

**Approach:**
- `Tournament`: id, creatorId, name, description?, bodyOfWater?, metric (enum: totalWeight | biggestFish | mostCatches | longestCatch | biggestSingle), startsAt, endsAt, joinCode, isClosed, isPublic, createdAt, updatedAt. **Add a `phaseAt(DateTime now)` method** that returns `TournamentPhase` from start/end/is_closed.
- `TournamentInput`: write-side type assembled by the Create Tournament sheet (no id, no createdAt).
- `TournamentMember`: tournamentId, anglerId, status (pending | accepted | rejected), approvedBy?, createdAt, updatedAt.
- `TournamentEntry`: id, tournamentId, catchId, anglerId, status, **denormalized**: speciesLabel?, weightKg?, lengthCm?, photoPath?, caughtAt, submittedAt, approvedAt?, approvedBy?.
- `TournamentSidePot`: id, tournamentId, name, metric, speciesFilter?, createdAt.
- `TournamentChatMessage`: id, tournamentId, authorId, body, deletedAt?, createdAt, updatedAt. `isDeleted` getter.
- `TournamentPhase`: enum `registration | live | closed`. Pure derivation function `phaseFor({startsAt, endsAt, isClosed, now})` for unit testing.

**Patterns to follow:**
- `lib/features/trips/domain/trip.dart` and `lib/features/feed/domain/comment.dart` for the @immutable + manual copyWith pattern.

**Test scenarios:**
- Happy path: each DTO round-trips a representative row.
- Edge case: `TournamentPhase.phaseFor` boundaries — `now == starts_at` → live; `now == ends_at` → live; `now < starts_at` → registration; `now > ends_at` → closed; `is_closed=true` overrides to closed regardless of dates.
- Edge case: `Entry.fromRow` round-trips a row with NULL species_label / weight_kg / photo_path (a snapshot from a catch with no weight).
- Edge case: `EntryStatus` enum unknown string → throws; `tryFromId` returns null.

**Verification:**
- All scenarios green; `flutter analyze` clean.

---

- U3. **`TournamentsRepository` — create, list, get, member approval**

**Goal:** Repository for tournament CRUD + member-side membership operations. `TournamentsDataSource` interface + Supabase impl + Riverpod providers.

**Requirements:** R1, R2, R3, R12.

**Dependencies:** U1, U2.

**Files:**
- Create: `lib/features/tournaments/data/tournaments_data_source.dart`
- Create: `lib/features/tournaments/data/tournaments_repository.dart`
- Create: `lib/features/tournaments/data/tournaments_repository_provider.dart`
- Test: `test/features/tournaments/data/tournaments_repository_test.dart`

**Approach:**
- `TournamentsDataSource`: insertTournament, selectMine (creator OR accepted member), selectById, updateClose (sets `is_closed=true`), insertMember (for invites), insertJoinByCode (looks up tournament by `join_code`, inserts pending member), updateMemberStatus, selectMembersForTournament.
- `TournamentsRepository`: orchestrates. Methods:
  - `create(TournamentInput, anglerId)` → returns Tournament
  - `inviteFriends(tournamentId, anglerIds)` → bulk insert pending members
  - `requestJoin(joinCode)` → look up tournament, insert pending member as caller
  - `approveMember(tournamentId, anglerId)` / `rejectMember(...)` — update status
  - `endTournament(tournamentId)` — set is_closed
  - `getMyTournaments()` — paginated; ordered by phase (Live → Registration → Closed) then by start desc
  - `getById(id)` — single tournament
  - `getMembers(tournamentId)` — list members + their profiles via M2 FriendsDataSource for handle/avatar
- Map PostgrestException to AppException subclasses (NetworkFailure / AuthFailure / ValidationFailure for unique-violation on duplicate member).
- Providers: `tournamentsRepositoryProvider`, `myTournamentsProvider` (FutureProvider), `tournamentByIdProvider.family`, `tournamentMembersProvider.family`.

**Execution note:** Test-first for the join-by-code path (privacy-load-bearing — wrong code shouldn't leak which codes are valid).

**Patterns to follow:**
- `lib/features/trips/data/trips_repository.dart` for repo / data-source split + AppException mapping.
- `lib/features/friends/data/friends_repository.dart` for the bundle-style read that fetches ancillary profile data.

**Test scenarios:**
- Happy path: `create` returns Tournament with `joinCode` populated.
- Happy path: `inviteFriends` inserts N pending member rows.
- Happy path: `requestJoin` with a valid code inserts a pending member for the calling user.
- Happy path: `approveMember` flips status to accepted.
- Happy path: `endTournament` flips `is_closed=true`.
- Error path: `requestJoin` with an unknown code throws `ValidationFailure('No tournament found for that code.')` (do NOT leak whether codes have ever existed).
- Error path: `approveMember` of self raises (RLS); maps to a friendly message.
- Error path: `requestJoin` when already a member raises `ValidationFailure('You\'ve already joined this tournament.')` (unique constraint on `(tournament_id, angler_id)`).
- Edge case: `getMyTournaments` partitions Live before Registration before Closed.

**Verification:**
- All scenarios green; `flutter analyze` clean.

---

- U4. **`TournamentEntriesRepository` — submit, approve, reject + side-pot leaderboard computation**

**Goal:** Submission writes a denormalized snapshot of the catch onto `tournament_entries`. Approve / reject mutate status. Side-pot leaderboards are computed client-side from the approved entries list.

**Requirements:** R4, R5, R6, R7, R12.

**Dependencies:** U1, U2.

**Files:**
- Create: `lib/features/tournaments/data/tournament_entries_data_source.dart`
- Create: `lib/features/tournaments/data/tournament_entries_repository.dart`
- Create: `lib/features/tournaments/data/tournament_entries_repository_provider.dart`
- Create: `lib/features/tournaments/data/tournament_side_pots_data_source.dart`
- Create: `lib/features/tournaments/data/tournament_side_pots_repository.dart`
- Create: `lib/features/tournaments/domain/leaderboard.dart`
- Test: `test/features/tournaments/data/tournament_entries_repository_test.dart`
- Test: `test/features/tournaments/domain/leaderboard_test.dart`

**Approach:**
- `submitEntry(tournamentId, catchId, anglerId)`: read the catch (RLS lets the angler read their own), build a denormalized row (species_label, weight_kg, length_cm, first photo_path, caught_at), insert into `tournament_entries` with status=pending. Tournament's species filter is enforced client-side AND validated server-side via a CHECK that compares the inserted row against `tournaments.species_filter` if non-null. Validation happens before insert; surface ValidationFailure on mismatch.
- `approveEntry(entryId)` / `rejectEntry(entryId)`: update `status` + stamp `approved_by` + `approved_at`. RLS in `0001` already prevents creator self-approval.
- `listForTournament(tournamentId)`: returns all entries (any status) for the tournament; the calling layer filters by status as needed.
- `Leaderboard.compute({entries, metric, speciesFilter?})`: pure function — partition approved-only, group by angler if metric is `total_weight` / `most_catches`, take max if `biggest_fish` / `biggest_single` / `longest_catch`. Returns `List<LeaderboardRow>` sorted descending.
- `TournamentSidePotsRepository.list(tournamentId)`: returns side pot configs.
- The screen later combines: 1 list of entries + N side pot configs + 1 main metric → 1 + N leaderboards.

**Execution note:** Test-first for `Leaderboard.compute` — the sort + group behavior is privacy-irrelevant but result-correctness-load-bearing (a wrong leaderboard discredits the entire feature).

**Patterns to follow:**
- `docs/solutions/2026-05-01-catch-persistence.md` for the snapshot-at-submission rationale.
- `lib/features/feed/data/feed_repository.dart` for the (primary fetch + computed view) pattern.

**Test scenarios:**
- Happy path: `submitEntry` writes a row whose species_label / weight_kg / length_cm / photo_path / caught_at match the source catch.
- Happy path: `Leaderboard.compute(metric: total_weight)` sums approved entries per angler descending.
- Happy path: `Leaderboard.compute(metric: biggest_fish)` returns max weight per angler.
- Happy path: `Leaderboard.compute(metric: biggest_single)` returns the single largest entry across all anglers (used by side pots).
- Happy path: `speciesFilter` excludes entries whose `species_label` doesn't match.
- Edge case: empty entries list → empty leaderboard.
- Edge case: entries with NULL weight are excluded from weight-based metrics but counted in `most_catches`.
- Edge case: ties — two anglers with equal totals — return both at the tied rank, sub-sorted by earliest first-entry timestamp (so the deterministic order doesn't flicker).
- Error path: `submitEntry` for a tournament where the angler isn't an accepted member → RLS denial maps to friendly `AppException`.
- Error path: `submitEntry` with a catch that violates `species_filter` → `ValidationFailure` before the insert is even attempted.

**Verification:**
- All scenarios green; `flutter analyze` clean.

---

- U5. **`TournamentRealtimeService` — Postgres-changes subscription for entries + chat**

**Goal:** Subscribe to two Realtime channels per tournament detail screen and expose them as `Stream<List<TournamentEntry>>` and `Stream<List<TournamentChatMessage>>`. Auto-reconnect; tear down on dispose.

**Requirements:** R6, R8, R12.

**Dependencies:** U2, U4.

**Files:**
- Create: `lib/features/tournaments/data/tournament_realtime_service.dart`
- Create: `lib/features/tournaments/data/tournament_chat_data_source.dart`
- Create: `lib/features/tournaments/data/tournament_chat_repository.dart`
- Create: `lib/features/tournaments/data/tournament_chat_repository_provider.dart`
- Create: `lib/features/tournaments/application/tournament_live_state.dart`
- Test: `test/features/tournaments/application/tournament_live_state_test.dart`

**Approach:**
- `TournamentRealtimeService` exposes two factory methods per tournament: `entriesStream(tournamentId)` and `chatStream(tournamentId)`. Each returns a stream of *patches*: `EntryEvent { type: insert|update|delete, row }`. Subscriptions are owned by the caller (Riverpod's `autoDispose` cleans them up on screen unmount).
- `TournamentChatRepository` mirrors M2 `CommentsRepository`: `post(tournamentId, body)`, `softDelete(messageId)`, `listForTournament(tournamentId)`.
- `TournamentLiveStateNotifier` (StateNotifier) holds `List<TournamentEntry>` for one tournament. Constructor seeds from initial fetch; subscribe to entriesStream and apply patches in-place (replace by id on update, append on insert, remove by id on delete). Riverpod widget rebuilds emit fresh leaderboard renders.
- Channel naming: `tournament:<id>:entries` and `tournament:<id>:chat`. Postgres filter: `tournament_id=eq.<id>`.
- Error path: stream errors (websocket drop) → log, attempt reconnect via supabase_flutter's built-in mechanism. If unrecoverable for >10s, surface a "Reconnecting…" banner via separate provider; UI still renders last-known state.

**Patterns to follow:**
- M2 `feed_repository_provider.dart` for AsyncValue-driven providers. Realtime adds a Stream layer on top.
- supabase_flutter docs for `client.channel(...).onPostgresChanges(...).subscribe()`.

**Test scenarios:**
- Happy path: a fake event stream that emits an insert payload + the initial seed list of 2 entries → notifier state contains 3 entries.
- Happy path: an update payload with a status change from pending → approved → notifier state has the matching entry's status updated, list length unchanged.
- Happy path: a delete payload removes the entry by id.
- Edge case: an update for an entry id not in the list → falls through to insert.
- Error path: stream error doesn't crash; notifier state preserved.
- Integration: replaying 100 events in order produces the same final state as inserting them via DB then fetching.

**Verification:**
- All scenarios green. Manual smoke: open a tournament on two devices; submit + approve on device A; device B leaderboard reorders within ~1s without manual refresh.

---

- U6. **Tournaments tab (list) + Create Tournament sheet**

**Goal:** Replace the placeholder Tourneys tab with a real list of the user's tournaments (creator OR member), partitioned by phase. Plus the bottom-sheet flow for creating a tournament — matches Lovable's Create Tournament screen layout.

**Requirements:** R1, R12.

**Dependencies:** U2, U3.

**Files:**
- Modify: `lib/features/tournaments/presentation/tournaments_screen.dart`
- Create: `lib/features/tournaments/presentation/widgets/tournament_card.dart`
- Create: `lib/features/tournaments/presentation/create_tournament_sheet.dart`
- Create: `lib/features/tournaments/application/tournament_create_controller.dart`
- Test: `test/features/tournaments/presentation/tournaments_screen_test.dart`
- Test: `test/features/tournaments/application/tournament_create_controller_test.dart`

**Approach:**
- `TournamentsScreen`: top FAB or AppBar action opens `CreateTournamentSheet`. Below: section for Live, section for Registration, section for Closed. Each `TournamentCard` shows: name, body of water, dates, phase pill (orange for Live, navy for Registration, grey for Closed), member count, "joined as creator/member" badge.
- `CreateTournamentSheet`: scrollable bottom sheet with fields matching Lovable's Create Tournament form (`Assests/Screenshot 2026-05-01 134202.jpg`): Tournament Name (required), Description, Start Date (required), End Date (required), Location (Body of Water), Scoring Method dropdown, Species Filter (multi-select using the `species` table from M0), Invite Friends list (using friendsBundleProvider). Validate dates (ends after starts, starts ≥ now); orange Create button.
- `TournamentCreateController` (AsyncNotifier<void>) drives the create call + bulk invite. Returns the created tournament on success so the sheet can navigate to it.

**Patterns to follow:**
- `lib/features/trips/presentation/start_trip_sheet.dart` for the bottom-sheet shape.
- `lib/features/catches/presentation/catch_log_screen.dart` for the form-field patterns (DropdownButtonFormField, validators).
- Visual: `Assests/Screenshot 2026-05-01 134202.jpg`.

**Test scenarios:**
- Happy path: tournaments list partitioned into Live / Registration / Closed sections.
- Happy path: Create sheet validates required fields (name, starts, ends).
- Happy path: ends < starts → form validator surfaces "End must be after start."
- Happy path: successful create + invite navigates to `/tournaments/<id>` and invalidates `myTournamentsProvider`.
- Edge case: no friends yet → Invite Friends section shows empty-state nudging Friends tab.
- Edge case: tap a Closed tournament card → routes to detail in Closed-state UI (no submit button).
- Error path: NetworkFailure during create surfaces a snackbar; form data preserved.

**Verification:**
- After creating in dev: card shows under Registration; if the start date has passed, it shows under Live with the orange pill.

---

- U7. **Tournament detail screen — header, phase banner, leaderboard, tabs**

**Goal:** The screen the whole feature converges on. Header (name + body of water + date range), phase banner (Registration / Live / Closed with orange-when-Live styling), main leaderboard, tabs for Members, Entries, Chat, Side Pots. Submit-entry CTA when Live.

**Requirements:** R5, R6, R7, R8, R9, R12.

**Dependencies:** U2, U3, U4, U5.

**Files:**
- Create: `lib/features/tournaments/presentation/tournament_detail_screen.dart`
- Create: `lib/features/tournaments/presentation/widgets/leaderboard_view.dart`
- Create: `lib/features/tournaments/presentation/widgets/tournament_phase_banner.dart`
- Create: `lib/features/tournaments/presentation/widgets/members_tab.dart`
- Create: `lib/features/tournaments/presentation/widgets/entries_tab.dart`
- Create: `lib/features/tournaments/presentation/widgets/chat_tab.dart`
- Create: `lib/features/tournaments/presentation/widgets/side_pots_tab.dart`
- Create: `lib/features/tournaments/application/tournament_member_controller.dart`
- Create: `lib/features/tournaments/application/tournament_entry_controller.dart`
- Modify: `lib/core/router/app_router.dart` — add `/tournaments/:id`.
- Test: `test/features/tournaments/presentation/tournament_detail_screen_test.dart`

**Approach:**
- `TournamentDetailScreen` watches `tournamentByIdProvider.family` + the live entries notifier from U5 (autoDispose so subscriptions tear down on pop).
- Phase banner derived client-side via `Tournament.phaseAt(DateTime.now())`. Live → orange banner with "Submit a catch" CTA. Closed → grey banner. Registration → navy banner with "Tournament starts {relative}" copy.
- `LeaderboardView` consumes the live entries + the tournament's metric and renders ranked rows: rank, angler handle, hero metric value, photo thumbnail. Sort recomputed on every state push.
- **Members tab:** shows accepted members + pending requests. For the creator only: each pending row has Accept / Reject buttons (controller wraps approveMember / rejectMember). Members tab also has a Copy Join Code button on top for the creator.
- **Entries tab:** every entry from the live state. For the creator only: pending entries get Approve / Reject buttons. Otherwise just renders status + thumbnail.
- **Chat tab:** mirrors M2 catch detail comment list — `CommentList` reused but for `tournament_chat_messages`. Composer at the bottom; soft-delete on author rows.
- **Side Pots tab:** lists each `TournamentSidePot` with its own `LeaderboardView` underneath.
- Submit-entry FAB shows on Live phase only when the user is an accepted member; tapping opens U8's submit flow.

**Patterns to follow:**
- `lib/features/catches/presentation/catch_detail_screen.dart` for the SliverAppBar + tab content pattern.
- `lib/features/feed/presentation/widgets/comment_list.dart` for the chat tab.

**Test scenarios:**
- Happy path: registration phase shows navy banner + relative-date copy + no submit button.
- Happy path: live phase shows orange banner + Submit FAB (when accepted member).
- Happy path: closed phase shows grey banner + no Submit FAB regardless of membership.
- Happy path: leaderboard rows ordered by metric descending; first place row gets the gold treatment.
- Happy path: creator sees Approve / Reject buttons on pending entries; non-creator member does not.
- Happy path: chat tab posts a message and the new row appears in the list (tested by feeding a synthetic event into the live state notifier).
- Edge case: tournament has zero entries → leaderboard shows empty state "Be the first to submit."
- Edge case: tournament with one approved + one pending entry — main board shows only the approved.
- Integration: realtime event → leaderboard reorders within the same widget pump.

**Verification:**
- Pixel-comparable to the spec: phase banner colors match plan; leaderboard top row visually distinct; tab bar has 4 tabs labeled correctly.

---

- U8. **Submit Entry flow**

**Goal:** Two entry points → one shared sheet. From the catch detail screen ("Submit to a tournament" button) and from the tournament detail screen ("Submit a catch" FAB). Both lead to a sheet that lists the user's catches matching the tournament's window + species filter, and submits the chosen one.

**Requirements:** R4, R12.

**Dependencies:** U3, U4, U7.

**Files:**
- Create: `lib/features/tournaments/presentation/submit_entry_sheet.dart`
- Create: `lib/features/tournaments/application/submit_entry_controller.dart`
- Modify: `lib/features/catches/presentation/catch_detail_screen.dart` — add "Submit to tournament" overflow action that opens the sheet preselected with that catch.
- Test: `test/features/tournaments/application/submit_entry_controller_test.dart`

**Approach:**
- From tournament detail: sheet shows ALL the user's catches that match the tournament's species_filter (if any) AND fall within `[starts_at, ends_at]` (if Live) — newest first. Tap → confirm → submit.
- From catch detail: sheet shows the user's tournaments where they're accepted, the tournament is Live, the catch's species fits the species_filter, and `caught_at` falls in the window — order Live tournaments first.
- `SubmitEntryController` wraps `TournamentEntriesRepository.submitEntry`; success invalidates the tournament's live state and pops the sheet.
- Validation surfaces:
  - "This catch is outside the tournament window."
  - "This catch's species doesn't match the tournament filter."
  - "You've already submitted this catch to this tournament." (unique constraint on (tournament_id, catch_id) from `0001`).

**Patterns to follow:**
- `lib/features/trips/presentation/start_trip_sheet.dart` for sheet shape.
- `lib/features/feed/application/reaction_controller.dart` for AsyncNotifier mutation pattern.

**Test scenarios:**
- Happy path: from tournament detail, picking a valid catch → submitEntry called with correct id; sheet pops.
- Happy path: from catch detail, the tournament list is filtered to Live, accepted, species-matching, window-matching tournaments.
- Edge case: zero matching catches → sheet shows empty state "No catches match this tournament's window."
- Error path: duplicate submit → ValidationFailure surfaces "Already submitted."
- Error path: tournament closed mid-flow → ValidationFailure "Tournament is no longer accepting entries."

**Verification:**
- Test pass + manual: submit a catch, see the pending entry on the Entries tab; switch user to the creator, approve, see the leaderboard reorder.

---

- U9. **Extend friends-only RLS integration test for tournaments**

**Goal:** Append four assertions to the existing `test_integration/friends_only_rls_test.dart`:
- A non-member angler cannot read tournament_chat_messages for a tournament they're not in.
- A non-friend tournament fellow CAN read another fellow's tournament_entries (via tournament-context visibility).
- A non-friend tournament fellow STILL cannot read the underlying `catches` row directly (friends-only catches RLS holds).
- A creator cannot self-approve their own pending entry (RLS denial maps to PostgrestException).

**Requirements:** R10, R11, R12.

**Dependencies:** U1, U3, U4.

**Files:**
- Modify: `test_integration/friends_only_rls_test.dart`

**Approach:**
- Reuse the existing 3-user setup. Add a fourth helper to create a tournament owned by A and accept B as a member (B is NOT a friend of A). Also create C as A's friend per existing setup.
- Submit a catch by A → submit it as a tournament entry → approve → assert B can read the entry but not the catch.
- All assertions skip when `FWF_INTEGRATION` env var is unset (existing gating).

**Execution note:** Test-first — write the four assertions before touching the data layer they exercise.

**Patterns to follow:**
- Existing M1+M2 tests in `test_integration/friends_only_rls_test.dart`.

**Test scenarios:**
- Covers R10/R11. Non-member B tries to read tournament chat → zero rows.
- Covers R11. Non-friend tournament fellow B reads tournament_entries belonging to A → succeeds (entry visible).
- Covers R11. Same B tries to read the underlying catches.id directly → zero rows (catches RLS unchanged).
- Covers R10. Creator A tries to update their own entry's status → PostgrestException.

**Verification:**
- `FWF_INTEGRATION=true flutter test test_integration/friends_only_rls_test.dart` green for M1+M2+M3 assertions.

---

## System-Wide Impact

- **Interaction graph:** new providers (`myTournamentsProvider`, `tournamentByIdProvider`, `tournamentLiveStateProvider`, `tournamentChatLiveStateProvider`) will be invalidated by mutation controllers. Submitting a tournament entry should invalidate `myCatchesProvider` only if we want to surface a "submitted" badge there (deferred unless the UI calls for it).
- **Error propagation:** tournament repository methods continue to map Postgrest / RLS errors to `AppException`. Realtime errors are non-fatal — they degrade the screen to "Reconnecting…" state without crashing.
- **State lifecycle risks:**
  - Realtime subscription leaks if the screen disposes mid-event. Mitigated by tying channels to autoDispose providers + explicit `unsubscribe` in `ref.onDispose`.
  - Snapshot drift between `tournament_entries.species_label` and `catches.species_label` if the angler edits the catch later. Acceptable in M3 by design — the entry is a commitment.
- **API surface parity:** `notification_kind` enum gains 5 new values. Any future bell UI in M6 must handle them. M3 doesn't render notifications.
- **Integration coverage:** U9 covers the cross-RLS-table contract (catches private but tournament_entries snapshots visible). Mocked unit tests cannot prove this; only the integration suite can.
- **Unchanged invariants:** `0001` friend-only RLS on `catches`, `0002` storage policies, M2 social policies, M2 trips RLS — all preserved. M3 only *adds* a parallel visibility path through tournament membership for the snapshot fields on `tournament_entries`.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Realtime websocket drops on web (Chrome backgrounding the tab). | supabase_flutter auto-reconnects; verify behavior in U5; if flaky, add a refetch-on-resume fallback when the screen regains focus. |
| Leaderboard sort ties cause UI flicker. | `Leaderboard.compute` sub-sorts by earliest entry timestamp deterministically; tested. |
| `random()*4294967295` in the `join_code` default has a tiny collision chance. | Unique index on `join_code` raises on collision; client retries the insert with a fresh code. M3 accepts this as a 1-in-4-billion problem. |
| Creator approves entries faster than realtime propagates → user sees stale data. | UI optimistically updates the *creator's* view on approve; viewers wait for the realtime push (acceptable lag <1s). |
| Snapshot fields drift if catch is edited post-submission. | Accepted tradeoff — the entry is a commitment. Document in `docs/solutions/`. |
| 100+ entries in a single tournament make the leaderboard recompute slow on each Realtime event. | Compute is `O(n log n)` over `n` entries; M3 accepts up to ~500 entries before any optimization. Document the threshold. |
| Tournament with deleted catch (catch dropped from `catches` after entry submission). | Snapshot fields on `tournament_entries` are independent of `catches`; entry remains valid. The thumbnail signed URL may 404 if the photo was also deleted — fall back to placeholder. |

---

## Documentation / Operational Notes

- After M3 lands, `docs/SUPABASE_SETUP.md` adds `0006_tournaments_realtime.sql` + a note that **Realtime must be enabled for `tournament_entries` and `tournament_chat_messages`** in **Database → Replication** for the leaderboard to update live.
- `README.md` "Feature status" table flips Tournaments rows to ✅ M3.
- New `docs/solutions/2026-05-XX-tournament-entry-snapshot.md`: rationale for denormalizing entry fields rather than weakening catches RLS. Future contributors will reach for the obvious "extend RLS" lever otherwise.
- New `docs/solutions/2026-05-XX-supabase-realtime-pattern.md`: the channel-per-tournament + StateNotifier pattern. M4 Stats and M6 Push will reuse the supabase_flutter realtime layer.

---

## Sources & References

- **Origin document:** `docs/brainstorms/fishing-with-friends-v1-requirements.md`
- **Predecessor plans:** `docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md` (M3 sketch), `docs/plans/2026-05-01-002-feat-m1-catch-persistence-plan.md` (data-layer + RLS patterns), `docs/plans/2026-05-01-003-feat-m2-trips-and-feed-plan.md` (notification triggers + chat-style flat collection patterns).
- **Related code:** `supabase/migrations/0001_init.sql` (existing tournament tables + RLS), `supabase/migrations/0005_trips_and_social.sql` (trigger pattern), `lib/features/feed/data/feed_repository.dart` (aggregate-counts pattern), `lib/features/feed/presentation/widgets/comment_list.dart` (tournament chat reuses).
- **Visual reference:** `Assests/Screenshot 2026-05-01 134202.jpg` — Lovable's Create Tournament screen, the layout U6 mirrors.
