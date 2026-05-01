# Supabase setup

One-time backend bootstrap for Fishing with Friends.

## 1. Create the project

1. Sign in at https://supabase.com/dashboard.
2. Create a new project under the Bunshin Studios org. Region: closest to your primary user base.
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

**Realtime:** After running 0006, enable Realtime for `tournament_entries` and `tournament_chat_messages` in **Database → Replication** so the live leaderboard + chat update without a refresh.

**M4 introduces no new migrations.** The Catch Map and Stats deepening features are pure read-side against the existing schema. RLS contract from 0001 + the recursion fix in 0007 remain authoritative.

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
