# Supabase setup

One-time backend bootstrap for Fishing with Friends.

## 1. Create the project

1. Sign in at https://supabase.com/dashboard.
2. Create a new project under the Bunshin Development Studios org. Region: closest to your primary user base.
3. Save the project URL and `anon` key into `.env`:
   ```
   SUPABASE_URL=https://<ref>.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOi...
   ```

## 2. Enable extensions

In **Database → Extensions**, enable:

- `pgcrypto` (UUID + crypto)
- `postgis` (catch geometry)

## 3. Run the migrations

Open **SQL Editor → New query** and run, in order:

1. `supabase/migrations/0001_init.sql` — schema + RLS for every table.
2. *(After step 4 below)* `supabase/migrations/0002_storage_policies.sql` — private 'catches' bucket policies.
3. `supabase/migrations/0003_units_and_species.sql` — canonical metric measurements, `species.water_type`, seed list of ~30 freshwater + saltwater species, `catches.conditions` JSONB column for the M6 weather/tide cache.
4. `supabase/migrations/0004_catch_metadata.sql` — `catch_and_release` + `rig` columns + view recreate.
5. `supabase/migrations/0005_trips_and_social.sql` — `trips`, `trip_participants`, `feed_reactions`, `comments` tables, `catches.trip_id` FK, RLS policies, and four notification triggers (friend request / friend accepted / reaction / comment).
6. `supabase/migrations/0006_tournaments_realtime.sql` — `tournaments.join_code` + `is_closed`, `tournament_entries` snapshot columns + status, `tournament_side_pots` table, `tournament_chat_messages` table, RLS policies, and three notification triggers (tournament invite / member resolved / entry resolved).
7. `supabase/migrations/0007_tournament_rls_recursion_fix.sql` — security-definer helpers (`tournament_creator_id`, `is_accepted_tournament_member`) that break the cross-table RLS infinite-recursion. **Required** — without it tournament reads return `42P17 infinite recursion detected in policy`.
8. `supabase/migrations/0008_auto_profile_on_signup.sql` — trigger on `auth.users` insert that auto-creates a `public.profiles` row (derived username) plus a one-time backfill for users that signed up before this migration. Without it any insert that FKs to `profiles` fails on a fresh sign-up.
9. `supabase/migrations/0009_storytelling_schema.sql` — `personal_records`, `badges` (+ 5 seeded definitions), `user_badges` tables with RLS, plus an AFTER INSERT/UPDATE trigger on `catches` that auto-detects new PRs (per-species weight + length) and earned badges. **Required for M5** — without it the celebration screen never fires.
10. `supabase/migrations/0010_conditions_autofill.sql` — enables `pg_net`, adds an AFTER INSERT trigger on `catches` that calls a `conditions-fill` edge function asynchronously to populate weather + tide. **Optional for M6** — if the edge function URL isn't configured (`app.settings.conditions_fn_url`), the trigger no-ops and conditions remain empty. See `docs/EDGE_FUNCTIONS.md` for deploy + config.
11. `supabase/migrations/0011_fwf_app_settings_fallback.sql` — table-backed `fwf_setting()` fallback for environments where the dashboard SQL Editor can't `alter database postgres set ...`. Insert key/value rows into `public.fwf_app_settings` instead.
12. `supabase/migrations/0012_conditions_search_path_fix.sql` — adds `extensions` to the conditions trigger function's `search_path` so PostGIS types resolve.
13. `supabase/migrations/0013_profile_onboarding_columns.sql` — adds `home_water` + `onboarding_completed_at` to `profiles`. **Required for M7** — without it the onboarding flow never finishes and the router traps users on `/onboarding`.
14. `supabase/migrations/0014_creator_auto_member.sql` — AFTER INSERT trigger on `tournaments` that auto-enrolls the creator as an `accepted` row in `tournament_members`, plus a one-time backfill for existing tournaments. **Fix for M3** — without it, tournament creators hit RLS when submitting their own catch as an entry (`new row violates row-level security policy for table "tournament_entries"`).
15. `supabase/migrations/0015_auto_approve_creator_entries.sql` — BEFORE INSERT trigger on `tournament_entries` that auto-stamps `status='approved'` when the submitting angler is the tournament creator. Otherwise creators have to "approve" their own entries, which is a no-op tap that confuses everyone. Backfills any existing pending creator entries.
16. `supabase/migrations/0016_catches_latlng_columns.sql` — adds plain `latitude`/`longitude` numeric columns to `catches`, kept in sync with `location` via a BEFORE INSERT/UPDATE trigger, plus a one-time backfill. Recreates `catches_friend_view` to expose them. Without this, the catch detail screen renders "Location not captured" even when GPS was set, because Supabase serializes `geography` as EWKB hex which the Flutter DTO can't parse.
17. `supabase/migrations/0017_push_schema.sql` — `device_tokens` (per-device FCM token) + `notification_preferences` (per-user category toggles) tables with RLS, plus the `fwf_lookup_push_recipients` security-definer helper that the dispatch edge function calls.
18. `supabase/migrations/0018_push_dispatch_trigger.sql` — AFTER INSERT trigger on `notifications` that calls the `push-dispatch` edge function via `pg_net`. **Optional for M6c** — if the edge function URL isn't configured (`app.settings.push_dispatch_fn_url`), the trigger no-ops.

