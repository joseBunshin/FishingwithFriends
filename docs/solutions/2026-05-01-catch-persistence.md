---
date: 2026-05-01
topic: catch-persistence
type: pattern
---

# Photo-upload-before-insert ordering for atomic catch creation

## Problem

Saving a catch needs to upload N photos to Supabase Storage AND insert one row into `public.catches` whose `photo_paths text[]` references those uploads. Two intuitive orderings both have problems:

1. **Insert row first, then upload photos and update.** Two-phase commit. The row exists with empty `photo_paths` for a window; concurrent friend reads see a "photo-less" catch. Update can fail leaving permanent inconsistency.
2. **Upload photos first, but use a server-generated row id.** You don't know the catch id until after insert, so you can't put the photos under `<angler_id>/<catch_id>/...` to match the storage policy in `0002_storage_policies.sql`. You'd have to either re-upload or use a separate id (creating a forever-cross-reference). Insert is no longer atomic with upload.

## Pattern

**Generate the catch id client-side; upload photos under that id; then insert the row referencing already-real paths.**

```text
catchId = uuid.v4()                                                 ← client
for each photo:                                                     ← upload
  storage.upload('<anglerId>/<catchId>/<i>.<ext>', file)
insert into catches (id = catchId, photo_paths = uploaded_paths)    ← single insert
```

The DB insert is atomic — the row never exists in a half-photo'd state. If insert fails, photos are orphaned in storage. M1 accepts this; M6's offline sync queue will reap orphans.

## Why this works for FWF

- Storage policy `(storage.foldername(name))[1] = auth.uid()` only requires the *angler* prefix to match, not the catch id. Pre-creating folders is fine.
- `catches.id` is `uuid` with a default of `gen_random_uuid()`, but the schema accepts a client-supplied id without complaint.
- `photo_paths text[]` is set in the same insert that establishes the row, so RLS readers never see a row with stale paths.

## Reusable artifacts

- `lib/features/catches/data/photo_storage.dart` — `PhotoStorage.upload(...)` builds the `<angler_id>/<catch_id>/<index>.<ext>` path.
- `lib/features/catches/data/catches_repository.dart` — orchestrates `for upload → insert` and maps Supabase errors into `AppException` subclasses.
- `lib/features/catches/data/signed_url_provider.dart` — Riverpod `family` keyed by storage path; lazy-refresh ~10 minutes before the 60-minute Supabase TTL.

When future features need the same atomic-insert-with-attached-media shape (avatar uploads in M7, tournament-chat photos in M3, share-card export in M5), reach for these primitives instead of reinventing.

## Tested invariant

`test/features/catches/data/catches_repository_test.dart` records call order across a fake `PhotoStorage` + fake `CatchesDataSource` and asserts that uploads precede the insert. The test is privacy-load-bearing: an inserted row that references unuploaded paths would either 404 for friends (best case) or, depending on storage policy edge cases, hide the privacy boundary.

## Related

- `supabase/migrations/0002_storage_policies.sql` — owner-folder + friend-read policies that this pattern depends on.
- `docs/plans/2026-05-01-002-feat-m1-catch-persistence-plan.md` — M1 plan, "Key Technical Decisions" section.
