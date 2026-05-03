---
title: "feat: M6 — Offline-first + conditions auto-fill + push notifications"
type: feat
status: active
date: 2026-05-01
origin: docs/brainstorms/fishing-with-friends-v1-requirements.md
parent_plan: docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md
---

# feat: M6 — Offline-first + conditions auto-fill + push

## Summary

The infrastructural milestone. Three orthogonal but synergistic features land together:

1. **Offline-first catch logging** — local SQLite store via `drift`, durable outbound queue for catches + tournament entries, photo upload retry. The non-negotiable from origin doc Section H ("boats and remote rivers don't have LTE").
2. **Conditions auto-fill** — Supabase edge function calls Open-Meteo (weather) + NOAA Tides on catch insert and populates `catches.conditions` JSONB. Tide is first-class for saltwater catches; freshwater catches get weather only.
3. **Push notifications** — APNs (iOS) + FCM (Android) via `firebase_messaging`. Wires the existing M2 notification rows + M3 tournament-trigger rows into device pushes for friend requests, tournament invites, entry verifications, and feed highlights.

Branch off `feat/m5-storytelling` as `feat/m6-offline-conditions-push` (stacked-PR pattern). Stop at M6; M7 plans separately.

This is the **highest-risk milestone** per the parent plan. M6 is sequenced after the UI surfaces stabilized in M0–M5 so we don't refactor offline + sync logic twice.

---

## Problem Frame

After M0–M5, the app is feature-complete for online use. Three concrete failure modes still ship:

- **Offline failure.** A user on a boat without LTE opens the app, taps Log, takes a photo, fills the form, hits Save → snackbar "Failed to save catch." They lose the catch they just landed. Origin doc calls this **non-negotiable** for v1.
- **Empty conditions.** Every `catches.conditions` JSONB is `{}`. The catch detail can't say "falling tide, 71°F water" — Stats' M4 conditions correlation card stays a placeholder forever without server-side fill.
- **No retention loop.** Friend requests, tournament invites, and entry verifications fire DB-side notifications (M2 + M3 schemas wrote to `notifications`), but no push reaches the user's lock screen. They open the app to discover something happened — they don't get pulled back in.

