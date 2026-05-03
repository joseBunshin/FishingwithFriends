# iOS capabilities, services, and App Store Connect declarations

Audit of every Apple capability + App Store Connect declaration FWF v1 needs (or explicitly does **not** need), mapped to what the app actually uses. Companion to [`ios.md`](./ios.md) and [`ios-checklist.md`](./ios-checklist.md).

Bundle id: `com.bunshin.fishingWithFriends`

---

## 1. Capabilities to enable in Xcode

Open `ios/Runner.xcworkspace` → **Signing & Capabilities** tab. Click **+ Capability** and add each row below. Both will auto-generate `ios/Runner/Runner.entitlements` — Apple provisions the entitlements automatically during archive.

| # | Capability | Why FWF needs it | Where it's used |
|---|---|---|---|
| 1 | **Push Notifications** | FCM delivers via APNs. Without this every push silently drops. | `lib/features/notifications/application/push_*` + `supabase/functions/push-dispatch/` |
| 2 | **Background Modes** → check **Remote notifications** | Lets FCM wake the app for data-only payloads so the background handler can act. | `lib/features/notifications/application/push_background_handler.dart` |

**Verify after enabling:**

- `ios/Runner/Runner.entitlements` exists and contains `aps-environment`.
- `ios/Runner.xcodeproj/project.pbxproj` references `Runner.entitlements` under both Debug and Release.
- A clean `flutter build ipa --release` finishes without "missing entitlement" warnings.

## 2. Capabilities you do **not** need

This list is here so a reviewer (you, future you, a contractor) doesn't second-guess. Each is a deliberate "no", not an oversight.

| Capability | Status | Reason |
|---|---|---|
| **Sign in with Apple** | Skip | Only required if you offer a **third-party** social login (Google, Facebook, Twitter). FWF uses email-only Supabase Auth — Apple's mandate doesn't trigger. Reconsider before adding any social provider. |
| **Associated Domains** | Skip for v1 | Used for Universal Links and Password-Reset-Through-App. `resetPasswordForEmail` currently opens the reset URL in Safari and the user finishes there — acceptable, mildly clunky. Add when wiring `bunshin.io` deep links. |
| **HealthKit / HomeKit / Siri / CallKit / ClassKit** | Skip | None of those domains apply to FWF. |
| **In-App Purchase / StoreKit / Game Center** | Skip for v1 | No paid tiers, no leaderboards on Game Center (tournaments are app-internal). Reconsider when monetisation lands. |
| **iCloud / CloudKit / App Groups / Keychain Sharing** | Skip | Supabase owns persistence; no extension targets, no shared keychain. |
| **MapKit** | Skip | `flutter_map` renders OpenStreetMap tiles directly — no Apple Maps capability required. |
| **Data Protection** | Default | The default protection level (`NSFileProtectionComplete` while locked) is appropriate for FWF's threat model. |
| **Family Controls / Communication Notifications / Group Activities (SharePlay)** | Skip | Not relevant. |
| **Network Extensions / Hotspot / VPN** | Skip | Standard URLSession/HTTPS only. |
| **Wallet / Passes** | Skip | No tickets, no passes. |
| **MusicKit / HomeKit / CarPlay** | Skip | Out of scope. |

### Special capabilities (require Apple justification)

Apple gates HealthKit, HomeKit, Family Controls, CarPlay, MusicKit, MDM, NetworkExtension, and Wallet/Passes behind a request form. **None apply to FWF.** Skip the request flow entirely.

## 3. Info.plist declarations

### 3.1 Already in place (✓)

`ios/Runner/Info.plist` already declares:

| Key | Why |
|---|---|
| `NSCameraUsageDescription` | image_picker — camera path for catch photos |
| `NSPhotoLibraryUsageDescription` | image_picker — library path for catch photos |
| `NSPhotoLibraryAddUsageDescription` | future "save catch photo back to library" affordance |
| `NSLocationWhenInUseUsageDescription` | geolocator — catch geotag |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | geolocator — same, but covers OS asking the broader prompt |
| `CADisableMinimumFrameDurationOnPhone` | enables 120Hz on ProMotion displays |

All four privacy strings explain *why* in human language — required to clear App Review.

### 3.2 Add before first TestFlight upload

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>

