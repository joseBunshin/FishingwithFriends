# Deployment readiness — Fishing with Friends v1.0.0

This is the gate-check before the iOS App Store and Google Play deployments. Code-side, the app is ready. Process-side, several non-code items have to land before submission.

---

## What's already in place

| Surface | Status |
|---|---|
| App identity | `com.bunshin.fishing_with_friends` (Android), `com.bunshin.fishingWithFriends` (iOS) |
| Version | `1.0.0+1` in `pubspec.yaml` |
| App icon + native splash | Generated via `flutter_launcher_icons` + `flutter_native_splash` (M7/U11) |
| Bunshin studio splash | Animated cyan-ghost intro (`lib/features/splash/...`) |
| Database migrations | 0001 → 0022 — see `docs/SUPABASE_SETUP.md` |
| Edge functions | `conditions-fill` + `push-dispatch` — see `docs/EDGE_FUNCTIONS.md` |
| Auth + transactional email | Sign-in / sign-up / forgot-password / reset; templates at `docs/EMAIL_TEMPLATES.md` |
| Push notifications | Firebase + Supabase pipeline (M6c) — service account configured per project |
| Store listing copy | Drafted in `docs/STORE_LISTINGS.md` |
| `flutter analyze` | Clean across the full repo |
| Tests | 45 widget + unit tests pass |

## Pre-deployment checklist

These have to happen **once per target platform** before first submission. Subsequent versions reuse the configuration.

### Both platforms

- [ ] **Privacy policy URL** — Apple and Google both require a publicly hosted policy. Bunshin Studios needs to host one (e.g. `https://bunshin.io/privacy/fishing-with-friends`). Cover: Supabase Auth, Supabase Storage (avatar + catch photos), location data, FCM push tokens, conditions enrichment via Open-Meteo.
- [ ] **Support / contact email** — `jose.diaz@bunshin.io` already used in app's Settings → About; same address works for store listings.
- [ ] **Marketing icon (1024×1024 PNG, no transparency)** — `assets/icon/app_icon.png` exists; verify it's flat-no-alpha for both stores.
- [ ] **Screenshots** — at least 2 hero screenshots per device class. Capture on device or via simulators with the dev seed populated.
- [ ] **App categorization** — primary "Sports", secondary "Social Networking" (matches `STORE_LISTINGS.md`).
- [ ] **Age rating** — 4+ on iOS, "Everyone" on Google Play. No user-generated public content (friends-only model).

### iOS-only

- [ ] **Apple Developer Program membership** — Bunshin Studios LLC enrolled ($99/year).
- [ ] **App Store Connect record created** with bundle ID `com.bunshin.fishingWithFriends`.
- [ ] **Distribution certificate + provisioning profile** generated in Apple Developer portal.
- [ ] **APNs key uploaded to Firebase** (push notifications) — APNs Auth Key (`.p8` file) tied to the Bunshin team.
- [ ] **Sign in with Apple** — required if ANY social login is used. We use email-based Supabase Auth, so Apple login isn't yet wired. Decision needed: add Apple Sign-In before launch, or stay email-only (still allowed).
- [ ] **Privacy nutrition labels** — declare collected types (Supabase Auth = email + user ID; catch photos; coarse location). 30-min Apple form.

### Android-only

- [ ] **Google Play Console account** — Bunshin Studios developer account ($25 one-time).
- [ ] **App signing keystore** — `android/key.properties` + `android/app/upload-keystore.jks` (both gitignored). Generate with `keytool -genkey -v -keystore ...`. Back the `.jks` up to a secure place — losing it means losing the ability to push updates.
- [ ] **Play Integrity API** — enabled on the Google Cloud project for the app, used by Firebase for app verification.
- [ ] **Data safety form** — Play Console equivalent of Apple's privacy nutrition labels.
- [ ] **Internal testing track** — first release goes here, not directly to Production.

### Server-side

- [ ] **Production Supabase project locked** — current `fishing-with-friends-bunshin` project is dev. Decision: split into prod + staging, or run dual-purpose for v1 launch.
- [ ] **Edge functions deployed** to the production project (see `docs/EDGE_FUNCTIONS.md`).
- [ ] **`fwf_app_settings` rows seeded** for both edge function URLs + the FCM service account JSON.
- [ ] **`avatars` bucket public, `catches` bucket private** — verified per migration 0019 + 0002.
- [ ] **Realtime enabled** for `tournament_entries` + `tournament_chat_messages` (Database → Replication).
- [ ] **Auth email templates customized** — see `docs/EMAIL_TEMPLATES.md`. Plug into Supabase Dashboard → Authentication → Email Templates.

### Pre-launch QA on real devices

- [ ] Sign-up + email confirmation roundtrip
- [ ] Catch logging with camera + GPS (real device, not simulator)
- [ ] Photo upload + signed-URL retrieval
- [ ] Push notification arrival (foreground + background)
- [ ] Conditions auto-fill on a real catch (verify edge function reachable from prod)
- [ ] Tournament create + invite + leaderboard live update
- [ ] Friends-only RLS — log in as a non-friend, verify no catches visible

---

## Per-platform guides

- **iOS** — see [`docs/deployment/ios.md`](./ios.md)
- **Android** — see [`docs/deployment/android.md`](./android.md)
