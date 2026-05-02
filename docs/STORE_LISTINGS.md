# Store listings — App Store + Play Console

Submission-ready copy for the v1 launch of Fishing with Friends. Replace
placeholder asset paths with finals before submission. Keep this in sync
when the product evolves — the version of this doc that ships is the one
that gets reviewed.

**Publisher:** Bunshin Studios
**Bundle ID / Application ID:** `com.bunshin.fishing_with_friends`
**Primary category:** Sports
**Secondary category (App Store):** Lifestyle
**Content rating:** 4+ / Everyone

---

## 1. App name + tagline

**App name (both stores):** `Fishing with Friends`

**Subtitle (App Store, 30 char max):**

> `Log catches. Run tournaments.`

**Short description (Play Console, 80 char max):**

> `Log catches, run tournaments with friends, and keep your fishing spots private.`

**Promotional text (App Store, 170 char max — editable without resubmitting):**

> `New: live tournaments with verified leaderboards. Log a catch in 30 seconds, even on a moving boat. Friends-only by default — your spots stay yours.`

---

## 2. Full description (both stores)

> Fishing with Friends is a beautiful logbook and a live tournament app, built for anglers who want their catches to feel like memories — not data entry.
>
> **Log a catch in seconds.** One tap from anywhere in the app. Photo, species, length, weight — done. Auto-fills your weather, water temperature, and tide. Works fully offline; syncs the moment you have signal again.
>
> **Run tournaments with your friends.** Pick a scoring metric — total weight, biggest fish, most catches, longest catch. Invite your group, approve entries as the day goes on, and watch the leaderboard update live. No public leagues, no strangers — just your crew.
>
> **Friends-only by default.** Every catch, every spot, every photo is shared with friends only. Per-catch *Secret Spot* toggle hides exact GPS even from them. Marine Protected Areas never expose precise coordinates.
>
> **Trips that tell a story.** Group your day's catches into a trip. Share a single trip summary instead of a wall of photos.
>
> **Stats that pay you back.** See your best months, your top species, your hot hours of the day, and how the conditions you fished in changed your luck.
>
> **What's in v1**
> • Hero catch logging — photo, species, length, weight, conditions, location
> • Live tournaments with creator-approved entries and side-pots
> • Friends graph + private storage — no public profiles
> • Trips, feed highlights, and shareable trip summaries
> • Catch map with Secret Spot suppression and Marine Protected Area awareness
> • Personal stats: time-of-day heatmap, species breakdown, vs-friends comparison
> • Push notifications: friend requests, tournament invites, entry verifications
> • Year-in-Review reel + share cards (seasonally)
> • Offline-first — log catches without signal, sync when you're back
> • Light + dark themes, lb/kg + in/cm toggles
>
> Built by Bunshin Studios. Freshwater + saltwater. iOS + Android.

---

## 3. Keywords (App Store, 100 char max, comma-separated, no spaces required)

> `fishing,catch,log,tournament,bass,trout,saltwater,tide,angler,friends,leaderboard,offline,trip`

(98 chars. App Store ignores spaces in this field, so the comma-only form
maximizes coverage. Keep `fishing` first; iterate based on App Store
Connect search ranking after launch.)

---

## 4. Screenshots checklist

Capture once on each device class on a clean install with a seeded demo
account. Take both light and dark variants; ship the strongest five per
device.

| # | Frame | What to show |
|---|---|---|
| 1 | Home (Today) | Greeting + last catch hero card + "Log a catch" CTA |
| 2 | Catch detail | Hero photo, species, length/weight in user's units, conditions block populated (auto-filled weather + tide) |
| 3 | Tournament leaderboard | Live leaderboard with 4–5 entries, current user not in #1 |
| 4 | Catch map | Pins with Secret Spot suppression visible, MPA halo on at least one |
| 5 | Stats — Time-of-day heatmap | Filled grid with vs-friends card below |
| 6 | Trip summary | Multi-catch day with shareable layout |
| 7 | Onboarding step 1 | Avatar + handle pick, navy/orange palette |

**Device matrix (Apple):**
- 6.7" (iPhone 15 Pro Max) — required
- 6.5" (iPhone 11 Pro Max) — required
- 5.5" (iPhone 8 Plus) — required if older devices targeted
- 12.9" iPad Pro — only if iPad listing enabled (not v1)

**Device matrix (Google Play):**
- Phone — minimum 2, recommended 8 (1080×1920 portrait or 1920×1080 landscape)
- 7" tablet, 10" tablet — only if tablet support declared (not v1; phones only)

**Asset locations (when generated):**

