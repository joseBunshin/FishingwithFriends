# Mac/Xcode walkthrough — TestFlight to App Store

The literal click-by-click guide for shipping Fishing with Friends to TestFlight and the App Store from a Mac. Designed to be followed linearly without flipping between docs.

Companion to:
- [`ios.md`](./ios.md) — procedural overview
- [`ios-checklist.md`](./ios-checklist.md) — tick-through punch list
- [`ios-capabilities.md`](./ios-capabilities.md) — capabilities + App Store Connect declarations

If something differs between this doc and the others, **this doc wins** for the Mac/Xcode steps.

---

## 0. Prerequisites

You'll need:

- **A Mac** running macOS 14 (Sonoma) or 15 (Sequoia). Apple Silicon recommended (Intel works but slower).
- **Apple ID** for the Bunshin Development Studios account.
- **Apple Developer Program enrollment** ($99/yr, on the Bunshin Apple ID).
- **App Store Connect access** for that same Apple ID, with the FWF app record created and bundle id `com.bunshin.fishingWithFriends` reserved.
- **A real iPhone** (running iOS 16+) for end-to-end TestFlight testing.
- **Lightning/USB-C cable** to plug the iPhone into the Mac for the first build.
- **GitHub access** to the `joseBunshin/FishingwithFriends` repo.
- **Production Firebase iOS config file** — `GoogleService-Info.plist` downloaded from Firebase Console → Project Settings → iOS app.
- **Production `.env`** values (Supabase URL + anon key for the **prod** project).

If any of those are missing, sort them before continuing — most can take hours of waiting (DUNS for Apple Developer enrollment) or vendor coordination.

---

## 1. First-time Mac environment setup

Skip this whole section if Flutter already builds iOS apps on this Mac.

### 1.1 Install Xcode

```bash
# Install from the Mac App Store (free, ~10 GB).
open "macappstore://apps.apple.com/app/xcode/id497799835"
```

After install, accept the license and install the Command Line Tools:

```bash
sudo xcodebuild -license accept
sudo xcode-select --install     # opens GUI installer
xcodebuild -runFirstLaunch       # does platform installs
```

Verify:

```bash
xcodebuild -version
# Xcode 16.x or 15.x
```

### 1.2 Install Homebrew + tooling

```bash
# Homebrew (skip if already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Flutter SDK
brew install --cask flutter

# CocoaPods (iOS dependency manager)
brew install cocoapods

# Optional but useful
brew install --cask transporter   # one-click IPA upload
brew install gh                    # GitHub CLI
```

Run `flutter doctor` and fix every red `[✗]`:

```bash
flutter doctor
# Common follow-ups:
sudo gem install cocoapods               # if pod is older
flutter doctor --android-licenses        # for the cross-platform build
```

You don't need a green Android setup to ship to iOS, but Flutter complains if it's missing — `[!]` is fine, `[✗]` for the iOS toolchain is not.

### 1.3 Sign in to Xcode with the Bunshin Apple ID

Xcode → Settings → Accounts → **+** → Apple ID → enter Bunshin credentials. Make sure the team **Bunshin Development Studios LLC** appears under "Team" in the right pane.

---

## 2. First-time repo setup on this Mac

```bash
cd ~/dev    # or wherever you keep code
git clone https://github.com/joseBunshin/FishingwithFriends.git
cd FishingwithFriends

git checkout main   # or the release branch you're shipping
git pull
```

### 2.1 Drop in the production secrets

These files are gitignored — they don't come from the clone.

```bash
# 1. Production .env (Supabase prod URL + anon key)
cp .env.example .env
# Edit .env and paste in the production values
nano .env
```

```bash
# 2. Production Firebase iOS config — download from Firebase Console
#    → Project Settings → "Your apps" → iOS app → GoogleService-Info.plist
#    Save it here:
#    ios/Runner/GoogleService-Info.plist
mv ~/Downloads/GoogleService-Info.plist ios/Runner/
```

> Do **not** commit `GoogleService-Info.plist` for the production Firebase project. The dev one is fine to commit; the prod one stays out of git via `.gitignore`. Verify with `git status` — it should not appear.

### 2.2 Pull dependencies

```bash
flutter pub get
cd ios && pod install && cd ..
```

If `pod install` fails:

```bash
cd ios
pod repo update
pod install --repo-update
cd ..
```

