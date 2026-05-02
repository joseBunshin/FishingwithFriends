// Supabase Edge Function — conditions-fill
//
// Triggered by the AFTER INSERT trigger on `catches` (migration 0010).
// Fetches weather (Open-Meteo) and, for saltwater species, tide (NOAA),
// computes moon phase locally, and writes the result back to
// `catches.conditions` via the `fwf_set_catch_conditions` RPC.
//
// Failures are logged and swallowed — leaving `conditions = {}` is the
// correct degraded state. The catch save is never blocked.

// deno-lint-ignore-file no-explicit-any
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

interface TriggerPayload {
  catch_id: string;
  lat: number;
  lng: number;
  caught_at: string; // ISO 8601 UTC
  species_id: string | null;
}

interface Conditions {
  temp_c?: number;
  wind_kph?: number;
  weather_code?: number;
  water_temp_c?: number;
  tide_state?: 'rising' | 'falling' | 'high' | 'low';
  tide_height_m?: number;
  moon_phase?: number; // 0..1, where 0 = new, 0.5 = full
  source?: string[];
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('method not allowed', { status: 405 });
  }

  let payload: TriggerPayload;
  try {
    payload = await req.json();
  } catch (_e) {
    return new Response('bad request', { status: 400 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !serviceKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return new Response('config', { status: 500 });
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const conditions: Conditions = { source: [] };

  // ---------- Weather (Open-Meteo) ----------
  try {
    const weather = await fetchWeather(
      payload.lat,
      payload.lng,
      payload.caught_at,
    );
    Object.assign(conditions, weather);
    if (weather) conditions.source!.push('open-meteo');
  } catch (e) {
    console.warn('weather fetch failed', e);
  }

  // ---------- Tide (NOAA — saltwater species only) ----------
  try {
    const isSaltwater = await checkSaltwater(supabase, payload.species_id);
    if (isSaltwater) {
      const tide = await fetchTide(
        payload.lat,
        payload.lng,
        payload.caught_at,
      );
      if (tide) {
        Object.assign(conditions, tide);
        conditions.source!.push('noaa-tides');
      }
    }
  } catch (e) {
    console.warn('tide fetch failed', e);
  }

  // ---------- Moon phase (local computation) ----------
  conditions.moon_phase = moonPhaseAt(new Date(payload.caught_at));
  conditions.source!.push('moon-local');

  if (conditions.source!.length === 0) {
    delete conditions.source;
  }

  // ---------- Write back ----------
  const { error } = await supabase.rpc('fwf_set_catch_conditions', {
    p_catch_id: payload.catch_id,
    p_conditions: conditions,
  });
  if (error) {
    console.error('rpc fwf_set_catch_conditions failed', error);
    return new Response('rpc-failed', { status: 500 });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'content-type': 'application/json' },
  });
});

// ----------------------------------------------------------------------------
// Open-Meteo — weather at lat/lng/timestamp.
// Past timestamps use the historical archive endpoint; future/recent
// timestamps fall back to the forecast endpoint.
// ----------------------------------------------------------------------------
async function fetchWeather(
  lat: number,
  lng: number,
  caughtAt: string,
): Promise<Partial<Conditions> | null> {
  const ts = new Date(caughtAt);
  const isoDate = ts.toISOString().slice(0, 10);
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setUTCDate(sevenDaysAgo.getUTCDate() - 7);
  const useArchive = ts < sevenDaysAgo;

  const base = useArchive
    ? 'https://archive-api.open-meteo.com/v1/archive'
    : 'https://api.open-meteo.com/v1/forecast';

  const url = new URL(base);
  url.searchParams.set('latitude', String(lat));
  url.searchParams.set('longitude', String(lng));
  url.searchParams.set('start_date', isoDate);
  url.searchParams.set('end_date', isoDate);
  url.searchParams.set(
    'hourly',
    'temperature_2m,wind_speed_10m,weather_code',
  );
  url.searchParams.set('timezone', 'UTC');

  const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) return null;
  const json = await res.json() as any;
  const hours = json?.hourly?.time as string[] | undefined;
  if (!hours || hours.length === 0) return null;

  // Pick the hour closest to caughtAt.
  const targetMs = ts.getTime();
  let bestIdx = 0;
  let bestDelta = Number.POSITIVE_INFINITY;
  for (let i = 0; i < hours.length; i++) {
    const d = Math.abs(new Date(hours[i] + 'Z').getTime() - targetMs);
    if (d < bestDelta) {
      bestDelta = d;
      bestIdx = i;
    }
  }

  const temps = json.hourly.temperature_2m as number[];
  const winds = json.hourly.wind_speed_10m as number[];
  const codes = json.hourly.weather_code as number[];

  return {
    temp_c: temps?.[bestIdx],
    wind_kph: winds?.[bestIdx],
    weather_code: codes?.[bestIdx],
  };
}

