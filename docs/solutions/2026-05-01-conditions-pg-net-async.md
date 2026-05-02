---
title: Conditions auto-fill — pg_net async dispatch + Deno edge function
date: 2026-05-01
type: architecture
milestone: M6b
component: supabase/functions/conditions-fill/, supabase/migrations/0010
---

# Conditions auto-fill

M6b populates `catches.conditions` (JSONB, default `{}`) with weather + tide + moon-phase data so M4's "Conditions correlation" Stats card has real signal to surface. The work runs entirely server-side and asynchronously — catch insert latency is unaffected.

## Decisions

### `pg_net.http_post`, not synchronous HTTP from a trigger

A blocking HTTP call inside an `AFTER INSERT` trigger would push catch insert latency to 500–1500ms per catch (Open-Meteo + NOAA both involve the round trip). `pg_net.http_post` is fire-and-forget — the trigger returns in microseconds and the call runs in a background worker. The catch save is never blocked or affected by an upstream API outage.

### Failures are silent

The edge function logs and swallows every external error. `conditions = {}` is the correct degraded state. Users never see a save failure caused by Open-Meteo being slow or NOAA returning 500.

### Open-Meteo + NOAA Tides — both free, no key

Open-Meteo gives historical archive (>7 days old) + current forecast in one consistent shape. NOAA Tides & Currents gives US tidal stations with no auth. Both are public-tier-friendly for v1's friends-only scale.

International tide is deferred — saltwater catches outside the ~200 NOAA stations get weather only. The function computes nearest-station via haversine and rejects matches farther than 75km.

### Moon phase computed locally

Conway's approximation is good to ±0.05 of a day. No external call. Always populated, regardless of network.

### Service-role write via dedicated RPC

`fwf_set_catch_conditions(catch_id, conditions)` is a `security definer` SQL function the edge function calls via `supabase.rpc(...)`. Doing the write through an RPC (vs a direct `update`) lets the edge function's permissions stay narrow — it can only write to the `conditions` column, not the rest of `catches`.

### URL + service-role key in Postgres settings

`app.settings.conditions_fn_url` and `app.settings.service_role_key` are read by `fwf_setting()` at trigger-fire time. If unset, the trigger no-ops — dev environments work without provisioning the function. Production setup is documented in `docs/EDGE_FUNCTIONS.md`.

## When to revisit

- Switch weather provider when Open-Meteo's free tier becomes a bottleneck. The function's external API surface is small (one request per catch), so any provider that returns hourly historical data over HTTP fits.
- Cache nearest-NOAA-station lookups in a `noaa_station_cache` table when call volume rises (currently one extra fetch per saltwater catch).
- Add international tide coverage (WorldTides or a regional aggregator) if v1 ships outside US-coastal markets.

## Test surface

The edge function lives in TypeScript outside the Dart test runner. Validate via:

1. `supabase functions deploy conditions-fill` to a dev project.
2. Insert a test catch with GPS via the SQL editor.
3. Query `select id, conditions from catches order by created_at desc limit 1;` 10 seconds later — conditions populated.
4. `test/features/catches/conditions_block_test.dart` covers the client-side rendering of the result.
5. `test/features/stats/conditions_correlation_test.dart` covers the Stats unlock threshold.
