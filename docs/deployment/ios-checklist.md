# iOS deployment checklist — Fishing with Friends

Tick-through checklist for shipping `com.bunshin.fishingWithFriends` to TestFlight and the App Store. Companion to [`ios.md`](./ios.md) (procedural detail) and [`README.md`](./README.md) (cross-platform readiness).

Builds **must** run on a Mac with Xcode 15+. Windows/Linux can do everything except the IPA build and Transporter upload.

---

## 0. Accounts & identity (one-time)

- [ ] Apple Developer Program — Bunshin Studios LLC enrolled, $99/yr active
- [ ] App Store Connect record created with bundle ID `com.bunshin.fishingWithFriends`
- [ ] App name reserved: **Fishing with Friends**
- [ ] Primary category: **Sports** · Secondary: **Social Networking**
- [ ] Age rating: **4+**
- [ ] Distribution certificate generated (Apple Developer portal → Certificates)
- [ ] Provisioning profile generated (App Store distribution)
- [ ] APNs Auth Key (`.p8`) downloaded and uploaded to Firebase → Cloud Messaging
- [ ] Test device UDIDs registered (for ad-hoc TestFlight if needed)

## 1. Legal & content prerequisites

- [ ] Privacy policy live at a public URL (e.g. `https://bunshin.io/privacy/fishing-with-friends`) covering: Supabase Auth, Storage (avatars + catch photos), GPS, FCM tokens, Open-Meteo conditions
- [ ] Support URL live (can be a simple page with `jose.diaz@bunshin.io`)
- [ ] Marketing URL live (or set to support URL)
- [ ] Terms of service URL (optional but recommended)
- [ ] Privacy nutrition label answers prepared — collected: email, user ID, user-generated content, photos, coarse location, device ID

## 2. Server-side readiness

- [ ] Production Supabase project locked (decision: dual-purpose for v1 or split prod/staging)
- [ ] All migrations 0001 → 0022 applied to prod
- [ ] Edge functions `conditions-fill` + `push-dispatch` + `delete-account` deployed to prod
- [ ] `fwf_app_settings` rows seeded: `app.settings.conditions_fill_url`, `app.settings.push_dispatch_url`, `app.settings.fcm_service_account_json`
- [ ] `avatars` bucket public · `catches` bucket private (verify in Storage dashboard)
- [ ] Realtime enabled for `tournament_entries` + `tournament_chat_messages`
- [ ] Auth email templates customized in Supabase Dashboard (per `docs/EMAIL_TEMPLATES.md`)
- [ ] Site URL + redirect allowlist updated for prod domain (not localhost)

## 3. Code & config readiness

- [ ] On `main` (or release branch) with all M1–M7 work merged
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (45+ tests pass)
- [ ] `pubspec.yaml` version bumped — first ship: `1.0.0+1`
- [ ] `.env.production` points to prod Supabase URL + anon key (NOT dev)
- [ ] Firebase `GoogleService-Info.plist` is the **production** Firebase iOS config, dropped into `ios/Runner/`
- [ ] `ios/Runner/Info.plist` usage strings explain *why*, not just *what*:
  - [ ] `NSLocationWhenInUseUsageDescription` — "to tag your catches with where you caught them"
  - [ ] `NSCameraUsageDescription` — "to take photos of your catches"
  - [ ] `NSPhotoLibraryUsageDescription` — "to attach existing photos to a catch"
- [ ] App icon `assets/icon/app_icon.png` is 1024×1024, no transparency, no rounded corners (Apple rounds them)
- [ ] Native splash regenerated if assets changed (`dart run flutter_native_splash:create`)

## 4. Mac build prep

- [ ] Repo cloned/pulled to the build Mac
- [ ] `flutter pub get` clean
- [ ] `cd ios && pod install` clean (run `pod repo update && pod install --repo-update` if outdated)
- [ ] Open `ios/Runner.xcworkspace` (NOT the `.xcodeproj`)
- [ ] Xcode → Signing & Capabilities → **Team = Bunshin Studios**, automatic signing on
- [ ] Capability **Push Notifications** enabled
- [ ] Capability **Background Modes → Remote notifications** enabled
- [ ] Build target → iOS 13.0+ (matches `Podfile`)
- [ ] Run on simulator once to confirm clean launch + splash + sign-in screen render

## 5. Build the IPA

- [ ] `flutter build ipa --release` succeeds
- [ ] Output exists: `build/ios/ipa/fishing_with_friends.ipa`
- [ ] No warnings about missing entitlements or stripped frameworks

## 6. Upload to App Store Connect

Pick one path:

