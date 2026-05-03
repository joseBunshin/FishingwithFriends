# Supabase Edge Functions

Deno-based functions deployed via the Supabase CLI. Each lives under `supabase/functions/<name>/index.ts`.

## Prerequisites

```bash
# Install Supabase CLI (one-time)
brew install supabase/tap/supabase   # macOS
# or
scoop install supabase                # Windows
```

Link your local repo to the project (one-time):

```bash
supabase link --project-ref <your-project-ref>
```

## Deploy

```bash
supabase functions deploy conditions-fill
```

After the first deploy, set the URL + service-role key in Postgres so migration 0010's trigger can call the function. Run in the Supabase SQL Editor (replace `<ref>` and the service key with your project values):

```sql
alter database postgres
  set "app.settings.conditions_fn_url" =
    'https://<ref>.supabase.co/functions/v1/conditions-fill';

alter database postgres
  set "app.settings.service_role_key" = '<service-role-key>';

-- Reload the settings into the current connection.
select pg_reload_conf();
```

## Local development

```bash
supabase functions serve conditions-fill --env-file ./supabase/.env.local
```

The function reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the environment. For local serving point them at your dev project (never prod).

## Functions

### `conditions-fill`

Triggered asynchronously by `pg_net.http_post` from migration 0010 when a catch is inserted with empty `conditions`. Fetches:

- **Weather** from Open-Meteo (free, no key) — temp, wind, weather code. Past timestamps use the historical archive endpoint; recent ones use the forecast endpoint.
- **Tide** from NOAA Tides & Currents (free, no key, US-only) — finds the nearest tide station within ~75km of the catch GPS, queries hourly predictions, derives `tide_state` (`rising`/`falling`/`high`/`low`) and `tide_height_m`. Saltwater species only (looked up via `species.water_type`).
- **Moon phase** computed locally via Conway's approximation. No external call.

Failures are logged and swallowed. The catch save is never blocked.

Writes back via the `fwf_set_catch_conditions(catch_id, conditions)` RPC (migration 0010) so writes happen via service role without resetting `updated_at`.

#### Payload shape

The function expects a POST body matching the trigger payload:

```json
{
  "catch_id": "uuid",
  "lat": 41.0,
  "lng": -75.0,
  "caught_at": "2026-04-01T12:00:00Z",
  "species_id": "uuid-or-null"
}
```

It writes back a JSONB conditions object:

```json
{
  "temp_c": 18.4,
  "wind_kph": 12.0,
  "weather_code": 3,
  "tide_state": "falling",
  "tide_height_m": 0.42,
  "moon_phase": 0.74,
  "source": ["open-meteo", "noaa-tides", "moon-local"]
}
```

#### When to revisit

- Switch to a paid weather provider when Open-Meteo rate-limits become an issue (current free tier is generous).
- Add international tide coverage when v1 expands beyond US waters — likely WorldTides or a regional aggregator.
- Cache nearest-station lookups in a `noaa_station_cache` table when API call volume rises (currently one extra fetch per saltwater catch).

### `delete-account`

Self-serve account deletion required by **Apple Guideline 5.1.1(v)** and **Google Play's Data Safety policy**.

Deployed via:

```bash
supabase functions deploy delete-account
```

No secrets to seed — the function only reads the auto-injected `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` env vars.

**Why an edge function instead of a Postgres RPC.** Direct `delete from auth.users` is blocked by Supabase ("direct deletion from tables is not allowed"). The only supported deletion path is `auth.admin.deleteUser(uid)`, which requires the service-role key. We can't ship that key to the Flutter client, so it has to run server-side.

**Flow.** The Flutter client invokes the function with the user's bearer token. The function:

1. Verifies the JWT against `auth.getUser()`.
2. Wipes storage objects under `avatars/<uid>/` and `catches/<uid>/` (both buckets use a `<uid>/` path prefix).
3. Calls `admin.deleteUser(uid)` — cascades through `public.profiles` and every dependent FK (`catches`, `trips`, `friendships`, `tournament_members`, `tournament_entries`, `notifications`, `device_tokens`, `notification_preferences`).

#### Verify after deploy

From a TestFlight build (or `flutter run`), sign in as a throwaway test account, navigate **Me → Settings → Danger zone → Delete account**, type `DELETE`, confirm. Then:

```sql
-- Replace with the deleted user's email.
select id, email from auth.users where email = 'throwaway@example.com';
-- Expect 0 rows.

select count(*) from public.profiles where id = '<uid-before-delete>';
-- Expect 0.

-- Storage path prefix should be empty.
select count(*) from storage.objects
  where bucket_id in ('avatars', 'catches')
    and (storage.foldername(name))[1] = '<uid-before-delete>';
-- Expect 0.
```

Re-attempt sign-in with the same email — it should fail (the user no longer exists; sign-up flow can re-claim it).

#### Failure modes

- **`401 unauthorized`** — caller's JWT has expired or sign-in dropped between the dialog and the invoke. Have them sign back in.
- **`500 auth-delete-failed`** — `admin.deleteUser` returned an error (rare; usually transient). Check the function logs in the Supabase dashboard.
- **Storage cleanup partial** — function logs a warning and proceeds with the auth deletion. Orphaned storage objects are cleaned up by a periodic sweep (TODO; for now they're invisible since the user is gone).
