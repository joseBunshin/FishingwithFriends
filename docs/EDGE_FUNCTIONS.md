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