// ----------------------------------------------------------------------------
// NOAA Tides & Currents — find nearest station and query tide prediction.
// Free, no key. US coastal coverage only; international saltwater catches
// get weather but no tide.
// ----------------------------------------------------------------------------
async function fetchTide(
  lat: number,
  lng: number,
  caughtAt: string,
): Promise<Partial<Conditions> | null> {
  // Find nearest active station within a sane radius.
  const stationsUrl =
    'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json'
    + '?type=tidepredictions';
  const sRes = await fetch(stationsUrl, { signal: AbortSignal.timeout(8000) });
  if (!sRes.ok) return null;
  const sJson = await sRes.json() as any;
  const stations = (sJson?.stations ?? []) as Array<{
    id: string;
    lat: number;
    lng: number;
  }>;
  if (stations.length === 0) return null;

  let best = stations[0];
  let bestD = haversine(lat, lng, best.lat, best.lng);
  for (const s of stations) {
    const d = haversine(lat, lng, s.lat, s.lng);
    if (d < bestD) {
      bestD = d;
      best = s;
    }
  }
  // Reject stations more than ~75km away — likely not the right body of water.
  if (bestD > 75) return null;

  const ts = new Date(caughtAt);
  const begin = new Date(ts.getTime() - 60 * 60 * 1000);
  const end = new Date(ts.getTime() + 60 * 60 * 1000);
  const fmt = (d: Date) =>
    d.toISOString().slice(0, 16).replace('T', ' ').replace(/[-:]/g, '');

  const tideUrl =
    `https://api.tidesandcurrents.noaa.gov/api/prod/datagetter`
    + `?product=predictions&station=${best.id}`
    + `&begin_date=${fmt(begin)}&end_date=${fmt(end)}`
    + `&datum=MLLW&time_zone=GMT&units=metric&format=json&interval=h`;
  const tRes = await fetch(tideUrl, { signal: AbortSignal.timeout(8000) });
  if (!tRes.ok) return null;
  const tJson = await tRes.json() as any;
  const preds = (tJson?.predictions ?? []) as Array<{
    t: string;
    v: string;
  }>;
  if (preds.length < 2) return null;

  // Closest-to-caught point + slope.
  const targetMs = ts.getTime();
  let bestIdx = 0;
  let bestDelta = Number.POSITIVE_INFINITY;
  for (let i = 0; i < preds.length; i++) {
    const d = Math.abs(new Date(preds[i].t + 'Z').getTime() - targetMs);
    if (d < bestDelta) {
      bestDelta = d;
      bestIdx = i;
    }
  }
  const here = parseFloat(preds[bestIdx].v);
  const next = preds[bestIdx + 1] ?? preds[bestIdx - 1];
  const there = parseFloat(next.v);
  const slope = there - here;
  const tideState =
    Math.abs(slope) < 0.05 ? (here > 1 ? 'high' : 'low')
    : slope > 0 ? 'rising' : 'falling';

  return {
    tide_state: tideState,
    tide_height_m: here,
  };
}

async function checkSaltwater(
  supabase: any,
  speciesId: string | null,
): Promise<boolean> {
  if (!speciesId) return false;
  const { data, error } = await supabase
    .from('species')
    .select('water_type')
    .eq('id', speciesId)
    .maybeSingle();
  if (error) return false;
  return data?.water_type === 'saltwater' || data?.water_type === 'both';
}

function haversine(
  aLat: number, aLng: number, bLat: number, bLng: number,
): number {
  const r = 6371; // km
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos((aLat * Math.PI) / 180)
      * Math.cos((bLat * Math.PI) / 180)
      * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(h));
}

// Conway's approximation — good to ±0.05.
function moonPhaseAt(date: Date): number {
  const synodic = 29.530588853;
  const ref = Date.UTC(2000, 0, 6, 18, 14); // known new moon
  const days = (date.getTime() - ref) / (1000 * 60 * 60 * 24);
  let phase = (days % synodic) / synodic;
  if (phase < 0) phase += 1;
  return Number(phase.toFixed(3));
}
