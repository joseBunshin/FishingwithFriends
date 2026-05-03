// Supabase Edge Function — push-dispatch
//
// Triggered by 0018's AFTER INSERT trigger on `notifications`. For each
// new notification row:
//   1. Look up recipient's device tokens + preferences via the
//      fwf_lookup_push_recipients RPC (security definer).
//   2. Skip when the relevant category preference is off.
//   3. Mint an OAuth token from FCM_SERVICE_ACCOUNT_JSON (Firebase Admin
//      SDK service account) and POST to FCM HTTP v1 per device.
//   4. Fail-silent — log errors but don't propagate; the notification
//      row is already in the DB so the in-app /me/notifications screen
//      sees it regardless.
//
// Environment:
//   SUPABASE_URL                — auto-injected
//   SUPABASE_SERVICE_ROLE_KEY   — auto-injected
//   FCM_SERVICE_ACCOUNT_JSON    — set in Supabase Edge Function Secrets
//                                 (the full Firebase Admin SDK JSON)

// deno-lint-ignore-file no-explicit-any
import { createClient } from 'npm:@supabase/supabase-js@2';

interface NotificationPayload {
  notification_id: string;
  recipient_id: string;
  kind: string; // friend_request, tournament_invite, ...
  payload: Record<string, any>;
  created_at: string;
}

interface DeviceToken {
  token: string;
  platform: 'ios' | 'android' | 'web';
}

interface RecipientLookup {
  tokens: DeviceToken[];
  prefs: {
    friend_requests: boolean;
    tournaments: boolean;
    feed: boolean;
  };
}

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  // ... other fields we don't use
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('method not allowed', { status: 405 });
  }

  let payload: NotificationPayload;
  try {
    payload = await req.json();
  } catch (_e) {
    return new Response('bad request', { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } },
  );

  // ---------- Look up tokens + preferences ----------
  let lookup: RecipientLookup;
  try {
    const { data, error } = await supabase.rpc(
      'fwf_lookup_push_recipients',
      { p_user_id: payload.recipient_id },
    );
    if (error) throw error;
    lookup = data as RecipientLookup;
  } catch (e) {
    console.error('lookup failed', e);
    return new Response('lookup-failed', { status: 500 });
  }

  if (lookup.tokens.length === 0) {
    return new Response(JSON.stringify({ ok: true, sent: 0, reason: 'no-tokens' }), {
      headers: { 'content-type': 'application/json' },
    });
  }

  // ---------- Honor per-category preferences ----------
  const category = categoryFor(payload.kind);
  if (category === 'friend_requests' && !lookup.prefs.friend_requests) {
    return jsonResponse({ ok: true, sent: 0, reason: 'pref-off-friends' });
  }
  if (category === 'tournaments' && !lookup.prefs.tournaments) {
    return jsonResponse({ ok: true, sent: 0, reason: 'pref-off-tournaments' });
  }
  if (category === 'feed' && !lookup.prefs.feed) {
    return jsonResponse({ ok: true, sent: 0, reason: 'pref-off-feed' });
  }

  // ---------- Build FCM message ----------
  const { title, body } = composeNotificationCopy(payload);
  const data: Record<string, string> = {
    notification_id: payload.notification_id,
    kind: payload.kind,
    deeplink_path: deeplinkFor(payload),
  };

  // ---------- Mint OAuth token + POST per device ----------
  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(
      Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? '{}',
    );
  } catch (e) {
    console.error('FCM_SERVICE_ACCOUNT_JSON parse failed', e);
    return new Response('config-failed', { status: 500 });
  }
  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    console.error('FCM_SERVICE_ACCOUNT_JSON missing required fields');
    return new Response('config-failed', { status: 500 });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (e) {
    console.error('access-token mint failed', e);
    return new Response('auth-failed', { status: 500 });
  }

  const projectId = serviceAccount.project_id;
  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  let sent = 0;
  for (const device of lookup.tokens) {
    try {
      const res = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: device.token,
            notification: { title, body },
            data,
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  'content-available': 1,
                },
              },
            },
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: 'default',
              },
            },
          },
        }),
      });
      if (res.ok) {
        sent += 1;
      } else {
        const text = await res.text();
        console.warn(
          `FCM send failed for token ${device.token.slice(0, 12)}…: ${res.status} ${text}`,
        );
        // 404 / 410 — token invalid; could prune from device_tokens here.
        if (res.status === 404 || res.status === 410) {
          await supabase
            .from('device_tokens')
            .delete()
            .eq('token', device.token);
        }
      }
    } catch (e) {
      console.warn('FCM send threw', e);
    }
  }

  return jsonResponse({ ok: true, sent });
});

// ----------------------------------------------------------------------------
function categoryFor(
  kind: string,
): 'friend_requests' | 'tournaments' | 'feed' | 'other' {
  if (kind === 'friend_request' || kind === 'friend_accepted') {
    return 'friend_requests';
  }
  if (kind.startsWith('tournament_')) return 'tournaments';
  if (kind === 'system') return 'other';
  return 'feed';
}

function composeNotificationCopy(
  p: NotificationPayload,
): { title: string; body: string } {
  const payloadTitle = p.payload?.title;
  const payloadBody = p.payload?.body;
  if (typeof payloadTitle === 'string' && payloadTitle.length > 0) {
    return {
      title: payloadTitle,
      body: typeof payloadBody === 'string' ? payloadBody : '',
    };
  }
  // Fall back to kind-based defaults — mirrors AppNotification.title.
  const titles: Record<string, string> = {
    friend_request: 'New friend request',
    friend_accepted: 'Friend request accepted',
    tournament_invite: 'Tournament invite',
    tournament_member_approved: 'You were approved for a tournament',
    tournament_member_rejected: 'Tournament request declined',
    tournament_entry_approved: 'Your catch was approved',
    tournament_entry_rejected: 'Your catch was rejected',
    system: 'Notification',
  };
  return {
    title: titles[p.kind] ?? 'Notification',
    body: typeof payloadBody === 'string' ? payloadBody : '',
  };
}

function deeplinkFor(p: NotificationPayload): string {
  const explicit = p.payload?.deeplink_path;
  if (typeof explicit === 'string' && explicit.length > 0) return explicit;
  const tid = p.payload?.tournament_id;
  if (typeof tid === 'string' && tid.length > 0) return `/tournaments/${tid}`;
  if (p.kind === 'friend_request' || p.kind === 'friend_accepted') {
    return '/friends';
  }
  const cid = p.payload?.catch_id;
  if (typeof cid === 'string' && cid.length > 0) return `/catches/${cid}`;
  return '/me/notifications';
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

// ----------------------------------------------------------------------------
// FCM HTTP v1 OAuth token mint via service-account JWT.
// Uses Web Crypto API; no Firebase Admin SDK dependency required.
// ----------------------------------------------------------------------------
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
  );
  const claim = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    })),
  );

  const unsigned = `${header}.${claim}`;
  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(sig))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`oauth token exchange ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  return json.access_token as string;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // Strip PEM header/footer and whitespace, then base64-decode to DER.
  const der = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binary = Uint8Array.from(atob(der), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binary.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}