- [ ] **Transporter**: drag IPA → Deliver → wait for "Delivery successful"
- [ ] **Xcode Organizer**: Window → Organizer → Archives → Distribute App → App Store Connect → Upload
- [ ] App Store Connect emails "Build processed" within 10–30 min
- [ ] Build appears under app → TestFlight → iOS Builds
- [ ] Export Compliance answered (uses standard HTTPS only → "No" to non-exempt encryption)

## 7. TestFlight — internal

- [ ] Build added to **Internal Testing** group (Bunshin team)
- [ ] Test on real iPhone (NOT simulator):
  - [ ] Sign-up + email confirmation roundtrip
  - [ ] Sign-in / forgot-password / reset
  - [ ] Log a catch with **camera** + GPS pin populates
  - [ ] Log a catch from **photo library**
  - [ ] Catch photo loads from Supabase Storage in feed
  - [ ] Conditions auto-fill on a real catch (edge function reachable)
  - [ ] Friend request → accept → see friend's catches in feed
  - [ ] Friends-only RLS — non-friend account sees nothing
  - [ ] Tournament create + invite + leaderboard live update
  - [ ] Push notification arrives (foreground **and** background — kill app, send)
  - [ ] Settings → °F/°C toggle reflects in conditions display
  - [ ] Offline catch log → reconnects → syncs without dupes
  - [ ] **Account deletion** — Me → Settings → Danger zone → Delete account — typed-DELETE confirmation, RPC succeeds, sign-out lands on `/sign-in`, sign-in with the same email is rejected (account is gone)
- [ ] Promote to **External Testing** (optional, requires Apple Beta App Review ~24h)

## 8. App Store metadata

In App Store Connect → app → App Store tab, version 1.0.0:

- [ ] App name: **Fishing with Friends**
- [ ] Subtitle (30 chars), Promotional Text (170 chars), Description, Keywords — pulled from `docs/STORE_LISTINGS.md`
- [ ] Support URL, Marketing URL, Privacy Policy URL filled
- [ ] **Screenshots** uploaded:
  - [ ] 6.7" iPhone (e.g. 15 Pro Max) — minimum 2, recommend 5–8
  - [ ] 6.5" iPhone — same set rescaled or recaptured
  - [ ] 5.5" iPhone (legacy, sometimes optional — check ASC) — same set
- [ ] App preview video (optional — defer to v1.1)
- [ ] App Privacy nutrition label completed (data types + usage purpose for each)
- [ ] Age rating questionnaire filled (no objectionable content)
- [ ] Copyright: `© 2026 Bunshin Studios LLC`
- [ ] Build selected from TestFlight → Builds dropdown
- [ ] Release option chosen: **Manual** (recommended for v1) or **Automatic on approval**

## 9. Submit for review

- [ ] App Review Information filled:
  - [ ] Demo account credentials (use `jose080391@gmail.com` test account or seed a reviewer-specific one)
  - [ ] Notes: friends-only social model, GPS used for catch geotag, camera for catch photos
- [ ] **Submit for Review** clicked
- [ ] Status moves: Waiting for Review → In Review → (Pending Developer Release | Ready for Sale)
- [ ] Typical v1 turnaround: 24–48h

## 10. After approval

- [ ] Smoke test on production App Store install
- [ ] Monitor Supabase logs (`auth`, `edge functions`, `postgres`) for first 48h
- [ ] Monitor Firebase Crashlytics for first 48h
- [ ] Verify `device_tokens` rows appearing for new installs:
  ```sql
  select platform, count(*) from public.device_tokens group by platform;
  ```
- [ ] Tag the release commit: `git tag v1.0.0 && git push origin v1.0.0`
- [ ] Update `docs/deployment/README.md` "What's already in place" → mark v1 shipped

## 11. Hotfix / next version

- [ ] Bump `pubspec.yaml` build number every upload (`1.0.0+2`, `+3`, …) — duplicate builds get silently rejected
- [ ] Marketing version bumps: `1.0.1` (patch), `1.1.0` (minor), `2.0.0` (major)
- [ ] Steps 5 → 9 only (skip account/setup steps)

---

## Common rejection reasons to dodge up-front

- Vague Info.plist usage strings → fix in §3
- Missing privacy policy URL or wrong URL → fix in §1
- Demo account credentials missing or non-functional → fix in §9
- Crashing on first launch on a fresh install → run the §7 real-device suite, especially on a non-developer's phone
- "Minimum functionality" rejection — Apple wants a real app, not a glorified webview. The catch-logging + tournament + push flows clear this bar; just make sure none are gated behind a paywall on launch
- **Missing in-app account deletion (Guideline 5.1.1(v))** — wired at Me → Settings → Danger zone → Delete account, backed by the `delete-account` edge function (`supabase/functions/delete-account/`). Verify it works end-to-end on TestFlight before submission
