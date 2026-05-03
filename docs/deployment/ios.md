# iOS — App Store deployment

End-to-end steps to ship Fishing with Friends to TestFlight and the App Store. Assumes the [`README.md`](./README.md) checklist is complete (Apple Developer enrolment, App Store Connect record, certificates, screenshots, privacy policy URL).

This guide must be run on a Mac with Xcode 15+ — the Flutter iOS build chain doesn't work on Windows or Linux.

---

## 1. One-time setup on the Mac

```bash
# Clone if not already
git clone https://github.com/joseBunshin/FishingwithFriends.git
cd FishingwithFriends
git checkout feat/m7-onboarding-polish  # or main once merged

# Flutter dependencies
flutter pub get

# CocoaPods
cd ios && pod install && cd ..
```

Open `ios/Runner.xcworkspace` (NOT `Runner.xcodeproj`) in Xcode.

In Xcode:

1. **Signing & Capabilities** — select the Bunshin team. Xcode auto-provisions the certificate + profile.
2. **Capabilities** — verify **Push Notifications** is on (FCM uses APNs).
3. **Capabilities** — verify **Background Modes → Remote notifications** is on.
4. **Info.plist** — confirm `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` all have human-readable copy that explains *why*. Apple rejects vague ones.

## 2. Bump the version

`pubspec.yaml`:

```yaml
version: 1.0.0+1
```

- Left of `+`: marketing version (`1.0.0`) — visible to users in the App Store.
- Right of `+`: build number (`1`) — must increment every TestFlight upload, even for the same marketing version. App Store Connect rejects duplicates.

For first submission keep `1.0.0+1`. For TestFlight iterations bump to `1.0.0+2`, `1.0.0+3`, etc. For a public bug-fix release bump to `1.0.1+N` and reset `N` if you want, but bumping is fine.

## 3. Build the IPA

From the repo root on the Mac:

```bash
flutter build ipa --release
```

Output: `build/ios/ipa/fishing_with_friends.ipa`.

**Common build failures:**
- *Missing provisioning profile* — open the project in Xcode, hit "Try Again" under Signing & Capabilities, let it auto-provision.
- *Pod outdated* — `cd ios && pod repo update && pod install --repo-update`.
- *Linker error around firebase* — `ios/Podfile` should pin `platform :ios, '13.0'` minimum (already set per the repo).

## 4. Upload to App Store Connect

Two paths, pick one:

### Option A: Transporter app (simpler)

1. Open **Transporter** (free in the Mac App Store).
2. Sign in with the Bunshin Apple ID.
3. Drag `build/ios/ipa/fishing_with_friends.ipa` into the window.
4. Click **Deliver**. Upload + Apple's automated validation takes ~5 minutes.

### Option B: Xcode Organizer

1. In Xcode: **Window → Organizer → Archives**.
2. Distribute App → App Store Connect → Upload.
3. Same automated validation flow.

After upload, App Store Connect emails you when the build is processed (10–30 min). It then appears under your app's TestFlight + Builds tab.

## 5. TestFlight — internal review

1. App Store Connect → your app → **TestFlight**.
2. Add the build to **Internal Testing** group (Bunshin team members).
3. Each tester gets an email with a TestFlight install link.
4. Test on real iPhone:
   - Sign up + confirm email
   - Log a catch with camera + GPS
   - Verify photo loads from Supabase
   - Confirm a push notification arrives
   - Run through tournament create + invite + leaderboard
5. Iterate on bugs. Each fix → bump build number → re-upload.

When stable, promote to **External Testing** (up to 10,000 testers, requires Apple's Beta App Review — usually <24h).

## 6. App Store submission

1. App Store Connect → your app → **App Store** tab.
2. Fill in:
   - **App Name**: Fishing with Friends
   - **Subtitle, Promotional Text, Description, Keywords** — pull from `docs/STORE_LISTINGS.md`.
   - **Screenshots** — 6.7" and 5.5" displays minimum. Upload PNGs from real device or simulator.
   - **App Privacy** — fill the nutrition label form. We collect: email (Auth), user-generated content (catches/photos), location (catch GPS), device ID (FCM token).
   - **Age rating** — 4+. No restricted content.
   - **Support URL**, **Marketing URL**, **Privacy Policy URL**.
3. Select the build to ship from TestFlight Builds.
4. Submit for review.

Apple review typically takes 24–48h for v1. Subsequent versions are usually <12h.

## 7. After approval

- App goes live based on your release setting (manual or automatic).
- Monitor Crashlytics + Supabase logs for the first 48h.
- Increment build number for hotfixes.
- Subsequent releases skip steps 1–4 setup; just bump version, build, upload, submit.

---

## Push notification verification

After TestFlight install:

```sql
-- Confirm device token registered
select user_id, platform, last_seen_at
from public.device_tokens
where user_id = (select id from auth.users where email = 'YOUR_TEST_EMAIL');
```

Manually trigger a push by inserting a notification:

```sql
insert into public.notifications (recipient_id, kind, payload)
values (
  (select id from auth.users where email = 'YOUR_TEST_EMAIL'),
  'system',
  '{"title": "Test", "body": "Push pipeline check"}'
);
```

The 0018 trigger fires `push-dispatch` via `pg_net`. Push should arrive on device within seconds.

If nothing arrives:
- Verify APNs Auth Key uploaded to Firebase Console → Cloud Messaging.
- Verify the FCM service account JSON is in `fwf_app_settings` (`app.settings.fcm_service_account_json`).
- Check Supabase logs for the edge function — `supabase functions logs push-dispatch` (CLI).

---

## Versioning convention

| Marketing version | Build number | Notes |
|---|---|---|
| `1.0.0` | `1` | First TestFlight upload |
| `1.0.0` | `2` | Bug fix during TestFlight |
| `1.0.0` | `3+` | Iterations |
| `1.0.1` | `1` | Public bug-fix release |
| `1.1.0` | `1` | Public minor feature release |
| `2.0.0` | `1` | Major version (breaking UX or schema) |

Increment build number on **every** Apple-bound build, even within the same marketing version. App Store Connect rejects duplicates without explanation.