<key>LSApplicationCategoryType</key>
<string>public.app-category.sports</string>
```

| Key | Reason |
|---|---|
| `ITSAppUsesNonExemptEncryption=false` | We use standard HTTPS only. Setting this bypasses the export-compliance question on every build and is required to skip the in-ASC dialog after each upload. |
| `LSApplicationCategoryType=public.app-category.sports` | Mirrors the App Store category. Cosmetic, but it's what App Store Connect expects. |

### 3.3 Privacy manifest (`PrivacyInfo.xcprivacy`)

Apple requires app-level + SDK-level privacy manifests as of 2024. Status:

- **Flutter framework** — ships its own privacy manifest in recent versions. No action.
- **Plugins** (firebase_messaging, geolocator, image_picker, supabase_flutter, etc.) — each plugin must ship its own. Recent Flutter versions auto-bundle theirs. If `flutter build ipa` warns about missing privacy manifests for a specific dependency, upgrade that plugin.
- **App-level manifest** — only required if you read the listed sensitive APIs *outside* of plugin code. FWF doesn't, so an app-level `PrivacyInfo.xcprivacy` is **not** required. Add only if App Review flags it during submission.

## 4. App Store Connect declarations

These are filled in App Store Connect, not Xcode. They map directly to FWF behaviour.

### 4.1 Encryption export compliance

| Question | Answer |
|---|---|
| Does your app use encryption? | **Yes** (HTTPS / TLS counts) |
| Does your app qualify for any of the exemptions? | **Yes — only uses standard encryption from Apple's OS / iOS frameworks** |
| Is your app available in France? | **Yes** (no extra French export controls trigger for HTTPS-only) |

Setting `ITSAppUsesNonExemptEncryption=false` (§3.2) means ASC stops asking after the first upload.

### 4.2 App Tracking Transparency (ATT)

| Question | Answer | Notes |
|---|---|---|
| Does your app track users? | **No** | We have no third-party analytics or advertising SDKs. We do not link app data to data from other companies for advertising/measurement. |
| Will the app prompt for ATT? | **No** | Skip the `NSUserTrackingUsageDescription` plist entry. |

If a future v1.x adds Mixpanel / Amplitude / similar, this answer changes — revisit.

### 4.3 Privacy nutrition label

App Store Connect → App Privacy → start the form. Declare each data type once.

**Data Linked to User** (we collect, tied to identity):

| Data type | Used for | Tracking? |
|---|---|---|
| Email address | Account, auth, transactional email | No |
| User ID (Supabase UUID) | Account, app functionality | No |
| Name (display name) | App functionality, social presence to friends | No |
| Photos (catch photos, avatar) | App functionality | No |
| Coarse Location (GPS at catch time) | App functionality (catch geotag, map) | No |
| User Content (catches, comments, chat, reactions, trips, tournaments) | App functionality, social interactions | No |
| Device ID (FCM/APNs token) | App functionality (push delivery) | No |
| Diagnostics (crash logs) | App functionality (Crashlytics) | No |

**Data Not Linked to User**: none.

**Data Used to Track You**: **NONE.** This is the headline label users see — it should read "Data Not Used to Track You".

### 4.4 Account deletion (Apple Guideline 5.1.1(v))

| Question | Answer |
|---|---|
| Does your app support account creation? | **Yes** (Supabase email signup) |
| Does your app support in-app account deletion? | **Yes** — Me → Settings → Danger zone → Delete account |
| What is deleted? | Profile, catches, photos, friend connections, tournament memberships/entries, notifications, device tokens, FCM preferences. Storage objects under `avatars/<uid>/` and `catches/<uid>/`. The `auth.users` row itself. |
| How? | The app calls the `delete-account` edge function (`supabase/functions/delete-account/`) which uses the service-role key to wipe storage and call `auth.admin.deleteUser(uid)`. |

### 4.5 App Review Information

| Field | What to provide |
|---|---|
| Sign-in required? | **Yes** |
| Demo account | Create a reviewer-only account on prod, e.g. `apple-reviewer@bunshin.io` with a memorable password. Pre-seed it with at least one friend, one trip, one tournament, and a few catches so reviewers see the full UX. |
| Notes | "Friends-only social fishing app. GPS used to geotag catches when the user logs one. Camera for catch photos. Push for friend/tournament notifications. No paywalls in v1." |
| Contact | jose.diaz@bunshin.io |

### 4.6 Other ASC fields

| Field | Value |
|---|---|
| Primary category | **Sports** |
| Secondary category | **Social Networking** |
| Age rating | **4+** |
| Copyright | `© 2026 Bunshin Development Studios LLC` |
| Support URL | https://bunshin.io/support (or the Bunshin homepage) |
| Marketing URL | Same |
| Privacy Policy URL | https://bunshin.io/privacy/fishing-with-friends |

## 5. Apple Developer portal — App ID services

Verify in https://developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → `com.bunshin.fishingWithFriends`. The following App Services should be **enabled**:

- [ ] **Push Notifications**
- [ ] **Sign in with Apple** — leave **off** (no third-party login)
- [ ] **Associated Domains** — leave off until v1.x deep-link work
- [ ] **iCloud / Game Center / HealthKit / HomeKit / Wallet / Apple Pay / DeviceActivity / etc.** — all off

If Push Notifications wasn't enabled at App ID creation, click Edit → toggle Push → Configure → upload an **APNs Auth Key (.p8)** if not already done. The same key goes to Firebase Console → Project Settings → Cloud Messaging.

## 6. TL;DR — minimum changes before TestFlight

1. **Xcode** — enable Push Notifications + Background Modes → Remote notifications.
2. **Info.plist** — add `ITSAppUsesNonExemptEncryption=false` and `LSApplicationCategoryType=public.app-category.sports`.
3. **App Store Connect** — fill privacy nutrition label per §4.3, set ATT = "does not track", confirm in-app account deletion per §4.4.
4. **Apple Developer portal** — confirm Push Notifications service is enabled on the App ID and the APNs Auth Key (.p8) is in Firebase.

Anything not on this list should stay disabled to keep the attack surface and review burden minimal.