```
docs/store_assets/
├── ios/
│   ├── 6.7/01-home.png ... 07-onboarding.png
│   ├── 6.5/...
│   └── 5.5/...
└── android/
    └── phone/01-home.png ... 08-trip.png
```

Render with the Sports category in mind — the first frame is what users
see in search; lead with the catch hero, not the dashboard.

---

## 5. Feature graphic (Play Console)

1024×500 PNG. Navy background `#102B47`, orange fish silhouette
(`assets/icon/app_icon_foreground.png` rendered at scale), wordmark in
white. Generate from Figma or designer art before submission. Placeholder
in `docs/store_assets/android/feature_graphic.png` is acceptable for
internal track but **must be replaced** before production submission.

---

## 6. App icon (both stores)

Source: `assets/icon/app_icon.png` (1024×1024, navy background, orange
fish). Per-platform sizes generated by `flutter_launcher_icons`. Replace
the placeholder with designer art before public submission — App Store
review rejects obvious placeholder icons.

---

## 7. Permission justifications

Both stores require an in-product reason for every runtime permission. The
strings below are the production answers for the App Store review notes
and the Play Console "Permission declarations" form. They match the
production `Info.plist` and `AndroidManifest.xml` strings verbatim — keep
all three in sync if any is edited.

| Permission | When prompted | Justification |
|---|---|---|
| Camera (iOS / Android) | First "Take photo" tap on the catch log screen | Used so anglers can capture a photo of every catch they log. |
| Photo library — read (iOS) / READ_MEDIA_IMAGES (Android) | First "Choose from library" tap | Used so anglers can attach catch photos from past trips, and pick an avatar during onboarding. |
| Photo library — add (iOS) | First "Save to camera roll" action on a catch | Used so users can save catch photos back to their library to keep them alongside their other memories. |
| Location — when in use (iOS / Android) | First catch save with auto-tag enabled | Used to tag a catch with where it was made. Users can hide the exact location from friends with the per-catch Secret Spot toggle, and Marine Protected Area pins never share precise coordinates regardless of the toggle. |
| Location — always (iOS) | **Not requested in v1.** | Listed in `Info.plist` only because `geolocator` declares both keys; we only ever call when-in-use. **Remove from `Info.plist` before App Store submission.** |
| Push notifications (iOS / POST_NOTIFICATIONS Android 13+) | After first catch save | Used to notify users of friend requests, tournament invites, tournament catch verifications, and feed highlights. Users can disable each category individually in Settings → Notifications. |

**Action item before submission:** delete the
`NSLocationAlwaysAndWhenInUseUsageDescription` key from
`ios/Runner/Info.plist`. v1 only needs when-in-use. Keeping the always-key
forces App Store review to ask why we need background location, which we
don't.

---

## 8. App Store privacy questionnaire

App Store Connect → App Privacy → Manage. Answers below match the v1
data model.

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| Email address | Yes | Yes | No | App functionality (Supabase auth identifier) |
| Name (display name + handle) | Yes | Yes | No | App functionality |
| User ID (Supabase auth UID) | Yes | Yes | No | App functionality |
| Photos | Yes | Yes | No | App functionality (catch photos, avatars) |
| Precise location | Yes | Yes | No | App functionality (catch location). **Only collected when the user logs a catch with auto-tag on.** |
| Coarse location | No | — | — | — |
| Diagnostics — crash data | No | — | — | (Add only if Crashlytics or Sentry is wired up before submission.) |
| Product interaction | No | — | — | (Add only if Mixpanel/Amplitude is wired up before submission.) |
| Device ID | No | — | — | — |
| Advertising data | No | — | — | — |
| Contacts | No | — | — | — |

**Privacy practices statement (App Privacy → Privacy Practices):**

> Fishing with Friends does not sell or share user data with third parties for advertising. Catch data — photos, species, length, weight, location, conditions — is visible only to friends the user has added on the platform. Location precision can be hidden per-catch with the Secret Spot toggle. We do not track users across other companies' apps or websites.

**Privacy policy URL:** `https://bunshin.io/fishing-with-friends/privacy`
**Support URL:** `https://bunshin.io/fishing-with-friends/support`
**Marketing URL (optional):** `https://bunshin.io/fishing-with-friends`

> *Action item:* publish the privacy policy + support pages on
> `bunshin.io` before submission. Apple rejects submissions whose
> privacy URL 404s or returns a placeholder.

---

## 9. Play Console Data safety form

Play Console → App content → Data safety. Mirrors the App Store table
above; the questions are different but the underlying answers are the same.

**Data collected:**
- Personal info: Email address, Name, User ID — for App functionality, linked to user, not used for tracking.
- Photos and videos: Photos — for App functionality, linked to user.
- Location: Approximate location (No), Precise location (Yes) — for App functionality, linked to user.