After running 0017 + 0018, also insert the dispatch URL into `fwf_app_settings`:

```sql
insert into public.fwf_app_settings (key, value) values
  ('app.settings.push_dispatch_fn_url',
   'https://YOUR-REF.supabase.co/functions/v1/push-dispatch')
on conflict (key) do update
  set value = excluded.value, updated_at = now();
```

The service-role key (already inserted for the conditions function) is reused.

19. `supabase/migrations/0019_avatars_bucket.sql` — public `avatars` storage bucket with owner-only write policies (gated by user-id-prefixed path). **Required for M7 avatar upload** — without it the picker fails with a storage RLS denial.
20. `supabase/migrations/0020_storytelling_friend_visibility.sql` — broadens RLS on `personal_records` and `user_badges` so accepted friends can read each other's PRs and badges (was owner-only). **Required for the social ProfileScreen** — without it friend profiles render zero badges.
21. `supabase/migrations/0021_tournament_metric_extra_values.sql` — extends the `tournament_metric` enum with `biggest_fish`, `most_catches`, `longest_catch`, `biggest_single`. **Required to create tournaments under those scoring modes** — without it the create sheet 500s with `22P02 invalid_text_representation` when anything other than `weight`/`length` is chosen.
22. `supabase/migrations/0022_creator_invite_members.sql` — adds RLS policy `tournament_members_insert_creator` so creators can directly invite anglers (insert pending member rows). The original schema only allowed self-pending inserts. **Required for the "Invite friends" sheet on the Members tab** — without it every invite RLS-fails silently.
23. `supabase/migrations/0023_delete_account.sql` — *(superseded — see 0024)* originally added a `public.delete_account()` security-definer RPC, but Supabase blocks direct deletion of `auth.users` rows ("direct deletion from tables is not allowed"). The deletion path moved to the `delete-account` edge function instead.
24. `supabase/migrations/0024_drop_delete_account_rpc.sql` — drops the broken `public.delete_account()` from 0023. Account deletion now runs through the **`delete-account` edge function** (`supabase/functions/delete-account/`), which uses the service-role key to call `auth.admin.deleteUser(uid)`. The Flutter client invokes it via `client.functions.invoke('delete-account')`. **Required for App Store / Play Store submission** (Apple Guideline 5.1.1(v) + Google Data Safety). See `docs/EDGE_FUNCTIONS.md` for the deploy + verify steps.
25. `supabase/migrations/0025_approved_by_set_null_on_delete.sql` — switches `tournament_members.approved_by` and `tournament_entries.approved_by` to `on delete set null`. Both FKs in 0001 defaulted to `no action`, which made `auth.admin.deleteUser(uid)` fail with `23503` whenever the deleting user had ever approved a tournament member or entry. **Required for `delete-account` to succeed** for any user who has ever moderated their own or others' tournaments.

**Realtime:** After running 0006, enable Realtime for `tournament_entries` and `tournament_chat_messages` in **Database → Replication** so the live leaderboard + chat update without a refresh.

**M4 introduces no new migrations.** The Catch Map and Stats deepening features are pure read-side against the existing schema. RLS contract from 0001 + the recursion fix in 0007 remain authoritative.

**Dev seed (optional).** Once migrations are applied, `supabase/seed/dev_seed.sql` populates 3 mock friend accounts + ~25 catches + 1 trip + 1 active tournament + reactions/comments so you can exercise the full app end-to-end. The file's docblock has the step-by-step (create three test users via Auth → Users, then paste the SQL). Idempotent — re-running wipes prior seed data scoped to the test users only.

Or, if you use the Supabase CLI:

```bash
supabase link --project-ref <ref>
supabase db push
```

## 4. Create the private storage bucket

In **Storage → Create bucket**:

- Name: `catches`
- Public: **off** (private)
- File size limit: 25 MB recommended
- Allowed MIME types: `image/*`

After the bucket exists, run `supabase/migrations/0002_storage_policies.sql`.

Path convention used by the app: `<angler_id>/<uuid>.<ext>`. The owner-folder check (`(storage.foldername(name))[1]`) depends on this layout.

## 5. Auth settings

In **Authentication → Providers**:

- Email + password is enabled by default. Keep it on for v1.
- Disable email confirmations during local dev if you want sign-in to be immediate; re-enable before TestFlight.

In **Authentication → URL configuration**:

- Site URL: not relevant for native. For deep links later, register `com.bunshin.fishingwithfriends://login-callback`.

## 6. Realtime

In **Database → Replication**, make sure these tables broadcast changes (needed for live leaderboards):

- `tournament_entries`
- `tournament_members`
- `catches`
- `notifications`

## 7. Smoke test

```bash
flutter run
```

Sign up with a throwaway email. You should land on the Feed tab. Open the Profile tab and tap **Sign out** to confirm the auth gate kicks you back to the sign-in screen.

If you hit `Missing SUPABASE_URL`, your `.env` is empty or not picked up — confirm `assets: - .env` is still in `pubspec.yaml` and re-run `flutter pub get`.
