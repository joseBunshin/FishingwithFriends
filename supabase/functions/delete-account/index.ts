// Supabase Edge Function — delete-account
//
// Self-serve account deletion required by App Store Guideline 5.1.1(v)
// and Google Play's Data Safety policy.
//
// Why this lives in an edge function (and not a Postgres RPC): direct
// `delete from auth.users` is blocked by Supabase ("direct deletion from
// tables is not allowed"); the only supported path is the auth admin
// API, which requires the service-role key. We can't ship that key to
// the client, so the deletion runs server-side here.
//
// Flow:
//   1. Read the caller's bearer token from the Authorization header.
//   2. Verify the token with the user-scoped client; bail if no user.
//   3. Use a service-role client to:
//      a. Wipe storage objects under `avatars/<uid>/...` and `catches/<uid>/...`.
//      b. Call `auth.admin.deleteUser(uid)` — cascades through every FK
//         that references public.profiles (catches, trips, friendships,
//         tournament memberships/entries, notifications, device_tokens,
//         notification_preferences) since profiles.id ON DELETE CASCADEs
//         from auth.users.
//
// Environment (all auto-injected by Supabase Edge Function runtime):
//   SUPABASE_URL
//   SUPABASE_ANON_KEY
//   SUPABASE_SERVICE_ROLE_KEY

// deno-lint-ignore-file no-explicit-any
import { createClient } from 'npm:@supabase/supabase-js@2';

const ALLOWED_ORIGINS = '*';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGINS,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method-not-allowed' }, 405);
  }

  const auth = req.headers.get('Authorization') ?? '';
  if (!auth.toLowerCase().startsWith('bearer ')) {
    return jsonResponse({ error: 'missing-bearer' }, 401);
  }
  const jwt = auth.slice(7).trim();
  if (!jwt) {
    return jsonResponse({ error: 'missing-bearer' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !anonKey || !serviceKey) {
    console.error('delete-account: missing env');
    return jsonResponse({ error: 'config' }, 500);
  }

  // 1. Verify JWT against the auth API (uses anon key + caller token).
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(
    jwt,
  );
  if (userError || !userData?.user) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }
  const uid = userData.user.id;

  // 2. Service-role client — bypasses RLS, can call auth admin.
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // 3. Wipe storage objects under `<uid>/` in both buckets. List + delete
  //    in batches so a user with hundreds of catch photos is handled.
  for (const bucket of ['avatars', 'catches']) {
    try {
      await wipeBucketFolder(admin, bucket, uid);
    } catch (e) {
      // Don't fail the whole deletion on storage cleanup — orphaned
      // objects are a soft problem, an undeletable account is a hard one.
      console.warn(`delete-account: storage wipe failed for ${bucket}/${uid}`, e);
    }
  }

  // 4. Delete the auth user. This cascades through public.profiles and
  //    every dependent FK in one shot.
  const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
  if (deleteError) {
    console.error('delete-account: admin.deleteUser failed', deleteError);
    return jsonResponse(
      { error: 'auth-delete-failed', detail: deleteError.message },
      500,
    );
  }

  return jsonResponse({ ok: true, deleted: uid });
});

async function wipeBucketFolder(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  uid: string,
): Promise<void> {
  const prefix = `${uid}/`;
  // Supabase storage list maxes out at 1000 entries per call. Loop until
  // we get an empty page.
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(uid, { limit: 1000 });
    if (error) throw error;
    if (!data || data.length === 0) return;
    const paths = data.map((entry: any) => `${prefix}${entry.name}`);
    const { error: removeError } = await admin.storage
      .from(bucket)
      .remove(paths);
    if (removeError) throw removeError;
    if (data.length < 1000) return;
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      'content-type': 'application/json',
    },
  });
}
