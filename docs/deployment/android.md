# Android — Google Play deployment

End-to-end steps to ship Fishing with Friends to Google Play internal testing, then production. Assumes the [`README.md`](./README.md) checklist is complete (Play Console account, signing keystore, privacy policy URL).

Unlike iOS, Android builds work on any platform with Flutter installed (Windows, macOS, Linux).

---

## 1. One-time signing keystore

Run **once**, ever, for Bunshin Development Studios. The resulting `.jks` is the irreplaceable identity for the app — losing it means you lose the ability to push updates and have to publish under a new package name.

```bash
keytool -genkey -v \
  -keystore ~/bunshin-fwf-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Prompts for:
- Keystore password (use a password manager — back this up)
- Key password (same is fine)
- Distinguished name fields (CN=Jose Diaz, OU=Bunshin Development Studios, O=Bunshin Development Studios, L=Charlotte, ST=NC, C=US — adjust to taste)

Copy the resulting file to a secure location AND drop a working copy at `android/app/upload-keystore.jks` (gitignored).

Create `android/key.properties` (also gitignored):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

`android/app/build.gradle.kts` already references this file (per the M7 build setup).

## 2. Bump the version

`pubspec.yaml`:

```yaml
version: 1.0.0+1
```

- Left of `+`: marketing version name (`1.0.0`) — visible in Play Store.
- Right of `+`: version code (`1`) — integer, must increment for every Play upload. Play Console rejects duplicates.

For first internal-track upload keep `1.0.0+1`. For iterations bump build number.

## 3. Build the AAB (Android App Bundle)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

**Why AAB and not APK:** Play Console requires `.aab` for new apps since Aug 2021. AAB lets Google Play generate per-device APKs, smaller download for users.

**Common build failures:**
- *Missing key.properties* — confirm step 1 keystore + properties file are in place.
- *Outdated Gradle plugin* — `cd android && ./gradlew --stop && ./gradlew clean`. Upgrade `gradle-wrapper.properties` if needed (currently 8.11.1).
- *Java version mismatch* — Flutter wants JDK 17. `java -version` should report 17.x.

## 4. Upload to Play Console

1. Play Console → your app → **Release → Testing → Internal testing**.
2. **Create new release**.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. **Release notes** — copy from `docs/STORE_LISTINGS.md` "What's new" section, or write a single sentence.
5. **Save** → **Review release** → **Start rollout to Internal testing**.

Internal testing rolls out to your test list immediately (no review). Up to 100 testers, identified by Google account email.

## 5. Test on real device

Add your test users to Play Console → **Testers** with their Google account emails. They get an opt-in link by email. After accepting, they install the app from Play Store as normal — the internal track build replaces production for them.

Test on a real Android device:

- Sign up + email confirmation
- Log a catch with camera + GPS
- Verify photo loads from Supabase
- Push notification arrives (foreground + background)
- Tournament create / invite / leaderboard
- Friends-only RLS — log in as a non-friend, confirm no catches visible
- Network: kill connection, log a catch, restore connection, verify offline queue syncs

Iterate on bugs. Each fix → bump version code → re-upload to Internal testing.

## 6. Open / Closed testing (optional)

When stable, promote to:

- **Closed testing** — up to 5,000 testers, opt-in via email. Slower review (~24h).
- **Open testing** — anyone with the opt-in link can install. Public beta surface.

Or skip straight to production if you're confident.

## 7. Production release

1. Play Console → **Release → Production**.
2. **Create new release**.
3. Either upload a fresh AAB or **Promote** the build from Internal/Closed testing.
4. Fill **Store listing** if not already done (pulls from `docs/STORE_LISTINGS.md`):
   - **App name**: Fishing with Friends
   - **Short description** (80 chars), **Full description** (4000 chars), **Screenshots**, **Feature graphic** (1024×500), **App icon**.
   - **Categorization**: Sports → Sports
   - **Content rating**: complete the questionnaire — should land at "Everyone".
   - **Privacy policy URL**.
   - **Data safety** — declare data collected: Account info (email), Photos, Location (precise), Device IDs.
5. **Pricing & distribution** — Free, list of countries.
6. Submit for review.

Google Play review typically takes <24h for v1. Subsequent updates are often instant.

## 8. After publish

- App live based on rollout setting (typically 100% or staged 10% / 50% / 100%).
- Monitor Crashlytics + Play Console → **Quality → Android vitals** for ANRs/crashes.
- Watch first-day install funnel — Play Console → **Statistics**.
- Increment version code for hotfixes; same submission flow.

---

## Push notification verification

Same as iOS, but Android uses FCM directly (no APNs intermediary). After install:

```sql
select user_id, platform, last_seen_at
from public.device_tokens
where user_id = (select id from auth.users where email = 'YOUR_TEST_EMAIL');
```

Then trigger:

```sql
insert into public.notifications (recipient_id, kind, payload)
values (
  (select id from auth.users where email = 'YOUR_TEST_EMAIL'),
  'system',
  '{"title": "Test", "body": "Push pipeline check"}'
);
```

If nothing arrives, check:
- `android/app/google-services.json` matches the production Firebase project.
- FCM service account JSON in `fwf_app_settings`.
- Supabase logs for the `push-dispatch` edge function.

---

## Versioning convention

| Marketing version | Version code | Notes |
|---|---|---|
| `1.0.0` | `1` | First Play upload |
| `1.0.0` | `2` | Bug fix during Internal testing |
| `1.0.0` | `3+` | Iterations |
| `1.0.1` | `4` | Public bug-fix release — version code keeps incrementing |
| `1.1.0` | `5` | Public minor feature release |
| `2.0.0` | `6` | Major version |

Unlike iOS, Android version codes are global integers — they only ever increment, regardless of marketing version. Don't reset.

---

## Backing up the keystore

The single biggest deployment-side risk is losing `bunshin-fwf-upload.jks`. If it's lost:
- You can't sign updates → existing users are stranded on the last published version.
- You'd have to publish under a new package name, losing all installs and reviews.

Mitigations:
- Store the `.jks` + passwords in 1Password / Bitwarden / a secure team vault.
- Replicate to a second physical drive.
- Don't commit it (already gitignored).
- Consider Play App Signing (Google holds the upload key for you, optional but recommended).