Each of these is its own subsystem. Bundled into one milestone because:
- All three are infrastructural (SQLite, edge functions, FCM/APNs config) rather than UI work.
- Conditions auto-fill writes to `catches.conditions` and that needs to survive offline-then-sync (the queue must preserve the conditions field as written client-side, then the server-side trigger overwrites if the conditions are empty — a small contract that's cheaper to design once).
- Push notifications need the offline queue to *not* fire local notifications for queued-but-not-yet-synced events that the server may dedupe.

The bundling is justified, but each subsystem is independently testable and shippable as separate sub-milestones (M6a / M6b / M6c).

---

## Requirements

### Offline-first (M6a)

- R1. Catch logging produces a successful save outcome with no network connection. Photos remain on the device until upload succeeds.
- R2. A durable outbound queue persists across app restarts. Items have status `pending | uploading | failed | synced` and a retry count.
- R3. The local store mirrors enough of the online state for read-side parity offline: my catches, my trips, my friends list, my tournaments. Friend catches are best-effort cached but not durable.
- R4. On reconnection, the sync orchestrator drains the queue in insertion order (FIFO), uploads photos first, then creates the `catches` row, then surfaces any errors as snackbars. Already-synced items don't re-fire.
- R5. Tournament entry submission goes through the same queue when offline.
- R6. A Riverpod provider exposes connectivity state + queue length so UI can surface a non-intrusive "syncing N catches" pill in the app bar when applicable.
- R7. Optimistic UI: a queued catch shows in My Catches grid + Home Feed immediately with a small upload indicator badge until synced.

### Conditions auto-fill (M6b)

- R8. When a catch is inserted with `conditions = '{}'` (default), a Supabase edge function fetches weather (temp, wind, sky from Open-Meteo) and tide (NOAA Tides for saltwater species via `species.water_type`) and writes the result back to `catches.conditions`.
- R9. The edge function runs after the catch insert, not blocking it. Failures are silent (catch keeps `{}`, never error-states the save).
- R10. Catch detail screen renders the conditions block when present (icons + values), hides when empty.
- R11. M4's "Conditions correlation" Stats card flips from placeholder to real once enough catches have non-empty conditions (≥10 same-species catches with conditions).

### Push notifications (M6c)

- R12. iOS push via APNs and Android push via FCM, registered on first sign-in after granting permission.
- R13. The user can grant or skip the permission prompt without breaking app functionality.
- R14. A Postgres trigger on `notifications` insert fires a `pg_net` HTTP POST to a Supabase edge function that resolves the recipient's device tokens and dispatches via `firebase_messaging`'s admin SDK (or equivalent HTTP API).
- R15. Push payload routes to the right in-app surface on tap (e.g., a tournament-invite push opens `/tournaments/:id`).
- R16. Notification preferences screen on Me tab — toggle per-category (Friend requests / Tournament events / Feed highlights) — values persist in a new `notification_preferences` table or as JSONB on `profiles`.

### Cross-cutting

- R17. App still passes `flutter analyze` clean and `flutter test` green after every M6 unit lands.
- R18. Friends-only RLS contract preserved. New tables (`device_tokens`, `notification_preferences`, the outbound queue mirror if any) follow owner-only RLS.
- R19. **No regression of M5 behavior.** Specifically: PR + badge detection still fires on synced catches; the celebration screen still triggers when a queued catch eventually syncs and the trigger writes a PR.

**Origin actors carried forward:** A1 Recreational angler (every M6 surface), A2 Tournament participant (M6c push for entry verifications), A3 Tournament creator (M6c push for member/entry approval requests).

---

## Scope Boundaries

### Deferred for later

*(Carried from origin and parent plan.)*

- **Voice-note transcription** (v1.5).
- **Photo species ID** (v1.5).
- **AI lure / depth / time suggestions** (v3).
- **Apple Watch / Wear OS** companions (v3).
- **Year-in-Review video composition** (v1.5; M5 ships static animated cards).
- All M7 work — onboarding polish, store submission.

### Outside this product's identity

*(Verbatim from origin.)*

- Public network / public discovery.
- Marketplace / in-app gear sales.
- License / regulation enforcement.
- Prize disbursement or in-app payments inside tournaments.

### Deferred to Implementation

- **Conditions API vendor selection between Open-Meteo and NOAA.** Origin doc names both; M6b uses **Open-Meteo for weather (free, no key)** and **NOAA Tides & Currents for US tidal stations (free, no key)**. International tide is deferred — saltwater catches outside the NOAA station footprint get weather only. Implementer documents the chosen station-finder algorithm in U6.
- **Push provider stack — `firebase_messaging` alone or `firebase_messaging` + APNs direct.** `firebase_messaging` handles both iOS and Android via FCM, but iOS requires APNs key registration in Firebase. Implementer picks during U10; the plan defaults to FCM-via-firebase_messaging for both platforms.
- **Drift schema migration shape** — implementer picks one of (a) regenerate full schema each migration via `drift`'s schema versioning, (b) migrate manually via `customStatement`. Drift docs prefer (a). Plan defers to U2.
- **Whether the queue surfaces individual upload errors as toasts or aggregates them into a "Tap to retry" pill.** Implementer decides during U7; default to aggregated pill to avoid notification fatigue.
- **APNs entitlements + push capability provisioning in Xcode** — runbook lives in `docs/IOS_PUSH_SETUP.md` once U10 lands; not a planning artifact.

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/catches/data/catches_repository.dart` — `create()` is the current online-only path. M6a wraps with a queue-aware orchestrator; the existing repo stays intact and is called *by* the new orchestrator.
- `lib/features/catches/application/save_catch_controller.dart` — the controller that `_save()` calls in `catch_log_screen.dart`. M6a swaps its dependency to the queue-aware orchestrator.
- `lib/features/tournaments/application/submit_entry_controller.dart` — same shape; M6a wraps for offline.
- `supabase/migrations/0005_trips_and_social.sql` — created `notifications` table + 4 triggers (friend request / friend accepted / reaction / comment).
- `supabase/migrations/0006_tournaments_realtime.sql` — added 3 more triggers on tournament events.
- M0 plan committed schema column `catches.conditions jsonb default '{}'::jsonb` already in place; M6b just populates it.
- `docs/SUPABASE_SETUP.md` — already documents the Realtime setup and migration runlist; M6 adds edge-function deploy instructions and the FCM/APNs setup runbook.
- M5's `0009` predicate trigger pattern and `tg_evaluate_storytelling_after_catch` shape — M6c reuses the security-definer trigger idiom for `pg_net` notification dispatch.

### Institutional Learnings

- `docs/solutions/2026-05-01-mpa-display-suppression.md` — established bundled-asset offline-first ethos.
- `docs/solutions/2026-05-01-storytelling-server-detection.md` — established server-side trigger as the durable contract surface; M6c follows the same pattern for notification-dispatch triggers.

### External References

- **`drift`** (`^2.20.0+`) — Flutter SQLite ORM. Type-safe queries, schema migrations, reactive streams. Production-tested in major Flutter apps.
- **`connectivity_plus`** (`^6.0.0+`) — first-party-style network state stream. Plus `internet_connection_checker_plus` for actual reachability vs interface-up. M6a uses one or both.
- **`workmanager`** (`^0.5.0+`) — background task scheduler for iOS / Android. M6a uses for queue drain attempts when the app isn't foregrounded.
- **Open-Meteo** (`https://api.open-meteo.com/`) — free, no-key weather API. Past-time + lat/lng → temp, wind, weather code. Documented well; rate-limit generous.
- **NOAA Tides & Currents** (`https://api.tidesandcurrents.noaa.gov/api/prod/`) — free, no-key US tidal stations. Station finder by lat/lng → predicted tide at timestamp.
- **`firebase_messaging`** (`^15.0.0+`) — official Flutter Firebase package. Handles permission, token registration, foreground/background message handlers, tap routing.
- **`flutter_local_notifications`** (`^17.0.0+`) — for in-app foreground notification rendering when FCM delivers while the app is in use.
- **Supabase Edge Functions** — Deno-based, deployed via `supabase functions deploy`. Called via PostgREST RPC or `pg_net` HTTP from triggers.
- **`pg_net`** Postgres extension — async HTTP from triggers without blocking. Already available on Supabase.

---

## Key Technical Decisions

- **`drift` over `sqflite` or `hive`.** Type safety + reactive streams + schema migrations win for a non-trivial offline store. `sqflite` would force hand-rolled type mapping; `hive` is fast but key-value semantics fight a relational mirror of catches+trips+entries.
- **One offline queue, three operation types.** A single `outbox` drift table with `op_type` (catch_create / entry_create / photo_upload), `payload` JSON blob, status, retry count. Avoids three parallel queues; keeps FIFO ordering across operation kinds (so a photo upload that belongs to a queued catch lands first).
- **Photos stored on disk, not in SQLite.** SQLite blob storage for 5+MB images is the wrong tool. `path_provider` directory + filename in the queue payload. Cleaned up after sync confirms.
- **Optimistic UI through a unified read provider.** `myCatchesProvider` returns `[...synced, ...queued]` in one list — UI renders identically except for an upload-indicator badge on queued items. This avoids two parallel "real catches" + "queued catches" lists in every screen.
- **Connectivity = stream-based, not poll.** `connectivity_plus`'s state stream is reactive. Sync orchestrator listens; on transition `none → wifi/mobile`, drain begins. No periodic polling.
- **Conditions auto-fill is server-side only, not client-side.** Two reasons: (a) keeps API keys (or rate-limit-friendly client identity) off-device, (b) survives offline + sync — the catch syncs from queue, the trigger fires, conditions land asynchronously. Client never has to wonder if the API call succeeded.
- **Conditions trigger uses `pg_net` async HTTP, not synchronous.** A blocking HTTP call inside a trigger would push catch insert latency to 500ms+. `pg_net` fire-and-forget pattern returns immediately; the edge function callback writes back to `catches.conditions` via service-role.
- **`firebase_messaging` for both platforms, no APNs direct.** One SDK, one token-registration flow, one server-side dispatch shape. iOS still requires APNs key in Firebase console — that's setup, not code.
- **Notification dispatch trigger separate from the M2/M3 notification-row triggers.** The existing triggers create rows in `notifications`; M6c adds an *additional* AFTER INSERT trigger on `notifications` that calls `pg_net` to the dispatch edge function. Layered, not entangled.
- **`device_tokens` table is owner-only-write (`auth.uid() = user_id`) but service-role-read.** The dispatch edge function uses service role to look up tokens by recipient user id; clients can only register their own.
- **Notification preferences as a row in `notification_preferences`, not JSONB on profiles.** Cleaner RLS shape; supports per-channel toggles without painting the profile row each preference change.

---

## Open Questions

### Resolved During Planning

- *Offline persistence library:* `drift`.
- *One queue or N:* one outbox table, multiple op types.
- *Photo storage on device:* filesystem via `path_provider`.
- *Connectivity:* stream-based.
- *Conditions placement:* server-side via edge function + `pg_net`.
- *Push provider:* `firebase_messaging` for both iOS and Android.
- *Conditions vendor:* Open-Meteo + NOAA Tides (US-only tidal coverage).
- *Notification preferences shape:* dedicated table.

### Deferred to Implementation

- *Drift migration shape* — picked during U2.
- *Whether queued catches show optimistically in friends' feeds before sync* — no. Friends only see synced rows. Documented in U7 test scenarios.
- *Push permission prompt timing* — first sign-in vs after first interaction. Implementer picks during U10; default is after first successful catch save (lower friction than blocking sign-in).
- *Whether the conditions edge function caches recent station lookups in-memory* — defer. First implementation queries NOAA per-call; if rate limit becomes an issue, add a `noaa_station_cache` table.
- *Tide station footprint outside US* — saltwater catches outside the ~200 NOAA stations get weather only. Documented in U5 plan.

---

## High-Level Technical Design

> *Directional guidance. Implementer treats as context, not code to reproduce.*

```
M6 surface graph
─────────────────────────────────────────────────────────────────

Offline-first (M6a):
  CatchLogScreen ──► saveCatchController.submit
                          │
                          ▼
                 catchOfflineOrchestrator.create
                          │
                          ├─ if online + idle:  do CatchesRepository.create directly
                          ├─ if offline:        write to outbox + return optimistic catch
                          └─ if online + queued: enqueue + drain after current ops

  outbox (drift):
    id pk, op_type, payload jsonb, status, retry_count,
    last_attempt_at, created_at

  syncOrchestrator (background isolate via workmanager):
    onConnect: drain FIFO. For each op:
      photo_upload: upload to storage, update payload with returned path
      catch_create: build CatchInput from payload, call repository.create
      entry_create: build entry, call entries_repository.submit
    on success: mark synced, delete after retention
    on failure: increment retry_count, exponential backoff

Conditions auto-fill (M6b):
  catches AFTER INSERT trigger ──► pg_net.http_post(edge_fn_url, payload)
                                          │
                                          ▼
                                  Edge Function (Deno)
                                          │
                                  ├─ Open-Meteo: weather
                                  ├─ NOAA Tides:  tide (saltwater + nearby station)
                                  ├─ moon phase: client-computable, included
                                          │
                                          ▼
                                  service_role UPDATE catches
                                    set conditions = jsonb

  CatchDetail: ConditionsBlock widget renders only when conditions != {}.

Push (M6c):
  Sign-in success ──► registerDeviceForPush
                              │
                              ├─ request permission
                              ├─ obtain FCM token (firebase_messaging)
                              └─ upsert into device_tokens (user_id, token, platform, last_seen)

  notifications AFTER INSERT trigger (M6c) ──►
        pg_net.http_post(dispatch_fn_url, payload: {recipient_id, kind, ...})
                              │
                              ▼
                         Dispatch Edge Function
                              │
                              ├─ select tokens where user_id = recipient_id
                              ├─ resolve preferences from notification_preferences
                              ├─ FCM HTTP v1 POST per device
                              └─ data payload includes deeplink_path

  App: handle foreground via flutter_local_notifications,
        handle tap via deeplink_path -> GoRouter navigation.

  /me/notifications screen: per-category toggles writing to
  notification_preferences.

────────────────────────────────────────────────────────────────
Schema delta (M6):
  drift local DB (separate file, not Postgres):
    outbox, catches_cache, trips_cache, tournaments_cache, photos_cache

  Postgres new (0010 migration):
    device_tokens (id, user_id, token, platform, last_seen_at, RLS owner-write/service-read)
    notification_preferences (user_id pk, friend_requests bool, tournaments bool, feed bool)
    AFTER INSERT on notifications -> pg_net to dispatch edge fn
    AFTER INSERT on catches (where conditions = '{}') -> pg_net to conditions edge fn
    Enable pg_net extension if not already

  Edge functions:
    /functions/conditions-fill — Open-Meteo + NOAA Tides → catches.conditions
    /functions/push-dispatch  — notifications row → FCM HTTP POSTs
```

---

## Implementation Units

- U1. **Add deps + drift codegen plumbing**

**Goal:** Wire all infrastructural deps and the drift codegen build step.

**Requirements:** R1, R17.

**Dependencies:** None.

**Files:**
- Modify: `pubspec.yaml` (add `drift ^2.20.0`, `drift_flutter ^0.2.0`, `connectivity_plus ^6.0.0`, `internet_connection_checker_plus ^2.5.0`, `workmanager ^0.5.0`, `firebase_core ^3.6.0`, `firebase_messaging ^15.1.0`, `flutter_local_notifications ^17.2.3`, `sqlite3_flutter_libs ^0.5.0`)
- Modify: `pubspec.yaml` dev_dependencies (`drift_dev ^2.20.0`, `build_runner ^2.4.0` — already present)
- Create: `analysis_options.yaml` exclusions for `**/*.g.dart` if not already in place

**Approach:**
- Match Flutter min SDK + Riverpod 2.6 constraints.
- `flutter pub get` succeeds.
- `dart run build_runner build` runs without crashing (codegen runs once but produces nothing yet — drift schema lands in U2).

**Patterns to follow:**
- M0/U6 pattern of dep block grouping; alphabetize within sections.

**Test scenarios:**
- `flutter pub get` clean; `flutter analyze` zero new issues.

**Verification:**
- All deps resolve to compatible versions.

---

- U2. **Drift database schema + outbox table + read caches**

**Goal:** Define the local drift schema covering outbox + read-side caches.

**Requirements:** R2, R3.

**Dependencies:** U1.

**Files:**
- Create: `lib/core/local_db/local_database.dart`
- Create: `lib/core/local_db/tables/outbox.dart`
- Create: `lib/core/local_db/tables/catches_cache.dart`
- Create: `lib/core/local_db/tables/trips_cache.dart`
- Create: `lib/core/local_db/tables/tournaments_cache.dart`
- Create: `lib/core/local_db/local_database_provider.dart`
- Test: `test/core/local_db/local_database_test.dart`

**Approach:**
- `outbox`: `id` int autoincrement pk, `op_type` text (enum-encoded), `payload` text (JSON), `status` text (`pending`/`uploading`/`failed`/`synced`), `retry_count` int default 0, `last_attempt_at` int? (epoch ms), `created_at` int (epoch ms).
- `catches_cache`: mirror of `catches` columns relevant for read (`id`, `angler_id`, `species_id`, `species_label`, `weight_kg`, `length_cm`, `caught_at`, `secret_spot`, `catch_and_release`, `notes`, `rig`, `latitude`, `longitude`, `photo_paths` as JSON text, `conditions` as JSON text, `created_at`, `updated_at`).
- Same shape for `trips_cache` and `tournaments_cache` (subset of fields needed for offline reads).
- Migration shape: `schemaVersion = 1`. Use drift's annotation pattern.
- Singleton provider opens the DB at app startup; closes on dispose.

**Patterns to follow:**
- `lib/features/catches/data/catches_data_source.dart` for read shape parity.
- Drift's official "drift_flutter" example for app-wide DB instance.

**Test scenarios:**
- DB opens, schema validates, basic insert + select works (in-memory DB for tests).
- Outbox insert returns autoincrement id.
- Cache table can hold + retrieve a row that round-trips JSON columns.

**Verification:**
- `dart run build_runner build` produces `*.g.dart` files. `flutter test test/core/local_db/local_database_test.dart` green.

---

- U3. **Outbox repository + queue API**

**Goal:** A typed Dart API over the outbox table — enqueue, claim, mark synced, mark failed.

**Requirements:** R2, R4, R5.

**Dependencies:** U2.

**Files:**
- Create: `lib/features/sync/domain/outbox_op.dart`
- Create: `lib/features/sync/data/outbox_repository.dart`
- Create: `lib/features/sync/data/outbox_repository_provider.dart`
- Test: `test/features/sync/outbox_repository_test.dart`

**Approach:**
- `OutboxOp` value: `id, opType, payload (typed sealed class), status, retryCount, lastAttemptAt, createdAt`.
- `OutboxOpType` sealed: `CatchCreate(input)`, `EntryCreate(tournamentId, sourceCatchId)`, `PhotoUpload(localPath, anglerId, catchId, index)`.
- Repository methods:
  - `enqueue(op)` — inserts a `pending` row, returns id.
  - `nextPending(limit)` — returns the oldest `pending` rows up to `limit`.
  - `markUploading(id)`, `markSynced(id)`, `markFailed(id, error)`.
  - `pendingCountStream()` — reactive count of `pending + uploading` for the UI pill.

**Patterns to follow:**
- M3 tournament_chat repository's stream pattern for `pendingCountStream`.

**Test scenarios:**
- Enqueue + nextPending returns FIFO order.
- markSynced removes from pending list.
- markFailed increments retry_count, status = failed.
- pendingCountStream emits on insert/update.

**Verification:**
- All tests green; in-memory drift instance.

---

- U4. **Connectivity service + sync orchestrator**

**Goal:** A reactive connectivity stream + a sync orchestrator that drains the outbox FIFO when online.

**Requirements:** R4, R6.

**Dependencies:** U3.

**Files:**
- Create: `lib/features/sync/application/connectivity_service.dart`
- Create: `lib/features/sync/application/sync_orchestrator.dart`
- Create: `lib/features/sync/application/sync_orchestrator_provider.dart`
- Test: `test/features/sync/sync_orchestrator_test.dart`

**Approach:**
- `ConnectivityService` wraps `connectivity_plus` + `internet_connection_checker_plus`. Exposes a `Stream<bool>` of "actually online."
- `SyncOrchestrator`:
  - Listens to connectivity transitions `false → true` and triggers `_drain()`.
  - `_drain()`: claims `nextPending(10)`, processes each in order. Photo uploads first when their parent catch is in the same batch.
  - For each op: try the corresponding action (CatchesRepository.create / entries.submit / photo_storage.upload), on success mark synced, on failure with retryable error mark failed + schedule exponential backoff.
  - After each successful op, re-fetch pending — new ops queued during processing get picked up.
- Riverpod provider auto-starts the orchestrator on app boot.

**Patterns to follow:**
- M3's tournament realtime service shape for an always-running async service tied to provider lifecycle.

**Test scenarios:**
- Orchestrator with one queued CatchCreate op + connectivity true: op transitions to synced.
- Orchestrator with photo + catch op in same batch: photo runs first.
- Failure path: a queued op whose repository call throws transitions to failed, retry_count=1.
- Connectivity flap (true → false → true): drain restarts only on positive transition, not redundantly.
- Orchestrator with 0 ops + connectivity true: no work, no error.

**Verification:**
- Tests green using in-memory drift + a fake CatchesRepository.

---

- U5. **Offline-aware catch save flow**

**Goal:** Wrap the existing `saveCatchController` so a catch save enqueues to the outbox when offline (with optimistic local insert), and goes direct when online.

**Requirements:** R1, R5, R7.

**Dependencies:** U4.

**Files:**
- Create: `lib/features/sync/application/catch_offline_orchestrator.dart`
- Modify: `lib/features/catches/application/save_catch_controller.dart`
- Modify: `lib/features/catches/data/catches_repository_provider.dart` (compose `myCatchesProvider` to merge cache + queued)
- Test: `test/features/sync/catch_offline_orchestrator_test.dart`

**Approach:**
- `CatchOfflineOrchestrator.create(input, anglerId)`:
  - If online, call `catchesRepository.create` directly. On success, also write into `catches_cache` for offline parity. Return the real `Catch`.
  - If offline:
    - Generate a client-side `id` (uuid).
    - Copy each photo `XFile` to local app docs dir; store the absolute paths.
    - Write a `CatchCreate` op to the outbox with the `(input + local photo paths + assigned id)` payload.
    - Insert a row into `catches_cache` flagged `_isPending = true` for optimistic UI.
    - Return the optimistic `Catch`.
- `myCatchesProvider` becomes: `synced from server` ∪ `pending from cache` (deduped on id, pending wins for optimistic display).
- Save controller now calls the orchestrator instead of the repo directly.

**Patterns to follow:**
- `lib/features/catches/data/catches_repository.dart`'s shape and error-wrap pattern.

**Test scenarios:**
- Online + repo succeeds: returns real catch, no outbox row.
- Online + repo throws network: gracefully degrades to offline path (enqueues, returns optimistic).
- Offline: returns optimistic, outbox row exists.
- Two offline catches in sequence: both queued, both visible in myCatches.
- After connectivity returns and orchestrator drains: cache `_isPending=true` flips to `false`.

**Verification:**
- `flutter test test/features/sync/` green. Manual smoke: airplane mode → log catch → see optimistic; restore → see synced.

---

- U6. **Conditions edge function + AFTER INSERT trigger (migration 0010)**

**Goal:** A Supabase edge function that fetches Open-Meteo weather + NOAA Tides and writes to `catches.conditions`. A trigger on catch insert calls it via `pg_net`.

**Requirements:** R8, R9, R18.

**Dependencies:** None client-side.

**Files:**
- Create: `supabase/functions/conditions-fill/index.ts` (Deno)
- Create: `supabase/functions/conditions-fill/deno.json`
- Create: `supabase/migrations/0010_conditions_autofill.sql`
- Create: `docs/EDGE_FUNCTIONS.md`

**Approach:**
- Edge function input: `{ catch_id, lat, lng, caught_at, species_id }`.
- Calls Open-Meteo `https://api.open-meteo.com/v1/forecast?latitude=...&longitude=...&hourly=temperature_2m,wind_speed_10m,weather_code&start=...&end=...` (use historical archive if `caught_at` is past).
- For saltwater species (lookup `species.water_type` via service role), find nearest NOAA station via cached station list, query tide prediction at `caught_at`.
- Computes moon phase pure-locally (no API).
- Writes `{ temp_c, wind_kph, sky_code, water_temp_c?, tide_state?, moon_phase }` to `catches.conditions` via service-role UPDATE.
- Migration 0010:
  - Enable `pg_net` extension if needed.
  - Trigger on `catches AFTER INSERT WHERE conditions = '{}'::jsonb` calls `net.http_post(<edge_fn_url>, payload)`.
  - URL is read from `app.settings.conditions_fn_url` configured in Supabase secrets.

**Patterns to follow:**
- M3's notification trigger pattern — security definer SQL function calls into helper.

**Test scenarios:**
- Edge function with test payload returns expected JSON shape.
- Migration 0010 applies cleanly; trigger fires on test catch insert.
- A catch with empty conditions ends up with non-empty conditions within ~5 seconds (manual verification on dev project).
- Edge function failure (network down, NOAA 500) leaves `conditions = {}` — no error propagated to the catch save.

**Verification:**
- `supabase functions deploy conditions-fill` succeeds. Migration runs. Smoke: log a catch with GPS, conditions populate within a few seconds.

---

- U7. **Conditions display block on catch detail + Stats unlock**

**Goal:** Catch detail screen renders the conditions block when present. Stats' M4 conditions correlation card flips from placeholder to real once enough data exists.

**Requirements:** R10, R11, R17.

**Dependencies:** U6.

**Files:**
- Create: `lib/features/catches/presentation/widgets/conditions_block.dart`
- Modify: `lib/features/catches/presentation/catch_detail_screen.dart`
- Modify: `lib/features/stats/presentation/widgets/conditions_correlation_card.dart` (replace placeholder body when data ≥ threshold)
- Create: `lib/features/stats/application/conditions_correlation_provider.dart`
- Test: `test/features/catches/conditions_block_test.dart`
- Test: `test/features/stats/conditions_correlation_test.dart`

**Approach:**
- `ConditionsBlock`: parses `catch.conditions` JSON, renders a row of pills: `Temp · Wind · Sky` + saltwater rows `Water · Tide` + `Moon`. Hidden when JSON is empty or null.
- `conditionsCorrelationProvider`: reads myCatchesProvider, filters to top-quartile-weight catches, groups by `tide_state` and `temp_c` bucket. Returns top 1–2 correlations as text strings ("Falling tide + 65–72°F"). Returns null when fewer than 10 same-species catches with conditions.
- Card: when provider returns null, keep M4 placeholder; when present, render the correlation lines.

**Patterns to follow:**
- M4's `_StatsPlaceholderCard` chrome.
- `_MeasurementPill` shape from catch detail.

**Test scenarios:**
- Catch with conditions JSON renders the row; empty conditions hides the block.
- Conditions correlation provider with 5 catches returns null; with 15 catches returns a correlation string.
- Card flips between placeholder body and correlation body cleanly.

**Verification:**
- `flutter test test/features/catches/conditions_block_test.dart` and `test/features/stats/conditions_correlation_test.dart` green.

---

- U8. **Push: Firebase setup + token registration + device_tokens schema**

**Goal:** Wire Firebase, request push permission post-first-catch-save, register device tokens server-side.

**Requirements:** R12, R13, R18.

**Dependencies:** U1.

**Files:**
- Modify: `pubspec.yaml` (already added in U1)
- Create: `firebase_options.dart` (via `flutterfire configure` — committed)
- Create: `supabase/migrations/0011_device_tokens.sql`
- Create: `lib/features/notifications/data/device_tokens_repository.dart`
- Create: `lib/features/notifications/application/push_registration_service.dart`
- Create: `lib/features/notifications/application/push_registration_provider.dart`
- Modify: `lib/main.dart` (Firebase.initializeApp before runApp)
- Modify: `lib/features/catches/application/save_catch_controller.dart` (post-first-success, prompt push)
- Test: `test/features/notifications/push_registration_test.dart`
- Create: `docs/IOS_PUSH_SETUP.md` + `docs/ANDROID_PUSH_SETUP.md`

**Approach:**
- 0011: `device_tokens (id pk, user_id fk, token, platform text check in ('ios','android','web'), last_seen_at)`. RLS: owner-only insert/update/delete on own user_id; no select policy for clients (service role only).
- `PushRegistrationService.requestAndRegister()`:
  - `firebase_messaging.requestPermission()` (returns granted/denied/not-determined).
  - If granted: get FCM token, upsert into `device_tokens` for current user.
  - Listens for `onTokenRefresh` and re-upserts.
- Hook into the save flow: after the first successful catch save in a session, if permission is `not-determined`, prompt.

**Patterns to follow:**
- `lib/features/auth/` shape for service-class + provider.

**Test scenarios:**
- Service with mocked firebase_messaging permission=granted: token written to repo.
- Permission=denied: no token written, no error.
- Token refresh: repo upsert called with new value.

**Verification:**
- Manual smoke on a real device: log a catch, see permission prompt, accept, confirm row in `device_tokens`.

---

- U9. **Notification dispatch edge function + trigger**

**Goal:** A trigger on `notifications AFTER INSERT` calls a `push-dispatch` edge function that resolves device tokens + preferences and POSTs to FCM v1.

**Requirements:** R14, R15, R18.

**Dependencies:** U8.

**Files:**
- Create: `supabase/functions/push-dispatch/index.ts`
- Create: `supabase/functions/push-dispatch/deno.json`
- Create: `supabase/migrations/0012_push_dispatch_trigger.sql`

**Approach:**
- Migration 0012:
  - Add trigger on `notifications AFTER INSERT` calling `pg_net.http_post(<dispatch_fn_url>, row_to_json(NEW))`.
  - URL via `app.settings.push_dispatch_fn_url`.
- Edge function:
  - Input: a `notifications` row.
  - Looks up recipient's `device_tokens`.
  - Looks up `notification_preferences`; skips dispatch when category disabled.
  - Builds FCM v1 HTTP API call with `data: { kind, deeplink_path, ... }` + `notification: { title, body }`.
  - POSTs per device. Logs failures; doesn't error-state.

**Test scenarios:**
- Inserting a row into `notifications` with a known recipient triggers a deliverable test push.
- Recipient with category preference off: no dispatch.
- Recipient with no device_tokens: no dispatch (no error).

**Verification:**
- Manual smoke: friend request to test user → push arrives within seconds.

---

- U10. **Push receive + tap routing + notification preferences screen**

**Goal:** App handles foreground / background / tap. Me-tab gains a Notifications screen with per-category toggles wired to `notification_preferences`.

**Requirements:** R15, R16.

**Dependencies:** U9.

**Files:**
- Create: `supabase/migrations/0013_notification_preferences.sql`
- Create: `lib/features/notifications/data/notification_preferences_repository.dart`
- Create: `lib/features/notifications/application/push_message_handler.dart`
- Create: `lib/features/notifications/presentation/notification_preferences_screen.dart`
- Modify: `lib/main.dart` (register foreground + background handlers, handle initial message on cold start)
- Modify: `lib/core/router/app_router.dart` (add `/me/notifications`)
- Modify: `lib/features/me/presentation/me_screen.dart` (Notifications tile → push to /me/notifications)
- Test: `test/features/notifications/notification_preferences_test.dart`

**Approach:**
- 0013: `notification_preferences (user_id pk fk profiles, friend_requests bool default true, tournaments bool default true, feed bool default true, updated_at)`. Owner-only RLS for select+upsert.
- Foreground handler renders `flutter_local_notifications` toast when app is in use.
- Background handler is registered via `firebase_messaging.onBackgroundMessage`.
- Tap handler reads `data.deeplink_path` and calls `GoRouter.go(...)`.
- Cold-start tap: `getInitialMessage()` after Firebase.initializeApp; route once router is ready.
- Preferences screen: `Switch.adaptive` per category; persists via repository; optimistic UI.

**Patterns to follow:**
- M2 notifications-tab shape (already exists as a placeholder ListTile).

**Test scenarios:**
- Tap a notification with `deeplink_path: /tournaments/xyz` → router state becomes that path.
- Toggling a preference persists and round-trips through the repository.

**Verification:**
- Manual smoke: send self a tournament invite from another test account; tap → app opens to the tournament.

---

- U11. **Optimistic-UI integration on Catch grid + Home Feed + sync pill**

**Goal:** Queued catches show with an upload indicator badge until synced. App bar surfaces "syncing N" when queue is non-empty.

**Requirements:** R6, R7.

**Dependencies:** U5, U3.

**Files:**
- Create: `lib/features/sync/presentation/widgets/sync_pill.dart`
- Modify: `lib/features/catches/presentation/widgets/catch_tile.dart` (add upload indicator)
- Modify: `lib/features/home/presentation/home_screen.dart` (sync pill in app bar)
- Modify: `lib/features/catches/presentation/catches_screen.dart` (sync pill in app bar)
- Test: `test/features/sync/sync_pill_test.dart`

**Approach:**
- `SyncPill` watches `outboxRepo.pendingCountStream`. Hidden when count == 0; otherwise renders "Syncing N" with a spinning icon.
- `CatchTile` accepts a `bool isPending` prop — adds a small upload icon badge top-right when true.

**Test scenarios:**
- 0 pending: pill not visible.
- 3 pending: pill renders "Syncing 3."
- Pending catch tile shows the upload badge; synced does not.

**Verification:**
- `flutter test test/features/sync/sync_pill_test.dart` green. Manual smoke: airplane mode → log 2 catches → see badges + pill; restore → both clear.

---

- U12. **Documentation pass + offline + push runbooks**

**Goal:** Update parent docs and capture the queue + edge function decisions so future contributors don't rebuild offline support from scratch.

**Requirements:** R17.

**Dependencies:** U1–U11.

**Files:**
- Modify: `docs/SUPABASE_SETUP.md` (0010, 0011, 0012, 0013 + edge function deploy steps + Firebase + APNs setup)
- Modify: `README.md` (Feature status — M6 row → ✅; project layout)
- Create: `docs/EDGE_FUNCTIONS.md` (generic runbook)
- Create: `docs/IOS_PUSH_SETUP.md` (APNs key in Firebase console; push capability in Xcode)
- Create: `docs/ANDROID_PUSH_SETUP.md` (FCM via google-services.json)
- Create: `docs/solutions/2026-05-01-offline-first-queue.md`
- Create: `docs/solutions/2026-05-01-conditions-pg-net-async.md`

**Approach:**
- Learning entries record: why drift over alternatives; one outbox over N queues; pg_net async over sync HTTP from triggers; FCM-via-firebase_messaging for both platforms; client-side optimistic UI shape; "When to revisit" guidance.

**Verification:**
- `flutter analyze` clean. `flutter test` green.

---

## System-Wide Impact

- **Interaction graph:** the catch save path now flows through `CatchOfflineOrchestrator`. Online path is *thinner* than M5 (orchestrator delegates to existing repo). Offline path is new (drift writes + outbox enqueue). `myCatchesProvider` semantics expand to include queued items.
- **Error propagation:** sync failures don't surface to the save flow — they degrade silently; the user sees their catch in the grid with a badge until it syncs (R7).
- **State lifecycle risks:** Highest in M6. The orchestrator must be reentrant-safe (multiple drain attempts can't double-process), workmanager background dispatch must coexist with foreground triggering, push background handlers run in a separate isolate.
- **API surface parity:** zero schema changes to existing M0–M5 tables. Three new tables (`device_tokens`, `notification_preferences`, plus the existing `catches.conditions` JSONB column finally getting populated). RLS shape preserved.
- **Integration coverage:** `test_integration/friends_only_rls_test.dart` should be extended to assert (a) `device_tokens` is owner-write-only, (b) `notification_preferences` is owner-only-read, (c) a queued-then-synced catch still triggers M5's PR + badge detection.
- **Unchanged invariants:** M0–M5 RLS policies remain authoritative; M5's storytelling trigger still fires on synced catches.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| **Drift schema migration goes wrong on a real device** with stored data. | M6 ships at v1, and the v1 install base is small (private beta). Add migration tests in U2 simulating v0 → v1 (no data loss). Real schema changes in M6.x patches use drift's `MigrationStrategy`. |
| **Sync orchestrator races** — two drain attempts from foreground + workmanager. | Single global `_draining` flag protected by a Completer; concurrent drain calls await the first one. Tested in U4. |
| **Photo paths drift** — moving local files invalidates queue payload. | Photos copied into a stable `app_docs/photos/queued/{id}/` directory not subject to ephemeral cleanup. Files deleted only after `markSynced`. |
| **NOAA Tides API rate limit / transient outages.** | Edge function fail-silently leaves `conditions = {}`. Re-runnable: a future "refill" trigger could re-run for empty conditions. Out of M6 scope. |
| **Open-Meteo historical archive lag** for very recent timestamps. | Documented limitation. The function falls back to the live forecast endpoint when archive returns empty. |
| **Firebase setup mistakes** — wrong APNs key, push capability not enabled in Xcode. | Runbooks in `docs/IOS_PUSH_SETUP.md` + `docs/ANDROID_PUSH_SETUP.md`. U10 verification step is a real-device test, not just unit tests. |
| **`firebase_messaging` background handler isolate** doesn't see Riverpod state. | Background handler is intentionally minimal — it just hands the message off. All in-app routing happens in the main isolate via `getInitialMessage()` + foreground handler. |
| **Push for a queued-then-synced catch** could double-fire. | Notifications are server-trigger-driven on the synced row; the queue write doesn't touch `notifications`. No double-fire. Documented in U9. |
| **Queue grows unbounded** if a permanent failure mode is hit (e.g., a deleted species_id reference). | After 10 retries, a row transitions to `permanently_failed` and surfaces in a "stuck items" UI in U11. User can manually retry or delete. |
| **Optimistic UI shows queued catches in friend feeds.** | No — friends only ever read the synced server state. The queued catch isn't visible to anyone but the owner until sync. Documented in U7 test scenarios. |

---

## Phased Delivery Within M6

Suggested merge order on `feat/m6-offline-conditions-push`:

1. **U1** (deps + drift codegen) — must be first.
2. **U2** (drift schema) — U1 dep.
3. **U3** (outbox repo) — U2 dep.
4. **U4** (connectivity + sync orchestrator) — U3 dep.
5. **U5** (offline-aware catch save) — U4 dep.
6. **U11** (optimistic UI sync pill + badges) — depends on U3 + U5; can land in parallel with U6 onwards.
7. **U6** (conditions edge function + trigger) — independent of M6a stack; can be parallel.
8. **U7** (conditions display + stats unlock) — U6 dep.
9. **U8** (push setup + device_tokens) — independent.
10. **U9** (push dispatch trigger) — U8 dep.
11. **U10** (push receive + preferences) — U9 dep.
12. **U12** (docs + learnings) — last.

**Stop scope at M6.** M7 (onboarding, polish, store submission) plans separately.

---

## Documentation / Operational Notes

- After M6 lands, `docs/SUPABASE_SETUP.md` runlist gains 0010 (conditions trigger), 0011 (device tokens), 0012 (push trigger), 0013 (notification prefs).
- `README.md` Feature status: M6 row → ✅ Offline / Conditions / Push.
- New runbooks: `docs/EDGE_FUNCTIONS.md`, `docs/IOS_PUSH_SETUP.md`, `docs/ANDROID_PUSH_SETUP.md`.
- New learning entries:
  - `docs/solutions/2026-05-01-offline-first-queue.md` — drift + single outbox + photo on disk + reentrant orchestrator.
  - `docs/solutions/2026-05-01-conditions-pg-net-async.md` — pg_net async dispatch, Open-Meteo + NOAA station finder, fail-silent shape.

---

## Sources & References

- **Origin document:** `docs/brainstorms/fishing-with-friends-v1-requirements.md` (Section H — Cross-cutting; offline mode + conditions + push).
- **Parent plan:** `docs/plans/2026-05-01-001-feat-fishing-with-friends-v1-plan.md`
- **Predecessor plans:** M1–M5 in `docs/plans/`.
- **Schema baseline:** `supabase/migrations/0001_init.sql` through `supabase/migrations/0009_storytelling_schema.sql`.
- **External:** drift (`^2.20.0`), connectivity_plus (`^6.0.0`), firebase_messaging (`^15.1.0`), workmanager (`^0.5.0`), Open-Meteo API, NOAA Tides & Currents API, FCM HTTP v1 API, Supabase Edge Functions + `pg_net`.
