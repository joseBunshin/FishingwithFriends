---
title: Offline-first — single drift outbox + sync orchestrator
date: 2026-05-01
type: architecture
milestone: M6a
component: lib/features/sync/
---

# Offline-first queue

M6a ships catch logging that works without a connection. A user on a boat with no LTE can still tap Save, see their catch immediately, and have it sync when connectivity returns. The contract is non-negotiable per origin doc Section H ("boats and remote rivers don't have LTE").

## Decisions

### `drift` (SQLite) over `sqflite` / `hive`

Drift wins on three axes for a non-trivial relational mirror: type-safe queries, reactive streams (the sync pill subscribes to a count stream straight off the table), and managed schema migrations. `sqflite` would force hand-rolled type mapping for every read; `hive` is fast but fights a relational shape.

### Single outbox table, three op kinds

One `outbox` table holds `(op_type, payload, status, retry_count, last_attempt_at)` for catch creates, tournament entry submits, and any future op kind. Insertion order = drain order. Avoids three parallel queues and keeps FIFO across ops that depend on each other.

Op kinds are encoded as a sealed-style class hierarchy (`CatchCreateOp`, `EntryCreateOp`, `PhotoUploadOp`) that round-trips JSON. Adding a new op type is a class + a switch arm, never a schema migration.

### Photos on the filesystem, not in SQLite

5MB+ images don't belong in a row. Photos copied into a stable `app_docs/queued_photos/<catchId>/` directory; the queue payload references absolute paths. Cleaned up after successful sync.

### Reentrant single-flight orchestrator

`SyncOrchestrator.drain()` returns the same Future to all callers while an in-flight drain is running. Avoids parallel drain attempts from foreground triggers + connectivity transitions. Uses a simple `Future<void>?` field cleared in `whenComplete`.

### Optimistic UI through merged provider

`myCatchesProvider` returns `synced ∪ pending` rows, deduped by id with pending winning. Existing screens (Stats, Map, Year-in-Review, Catches grid, Home feed) didn't need to change — they all see queued catches automatically. The badge layer is the only UI explicitly aware of "isPending."

### Mid-flight network failure degrades to the queue

`CatchOfflineOrchestrator.create()` checks connectivity, tries the online path, and on `NetworkFailure` falls through to the offline enqueue path. The user never sees a save error from a transient blip — their catch always lands somewhere durable.

## When to revisit

Move to a richer sync model (e.g., per-table replication via `electric-sql` or PowerSync) when **any** of:

- Friend catches need offline read parity (currently only own catches are cached).
- Conflict resolution becomes a thing (M6 has none — client always wins because the catch id is generated client-side).
- Sync queue depth regularly exceeds ~50 items per user (current FIFO drain is fine for typical use).

## Test surface

- `test/core/local_db/local_database_test.dart` — schema + insert/select round-trip
- `test/features/sync/outbox_repository_test.dart` — queue API + status transitions + count stream
- `test/features/sync/sync_orchestrator_test.dart` — drain + reentrancy + entry replay
- `test/features/sync/catch_offline_orchestrator_test.dart` — online + offline paths, mid-flight degradation
- `test/features/sync/sync_pill_test.dart` — pill visibility based on count

## Related

- `lib/features/sync/data/pending_catches_provider.dart` — stream provider keyed off `catches_cache.is_pending=true`. Lives in the sync feature folder so the catches feature can consume it without forming an import cycle through the orchestrator.