If it still fails on a Firebase / gRPC / BoringSSL build error, your Xcode is too old — update Xcode and retry.

### 2.3 Quick sanity check

```bash
flutter analyze   # should be clean
flutter test      # should be all-pass except known router/AppShell tests
```

---

## 3. Open the project in Xcode (correctly)

**ALWAYS open `Runner.xcworkspace`, never `Runner.xcodeproj`.** Pods are configured at the workspace level; opening the project file leaves them out and the build fails confusingly.

```bash
open ios/Runner.xcworkspace
```

In the left **Project navigator**, click the top-level `Runner` blueprint icon. A wide editor pane appears with tabs across the top.

---

## 4. Signing & Capabilities (one-time)

### 4.1 Signing

Click the **Signing & Capabilities** tab.

- Select the `Runner` target (left side of the editor pane).
- **Automatically manage signing** → checked.
- **Team** → select **Bunshin Development Studios LLC**.
- **Bundle Identifier** → must be exactly `com.bunshin.fishingWithFriends`.

Xcode will auto-create a development provisioning profile. If you see a red banner like "Failed to register a bundle identifier", click **Try Again** — sometimes Apple's portal lags.

### 4.2 Add capabilities

Click **+ Capability** (button just under the Signing section). Add **two**:

1. **Push Notifications**
   - Single click. Done.
2. **Background Modes**
   - Click. In the new section, check **Remote notifications**.

These two together create `ios/Runner/Runner.entitlements`. You'll see it appear in the Project navigator.

You should *not* enable any other capability at this stage. See [`ios-capabilities.md`](./ios-capabilities.md) §2 for the explicit "skip" list.

### 4.3 Verify the entitlements file

In the navigator, open `Runner.entitlements`. It should contain at minimum:

```xml
<key>aps-environment</key>
<string>development</string>   <!-- or "production" — Xcode flips it per build config -->
```

If `aps-environment` is missing, Push Notifications didn't take. Remove and re-add the capability.

---

## 5. Verify the App ID + APNs key on the Apple side

In a browser, log in at https://developer.apple.com/account → **Certificates, Identifiers & Profiles**.

### 5.1 App ID services

**Identifiers** → click `com.bunshin.fishingWithFriends`. Confirm:

- **Push Notifications** — checked.
- **Sign in with Apple** — *unchecked* (we don't use it).
- Everything else — unchecked.

If Push Notifications wasn't on at App ID creation, check it now → Save.

### 5.2 APNs Auth Key (.p8) → Firebase

This is what lets FCM send pushes to APNs. One-time setup.

1. **Keys** → **+** → name it `FWF APNs` → check **Apple Push Notifications service (APNs)** → Continue → Register.
2. **Download the `.p8`.** You can only download it **once** — store it in 1Password / similar. Note the **Key ID** (10-char string) shown on screen.
3. Note the **Team ID** (top-right of the developer portal — 10-char string).
4. Go to Firebase Console → your prod Firebase project → **Project Settings** → **Cloud Messaging** tab → scroll to **Apple app configuration** → click your iOS app's row → **Upload** under "APNs Authentication Key".
5. Paste in the `.p8` file, **Key ID**, and **Team ID** → Upload.

Verify by sending a test push from Firebase Console → Cloud Messaging → New campaign → Notifications → Send test message after a TestFlight install (covered later).

---

## 6. First end-to-end build on simulator

Sanity check before burning provisioning time on real hardware.

In Xcode's top toolbar, set the destination dropdown to a simulator (e.g. **iPhone 15 Pro**).

```bash
flutter run -d "iPhone 15 Pro"
```

You're checking that:
- Splash → sign-in screen renders.
- You can sign up with a throwaway email.
- (FCM won't work on simulator — that's fine.)

Kill with `q` in the terminal. Move on.

---

## 7. Real-device smoke test (recommended)

Plug in your iPhone via cable. Trust the Mac when prompted. In Xcode's destination dropdown, your phone shows up under "Mac".

```bash
flutter run --release -d <phone-name>
# or just `flutter run -d <phone-name>` for debug — slower but supports hot reload
```

The first run takes ~5 minutes (Xcode signs and provisions). On the phone you may need to **Settings → General → VPN & Device Management → trust the developer profile**.

Test the things that don't work on simulator:
- Camera-path catch logging.
- GPS auto-fill.
- Push notification arrival (kill the app first, then trigger a notification from the dashboard or by inserting into `public.notifications`).

---

## 8. Bump the version

Edit `pubspec.yaml`:

```yaml
version: 1.0.0+1     # marketing+build
```

- Left of `+` (`1.0.0`) — visible to users in the App Store. Bump when you ship a public release.
- Right of `+` (`1`) — build number. **Bump on every Apple-bound build, even the same marketing version.** App Store Connect silently rejects duplicates.

For the very first TestFlight upload: `1.0.0+1`. For the next: `1.0.0+2`, then `+3`, etc. When you cut a public bug-fix release: `1.0.1+1`.

Commit:

```bash
git commit -am "chore: bump to 1.0.0+1 for first TestFlight"
```

---

## 9. Build the IPA

From the repo root on the Mac:

```bash
flutter clean              # only if pubspec or pods changed
flutter pub get
cd ios && pod install && cd ..

flutter build ipa --release
```

The build takes 5–15 min the first time. Output:

```
✓ Built build/ios/ipa/fishing_with_friends.ipa
```

If you see "**Missing provisioning profile**":
- Open Xcode → Signing & Capabilities → click **Try Again** under the Status row.
- Re-run `flutter build ipa --release`.

If you see "**Linker error around Firebase**":
- `cd ios && pod repo update && pod install --repo-update && cd ..`
- Try the build again.

If you see "**Missing privacy manifest**" for a plugin:
- Update that plugin: `flutter pub upgrade <plugin-name>`. Recent plugin versions ship privacy manifests.

---

## 10. Upload to App Store Connect

Two paths — pick **A** (Transporter) for v1, **B** (Xcode Organizer) for iteration.

### 10.1 Path A — Transporter

1. Open **Transporter** (free in the Mac App Store; installed via brew above).
2. Sign in with the Bunshin Apple ID.
3. Drag `build/ios/ipa/fishing_with_friends.ipa` into the window.
4. Click **Deliver**. Apple's automated validation takes 2–10 minutes.
5. You'll get an email at the Bunshin address: "Build for Fishing with Friends has completed processing".

### 10.2 Path B — Xcode Organizer

1. In Xcode, after a successful **Product → Archive** (which `flutter build ipa` already did), open **Window → Organizer**.
2. Pick the latest archive in the Archives tab.
3. Click **Distribute App** → App Store Connect → Upload → defaults → Upload.

Either path lands the build under your app → TestFlight → iOS Builds tab in App Store Connect, with status **Processing** (10–30 min) → **Ready to Submit**.

---

## 11. Answer Export Compliance

After the build appears in App Store Connect:

- Click the build → "Export Compliance" prompt.
- "Does your app use encryption?" → **Yes**
- "Does your app qualify for any of the exemptions?" → **Yes — only uses standard encryption from Apple's OS/iOS frameworks**
- "Available in France?" → **Yes**

You set `ITSAppUsesNonExemptEncryption=false` in `Info.plist` (commit 892b880), so this dialog stops appearing for future builds.

---

## 12. TestFlight — internal testing (Bunshin team only)

App Store Connect → your app → **TestFlight** tab.

### 12.1 First-time setup

1. **App Information** (left sidebar) — fill **Beta App Description** (1–2 paragraphs explaining what the app does) and **Beta App Feedback Email** (`jose.diaz@bunshin.io`).
2. **Test Information** — at least the **Email** and **Privacy Policy URL**. Required before any external testing, optional for internal but fill it anyway.

### 12.2 Add internal testers

- **Internal Testing** group → click **+** → select Bunshin team members from the dropdown (they must already be on your App Store Connect team).
- Save. Each tester gets an email "You're invited to test Fishing with Friends" with a TestFlight install link.
- They install **TestFlight** from the App Store, redeem the invite, and the build appears.

### 12.3 What to test on real iPhone

- [ ] Sign-up + email confirmation.
- [ ] Sign-in / forgot password / reset (the reset link opens in Safari — that's expected for v1).
- [ ] Onboarding flow completes.
- [ ] Log a catch with **camera** + GPS pin populates.
- [ ] Log a catch with **photo library** image.
- [ ] Photo loads from Supabase Storage in feed.
- [ ] Conditions auto-fill on a real catch (verify edge function reachable from prod).
- [ ] Friend request → accept on second account → see friend's catches.
- [ ] Tournament create → invite → leaderboard live update.
- [ ] Push notification arrives **foreground** AND **background** (kill the app and trigger).
- [ ] Settings → °F/°C toggle reflects in conditions display.
- [ ] **Account deletion** — Me → Settings → Danger zone → Delete account → typed `DELETE` confirms → app signs out → re-attempting sign-in fails.

If any of those fails, fix → bump build number → re-upload (steps 8–11) → retest.

### 12.4 Promote to External Testing (optional)

When stable:

- Add a public link OR add up to 10,000 external testers by email.
- External Testing **requires Apple's Beta App Review** — usually < 24h, sometimes < 4h.
- A reviewer installs and runs your app; same rejection categories as App Store review (broken sign-up, crashes, missing privacy strings).

---

## 13. App Store metadata

App Store Connect → your app → **App Store** tab → version **1.0 Prepare for Submission**.

### 13.1 App Information (one-time)

| Field | Value |
|---|---|
| **Subtitle** (30 chars) | from `docs/STORE_LISTINGS.md` |
| **Promotional Text** (170 chars) | from STORE_LISTINGS |
| **Description** (4,000 chars) | from STORE_LISTINGS |
| **Keywords** (100 chars, comma-separated) | from STORE_LISTINGS |
| **Support URL** | https://bunshin.io/support (or homepage) |
| **Marketing URL** (optional) | https://bunshin.io |
| **Privacy Policy URL** | https://bunshin.io/privacy/fishing-with-friends |
| **Primary category** | Sports |
| **Secondary category** | Social Networking |
| **Copyright** | © 2026 Bunshin Development Studios LLC |
| **Age Rating** | 4+ (questionnaire — answer "None" to everything) |

### 13.2 Screenshots

You need at minimum **6.7" iPhone** screenshots (latest devices). Apple uses these scaled down for older sizes, but if you want a polished listing, also upload 6.5" and 5.5".

Required: **3–10 screenshots per size class.**

Capture from a real device:
- Hold **Volume Up + Side button** simultaneously.
- AirDrop the PNGs to the Mac.
- Or use simulator: **Cmd + S** in the simulator window.

Suggested screenshot set:
1. Home feed with friends' catches
2. Catch detail with photo + conditions
3. Live tournament leaderboard
4. Catch map with pins
5. Year-in-Review hero
6. Profile with badges

### 13.3 App preview video (optional)

15–30 second portrait video. Skip for v1 — can add later.

### 13.4 App Privacy nutrition label (one-time)

App Information → **App Privacy** → Get Started.

Fill exactly per [`ios-capabilities.md`](./ios-capabilities.md) §4.3:

- **Data Linked to User**: Email, User ID, Name, Photos, Coarse Location, User Content, Device ID, Diagnostics
- **Data Used to Track You**: NONE
- For each type: select **App Functionality** as the purpose. Toggle off "Used for Tracking" everywhere.

This step takes ~30 minutes and is the most error-prone — work through it carefully. App Review will reject mismatches between your Info.plist permissions and your declared data types.

### 13.5 Pricing and Availability

- **Price** → Free (Tier 0)
- **Availability** → All territories (or restrict if there's a reason)

### 13.6 Account deletion declaration

App Information → "Does your app support account deletion?" → **Yes** → users can delete via Me → Settings → Danger zone → Delete account.

---

## 14. Build assignment + submit for review

Still in the version page:

1. Scroll to **Build** section → click **+ Add Build** → pick the TestFlight build that passed your QA.
2. Scroll to **App Review Information**:
   - **Sign-in required** → Yes
   - **User name + Password** → demo account credentials. Create one explicitly for review (e.g. `apple-reviewer@bunshin.io`) seeded with friends, catches, and a tournament so reviewers can exercise everything.
   - **Notes** → "Friends-only social fishing app. GPS used to geotag catches when the user logs one. Camera for catch photos. Push for friend/tournament notifications. No paywalls in v1. To delete the account: Me → Settings → Danger zone → Delete account."
   - **Contact** → Jose Diaz, jose.diaz@bunshin.io, +1 phone.
3. Scroll to **Version Release** → choose:
   - **Manually release this version** — recommended for v1 so you can do a final smoke test before it's live.
   - OR Automatically release after approval.
4. Scroll up. Click **Save**, then **Add for Review**, then **Submit for Review**.

Status moves: **Waiting for Review** → **In Review** → **Pending Developer Release** (or **Ready for Sale** if you chose auto-release).

Typical v1 turnaround: **24–48 hours**. Subsequent versions usually < 12h.

---

## 15. After approval

- **If you chose Manual** — go to App Store Connect → click **Release this version**. App is live within 1–4h.
- **If you chose Automatic** — already live.
- Smoke test with the production App Store install (don't use TestFlight).
- Monitor for **48h**:
  - Supabase Dashboard → Logs (auth, edge functions, postgres).
  - Firebase Crashlytics.
  - App Store Connect → Analytics for installs and crashes.

```sql
-- Healthy push pipeline check after a few real installs
select platform, count(*) from public.device_tokens group by platform;
```

Tag the release commit:

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 16. Iteration loop (subsequent uploads)

For every fix or feature update:

1. Make changes on a branch → merge to main.
2. **Bump build number** in `pubspec.yaml` (e.g. `1.0.0+2`, `1.0.1+1`, `1.1.0+1`).
3. `flutter clean && flutter pub get && cd ios && pod install && cd ..`
4. `flutter build ipa --release`
5. Transporter upload.
6. Wait for the build to process in App Store Connect (5–10 min).
7. **For TestFlight only** — assign to your testing group and ship. No review for build-number bumps within the same marketing version.
8. **For App Store** — bump the marketing version, fill **What's New in This Version** (the release notes), assign the build, submit for review.

You skip §1, §2, §4, §5 entirely. They're one-time.

---

## 17. Common rejection reasons (and how to dodge them)

| Reason | Fix |
|---|---|
| **Vague Info.plist usage strings** | Already fixed — strings explain *why* |
| **Missing privacy policy URL** | Host policy at https://bunshin.io/privacy/fishing-with-friends before submitting |
| **Demo account credentials missing or non-functional** | Verify the `apple-reviewer@bunshin.io` account is seeded and the password works |
| **Crashes on first launch on a fresh install** | Run §12.3 on a non-developer's iPhone |
| **Missing in-app account deletion (5.1.1(v))** | Already wired (commit 617e3ea) — verify on TestFlight |
| **"Minimum functionality" rejection** | The catch + tournament + push flows clear the bar; just don't paywall the core flow on launch |
| **Privacy label mismatch with Info.plist** | The nutrition label must declare every data type matching your `NS*UsageDescription` keys + the FCM token + email |
| **Apple-Sign-in required because you have third-party login** | We're email-only — doesn't apply. Stays "doesn't apply" until you add Google/Facebook/etc. |

---

## 18. Quick reference — file paths on the Mac

| Path | What |
|---|---|
| `~/dev/FishingwithFriends/` | Repo root |
| `~/dev/FishingwithFriends/.env` | Production Supabase secrets (gitignored) |
| `~/dev/FishingwithFriends/ios/Runner.xcworkspace` | What you open in Xcode |
| `~/dev/FishingwithFriends/ios/Runner/GoogleService-Info.plist` | Production Firebase config (gitignored) |
| `~/dev/FishingwithFriends/ios/Runner/Info.plist` | Already configured |
| `~/dev/FishingwithFriends/ios/Runner/Runner.entitlements` | Created when you add the Push capability |
| `~/dev/FishingwithFriends/build/ios/ipa/fishing_with_friends.ipa` | What you upload |

---

## TL;DR — first ship in 12 commands

```bash
# Mac setup (one-time)
brew install --cask flutter transporter
brew install cocoapods

# Repo setup (one-time, on this Mac)
git clone https://github.com/joseBunshin/FishingwithFriends.git
cd FishingwithFriends
cp .env.example .env && nano .env
# place GoogleService-Info.plist in ios/Runner/
flutter pub get
cd ios && pod install && cd ..

# Open in Xcode → Signing & Capabilities → Bunshin team + Push + BG Modes
open ios/Runner.xcworkspace

# Build
flutter build ipa --release

# Drag build/ios/ipa/fishing_with_friends.ipa into Transporter → Deliver

# Then App Store Connect: TestFlight → Internal Testing → install → smoke test
# Then App Store tab → fill metadata → assign build → Submit for Review
```
