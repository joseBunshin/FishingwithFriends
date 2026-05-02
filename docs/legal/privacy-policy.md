# Privacy Policy — Fishing with Friends

**Last updated:** 2 May 2026
**Effective:** 2 May 2026

Bunshin Studios LLC ("Bunshin Studios", "we", "us", "our") operates the **Fishing with Friends** mobile application (the "App"). This Privacy Policy explains what information we collect, why we collect it, how we use it, and the choices you have.

If you do not agree with this Policy, please do not use the App.

---

## 1. Who we are

| | |
|---|---|
| Controller | Bunshin Studios LLC |
| Contact | jose.diaz@bunshin.io |
| App | Fishing with Friends (iOS, Android) |
| Website | https://bunshin.io |

For privacy questions, requests, or complaints, email **jose.diaz@bunshin.io**.

---

## 2. Information we collect

We collect only what the App needs to work. We do **not** sell your data, run third-party advertising, or use third-party analytics SDKs that track you across other apps.

### 2.1 Information you provide

| Data | Why we collect it |
|---|---|
| Email address | Account sign-in, password reset, transactional email |
| Password (hashed) | Account authentication — stored only in hashed form by Supabase Auth, never visible to us |
| Display name, avatar photo | Identifying you to your friends inside the App |
| Catch logs (species, length, weight, notes, gear) | The core function of the App — your fishing log |
| Catch photos | Optional photos attached to your catches |
| Trip details (title, location, dates, members) | Group fishing trips you create or are invited to |
| Tournament details (name, rules, entries, chat) | Tournaments you create, join, or are invited to |
| Friend connections | Building your private friends graph |
| Reactions, comments, chat messages | In-feed interactions and tournament chat |

### 2.2 Information collected automatically

| Data | Why |
|---|---|
| GPS coordinates of a logged catch | Tagging the catch on the map (only when you log a catch — we do not track you in the background) |
| Approximate device location at login (from IP) | Standard auth security signal |
| Push notification token (FCM/APNs) | Sending you push notifications you've opted into |
| Device platform (iOS / Android) and app version | Diagnostic context for support and crash debugging |
| Crash and error reports | Diagnosing app stability problems |

### 2.3 Information we do **not** collect

- We do not access your contacts, calendar, microphone, or files outside what you explicitly attach.
- We do not run background location tracking. GPS is only read at the moment you log a catch.
- We do not include third-party advertising SDKs.
- We do not include third-party cross-app analytics SDKs (no Mixpanel, no Amplitude, no Segment).
- We do not sell or rent personal information to anyone, ever.

---

## 3. How we use your information

We use the information described above to:

- Operate the App's core features — accounts, catches, trips, tournaments, friends, feed.
- Enrich your catches with weather, water temperature, moon phase, tide, and similar conditions via the Open-Meteo public weather API (only the latitude/longitude of the catch is sent — never your identity).
- Send transactional emails (sign-up confirmation, password reset).
- Send push notifications you've enabled (catch reactions, friend requests, tournament updates).
- Diagnose crashes and improve stability.
- Detect and prevent abuse, fraud, and violations of our Terms of Service.
- Comply with applicable law.

We do **not** use your data to train machine learning models, profile you for advertising, or share it with data brokers.

---

## 4. Who sees your data inside the App

Fishing with Friends is a **friends-only** social app. Your catches, trips, comments, and reactions are visible **only to friends you've accepted** — not to the general public, and not to other Fishing with Friends users you haven't connected with.

The exceptions are:

- **Tournaments**: when you join a tournament, your entries and tournament-chat messages are visible to other tournament participants for the duration of the tournament, even if they are not your friends.
- **Display name and avatar**: visible to anyone who receives a friend request from you, an invite from you, or who is in a tournament with you.

You can leave a tournament or remove a friend at any time, which revokes their forward-looking access to your activity.

---

## 5. Service providers (sub-processors)

We rely on a small number of third-party providers to run the App. Each is contractually obligated to use your data only to provide their service to us.

| Provider | What they do | Where they store data | Privacy policy |
|---|---|---|---|
| Supabase, Inc. | Authentication, database (Postgres), file storage (catch photos, avatars), edge functions | AWS US East / EU (region depends on project) | https://supabase.com/privacy |
| Google Firebase (Cloud Messaging) | Delivering push notifications to your device | Google Cloud | https://firebase.google.com/support/privacy |
| Apple Push Notification service | Delivering iOS push notifications | Apple infrastructure | https://www.apple.com/legal/privacy/ |
| Open-Meteo | Weather, marine, and astronomy lookup (lat/lon only — no identity sent) | EU | https://open-meteo.com/en/terms |
| Apple App Store / Google Play | Distribution, in-app purchase processing (if applicable) | Apple / Google | https://www.apple.com/legal/privacy/ · https://policies.google.com/privacy |