**Data shared with third parties:** None. (We use Supabase as our backend; that is data processing, not third-party sharing under Play's definition.)

**Security practices:**
- Data is encrypted in transit: **Yes** (HTTPS / TLS to Supabase).
- Data is encrypted at rest: **Yes** (Supabase Postgres + Storage default encryption).
- Users can request data deletion: **Yes** (in-app: Settings → Account → Delete account; or by emailing `support@bunshin.io`).
- Independent security review: **No** (declare only if commissioned before submission).

> *Action item:* wire the in-app account deletion route before
> submission. Play requires a working in-app deletion flow for any app
> that lets users sign in. If the route ships post-launch, declare email
> only and add the in-app route in v1.0.1.

---

## 10. Content rating

**App Store:** No objectionable content. Rates 4+.

**Play Console (IARC questionnaire):**
- Violence: None
- Sexuality: None
- Profanity: None
- Controlled substances: None
- Gambling: None
- User-generated content: **Yes** (catch photos, display names, tournament names — visible to friends only). Declare moderation: in-app block + report flow on profiles. Result: rated Everyone with UGC notice.

> *Action item:* confirm the report-user flow ships in v1. If it doesn't,
> declare UGC = No (since friends-only graphs aren't typically classified
> as UGC under Play's definition), but the safer route is to ship report
> + block.

---

## 11. What's new — release notes templates

App Store and Play accept the same copy. Keep under 4000 chars; the first
~170 are what most users see in the update card.

**v1.0.0 — initial launch:**

> Welcome to Fishing with Friends. Log a catch in 30 seconds, run live
> tournaments with your crew, and keep your spots private. Built for
> freshwater + saltwater anglers.

**v1.0.x — bugfix template:**

> Stability fixes and small polish across catch logging, tournaments,
> and the map. Thanks for the feedback — keep it coming at
> support@bunshin.io.

**v1.1.x — feature template:**

> New in this release: {{headline feature in one sentence}}. Plus the
> usual round of fixes and polish. Tap Settings → Send feedback if you
> hit anything weird.

---

## 12. Submission checklist

Before tapping "Submit for review" on either store:

**Both:**
- [ ] App icon replaces the placeholder navy/orange fish with designer art
- [ ] Privacy policy + support pages live at `https://bunshin.io/fishing-with-friends/{privacy,support}`
- [ ] In-app account deletion flow live (Play hard requirement)
- [ ] All five required screenshots captured and uploaded per device class
- [ ] At least one tournament + one trip seeded for the demo account passed to reviewers
- [ ] Crash-free signed build uploaded; tested on physical iOS + Android device
- [ ] Sign-in with Apple supported (iOS hard requirement when other social SSO is offered — currently only email/password, so deferred unless we add Google sign-in)

**App Store:**
- [ ] Removed `NSLocationAlwaysAndWhenInUseUsageDescription` from `Info.plist`
- [ ] App Privacy questionnaire matches §8 above
- [ ] Demo account credentials in App Review Information (`reviewer@bunshin.io` / one-time password)
- [ ] Review notes call out Secret Spot toggle behavior for the location reviewer (otherwise they may flag the precise-location request)
- [ ] Screenshots use real catch photos, not stock — App Store review reads screenshot copy

**Play Console:**
- [ ] Internal testing track rolled out + smoke-tested on a Pixel + a mid-tier Samsung
- [ ] Data safety form matches §9 above
- [ ] Target API level matches Play's current floor (check Play Console for the live floor at submission time — Google bumps it annually)
- [ ] Content rating questionnaire submitted (IARC turns it around in <24h)
- [ ] App signing by Google Play enabled
- [ ] Feature graphic uploaded (1024×500)

**Action items inherited from v1 plan (M7):**
- [ ] Designer app icon delivered and committed to `assets/icon/`
- [ ] Designer feature graphic delivered for Play Console

---

## 13. Reviewer demo account

Both stores ask for a demo account in their review notes. Provision
before submission:

- Email: `reviewer@bunshin.io`
- Password: rotated per submission, sent via App Review Information / Play Console review notes (never committed)
- Seed data: 8 catches across 2 species, 1 active trip, 1 closed tournament with 3 members + 4 entries, 2 friends with their own catches visible.
- Note for reviewer: "Open the Map tab to see Secret Spot suppression in action — one of the seeded catches has Secret Spot on, the others off."

Seed script TBD. Track as a separate post-launch task; manual seeding via
the dashboard is acceptable for the first submission.

---

## 14. Marketing pages — out of scope for this doc

Landing page copy, press kit, ASO experimentation, and paid acquisition
all live outside of this file. Add `docs/MARKETING.md` if those start to
need durable copy.