We do not share your information with any party not listed above, except as required by law (see §10).

---

## 6. International transfers

Bunshin Studios is based in the United States. By using the App, you understand that your information may be processed in the United States and other countries where our service providers operate. Where required by law, we rely on appropriate transfer mechanisms (e.g. Standard Contractual Clauses).

---

## 7. Data retention

We keep your data while your account is active. When you delete your account:

- Your profile, catches, photos, trip memberships, friend edges, reactions, comments, and chat messages are deleted from our production database within **30 days**.
- Backups containing your data may persist for up to **90 days** after deletion before being rotated out.
- Anonymised, aggregated statistics (e.g. total catches logged per month) may be retained indefinitely.
- Some records may be retained longer where required by law (e.g. tax, fraud, legal hold).

You can delete your account from inside the App: **Me → Settings → Danger zone → Delete account**, or by emailing **jose.diaz@bunshin.io**.

---

## 8. Your rights

Depending on where you live, you have some or all of the following rights regarding your personal data:

- **Access** — request a copy of the data we hold about you.
- **Correction** — fix inaccurate data (most fields are user-editable in-app).
- **Deletion** — delete your account and associated data (see §7).
- **Portability** — request your data in a machine-readable format.
- **Restriction / objection** — limit how we process your data.
- **Withdraw consent** — for processing based on consent (e.g. push notifications — toggle off in Settings or device OS settings).
- **Lodge a complaint** with your local data-protection authority.

To exercise any of these rights, email **jose.diaz@bunshin.io**. We will respond within 30 days.

### California residents (CCPA/CPRA)

You have the right to know what categories of personal information we collect, the right to delete it, and the right not to be discriminated against for exercising your rights. We do **not** sell or share personal information for cross-context behavioural advertising.

### EU/EEA/UK residents (GDPR/UK GDPR)

Our legal bases for processing are:

- **Contract** — operating your account and the App's features.
- **Legitimate interest** — security, abuse prevention, app improvement.
- **Consent** — push notifications, optional photo uploads, optional GPS tagging.
- **Legal obligation** — where required by law.

---

## 9. Children's privacy

Fishing with Friends is rated **4+ on the App Store** and **Everyone on Google Play**. The App is **not directed at children under 13** (or the equivalent minimum age in your jurisdiction), and we do not knowingly collect personal information from children under 13.

If you are a parent or guardian and believe your child has provided us with personal information, contact **jose.diaz@bunshin.io** and we will delete it.

---

## 10. Security

We protect your data with industry-standard safeguards:

- All traffic between the App and our servers uses TLS (HTTPS).
- Passwords are stored hashed (bcrypt) by Supabase Auth — never in plaintext.
- Catch photos are stored in a private bucket, accessible only via short-lived signed URLs.
- Database row-level security policies enforce the friends-only model server-side, not just in the App.
- Push notification tokens are scoped per device and revoked when you sign out.

No system is perfectly secure. If we ever discover a breach affecting your data, we will notify you in accordance with applicable law.

---

## 11. Disclosure for legal reasons

We may disclose your information when we believe in good faith that disclosure is necessary to:

- Comply with a valid legal process (subpoena, court order, regulatory demand).
- Enforce our Terms of Service.
- Protect the safety, rights, or property of users, the public, or Bunshin Studios.
- Investigate fraud, abuse, or security incidents.

---

## 12. Changes to this Policy

We may update this Policy from time to time. When we do, we will:

- Update the "Last updated" date at the top.
- Post the new Policy at https://bunshin.io/privacy/fishing-with-friends.
- For material changes, notify you in-app or by email before the change takes effect.

Continued use of the App after a change means you accept the updated Policy.

---

## 13. Contact

Questions, requests, or complaints?

**Bunshin Studios LLC**
Email: **jose.diaz@bunshin.io**

---

*This document is the canonical privacy policy for Fishing with Friends. The version hosted at `https://bunshin.io/privacy/fishing-with-friends` is the version Apple and Google reviewers will reference; keep them in sync.*
