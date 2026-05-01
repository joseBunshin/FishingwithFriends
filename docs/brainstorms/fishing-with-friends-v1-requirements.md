# Fishing with Friends — v1 Requirements

**Date:** 2026-05-01
**Status:** Locked for planning
**Source brainstorm:** This file (initial product brainstorm; supersedes the spec PDF for v1 scope)
**Visual reference:** `Assests/` (Lovable prototype screenshots — palette, tabs, page shapes)
**Spec foundation:** PDF at `Fishing_With_Friends_Enterprise_Dev_Sheet.pdf` (Bunshin Studios v1.0)

---

## Context

Fishing with Friends is migrating from a Lovable web prototype to a production Flutter + Supabase mobile app. The Lovable prototype proved the basic shape (catch logging, friends, tournaments, map, stats), but feels like a logbook port. v1 needs to feel like a *product* — something a saltwater + freshwater angler is excited to use solo on Tuesday and during a tournament on Saturday.

The codebase already has: Flutter scaffold, Riverpod + go_router, Supabase auth + RLS-strict schema covering profiles / friendships / catches (with PostGIS) / tournaments / tournament_members / tournament_entries / notifications, private storage bucket policies, sign-in screen wired to Supabase, hero catch-log UI placeholder, bottom-nav shell with 4 tabs.

## Product thesis

A fishing app fails if it tries to be a logbook *and* a discovery network *and* an AI coach on Day 1. v1 wins by combining:

1. **A solo-valuable logbook** — useful even before a single friend joins (the install reason).
2. **Live, friends-only tournaments** — viral hook that makes inviting friends pay off immediately (the retention reason).

Everything else is deferred.

## Goals (v1)

1. An angler logs a beautiful catch in under 30 seconds, even on a moving boat with one wet hand.
2. A trip with friends produces a single shareable trip summary, not a wall of disconnected catches.
3. Two friends can run a Saturday tournament with a leaderboard that updates in real time as catches submit and get verified.
4. A user reaches the end of a season and is shown a Year-in-Review reel + share cards that pull them (and their friends) back in.
5. Friends-only by default — no public catch is exposed, no spot is leaked unless the user opts in.

## Non-goals (v1)

- Public profiles, public feed, public discovery.
- Photo-based species identification or any ML on catches.
- AI lure / depth / time-of-day suggestions.
- Apple Watch / Wear OS companion apps.
- Tournament brackets or divisions (single leaderboard only).
- Community-submitted water reports / hatch reports.
- In-app payments, prizes, or marketplace.
- Web app (mobile only — iOS + Android).

## Personas

- **Recreational angler (primary)** — fishes 10–40 days/year, freshwater or saltwater, wants a beautiful logbook + flex with close friends. Will install for the logbook.
- **Tournament participant (primary)** — joins club / friend tournaments a few times a year, wants live scoring and verified entries. Will install because a friend invites them to a tournament.
- **Tournament creator (secondary)** — runs Saturday club events, needs to invite, approve members, verify catches, close out. Power user.
- **Admin (operational)** — manages the global species table and platform integrity.

## Key decisions

- **Wedge:** Storytelling-first logbook + live tournaments shipped together.
- **Water type:** Freshwater + saltwater. Species table includes inland (bass/trout/walleye/pike/panfish) and coastal (snook/redfish/striper/tarpon/sea trout/etc.). Tide is a first-class condition for saltwater catches.
- **Social model:** Friends-only by default; per-catch privacy is *not* a v1 toggle (keeps the model simple). All visibility runs through the friendship graph + RLS.
- **Identity:** Generated handles like `@silentfisher409` (Lovable convention). Display name + avatar are user-editable. No real-name requirement.
- **Privacy:** Per-catch **Secret Spot** toggle hides exact GPS from friends. Independent **Catch & Release** toggle for ethics/reporting. Marine Protected Area pins never share exact coordinates regardless of toggle.
- **Units:** Per-input toggle for lbs/kg and in/cm (Lovable pattern). Stored in canonical metric in DB; display follows user preference.
- **Tournament shape:** Invite-only (creator-approves members) or join-by-code. No public tournaments in v1. Single leaderboard per tournament; multiple side-pots (e.g., "biggest fish") allowed.

## Feature scope (v1)

### A. Catch logging — the hero flow

- **Photo-first hero** with multi-photo carousel (camera + library, ≤5 photos per catch).
- **Smart auto-fill:** GPS, date, time on open. User can override.
- **Species selector** backed by global `species` table (freshwater + saltwater). Search + recent.
- **Numeric pads** for length (in/cm) and weight (lbs/kg) with per-field unit toggle.
- **Conditions block (optional, auto-fill):** weather (temp, wind, sky), water temp, **tide (saltwater only)**, moon phase. Pulled from a weather/tide API via a Supabase edge function on submit; user can edit.
- **Rig / bait / lure** — chip selector with freeform fallback.
- **Notes** — text + **voice notes** (long-press mic, stored as audio file in private bucket, transcribed best-effort).
- **Toggles:** Secret Spot, Catch & Release.
- **Quick-log mode:** photo + species → save. Defer everything else; user can fill in later.
- Save triggers haptic feedback and routes to the catch detail screen with hero image transition.

### B. Trips — multi-catch sessions

- **A Trip is the parent of N catches.** Has a cover photo (auto = best of trip), title, body of water, start/end timestamp, optional companions (`@mentions` of friends).
- **Start a trip** from the Log tab → all catches that day default into the active trip.
- **Trip summary card** at end: total catches, total weight, top species, biggest catch hero, map of pins, companions tagged.
- **Co-angled trips:** companions you tagged see the trip on their feed and can opt in as participants (their own catches stay theirs, but the trip is shared).

### C. Storytelling layer

- **Personal Records (PRs):** auto-detected per species (biggest weight, longest length). New PR triggers a full-screen celebration + shareable card.
- **Badges & milestones:** seeded set including First Catch, First Species, 100 Catches, Sunrise Warrior (5 catches before 7am), Slam (3+ species same day), saltwater-specific (First Inshore Slam, etc.).
- **Streaks:** count of consecutive fishing days/weeks; soft (resets gracefully).
- **Year-in-Review:** annual animated reel — top catches, biggest, most caught species, days fished, biggest trip, friend leaderboard. Generated client-side from Supabase data, exportable as a video / share card.
- **Catch comparison:** every saved catch shows context like "3rd biggest largemouth this year" / "biggest catch on this lake."
- **Branded share cards:** one-tap share to iMessage / Instagram / X / etc. with a beautifully composed card (photo + species + weight + length + location text). The only growth surface in a friends-only app — needs to be gorgeous.
- **Catch journal:** optional long-form notes per catch.

### D. Live tournaments

- **Create a tournament:** name, description, start/end (timezone-aware), location/body of water, scoring metric (Total Weight | Biggest Fish | Most Catches | Longest Catch), species filter (multi-select), invite friends or generate join code.
- **Membership flow:** request → creator approves (Pending → Accepted). RLS prevents self-approval (already in schema).
- **Catch entry flow:** member submits an existing catch → "Pending" → creator approves with one tap → "Counted." RLS prevents self-approval.
- **Live leaderboard:** Supabase Realtime stream; reorders as entries are approved. "🟢 fishing now" indicator next to anglers active in the last 30 min.
- **Side pots:** creator can add 0–N side pots (e.g., "Biggest single fish", "Biggest of species X"). Each side pot has its own scoring + winner.
- **Tournament chat:** single-thread per tournament, members only. Photos + text; reactions reuse the global feed reaction set.
- **Phases:** Registration → Live → Closed. Banner state on the tournament card; auto-transitions based on dates.
- **Recurring tournaments:** "every Saturday on Lake Michigan" auto-creates the next instance when the previous closes.
- **Final results screen:** podium animation, badges minted to winners.

### E. Social — friends-only

- **Friend search** by username; add by handle or by tapping in a feed.
- **Friend requests:** pending → accepted (already in schema).
- **Activity feed (Home tab):** friends' catches and trips, chronological, with hero image and caption. **Reactions** (small fishing-themed set: 🎣 🔥 👊 🤯 🤝). **Comments** with `@mentions`.
- **Fishing clubs:** named groups (e.g., "Tuesday Bass League"). Sub-feed scoped to club, internal tournaments, internal leaderboard. A club is essentially a friends-of-friends abstraction with its own permission scope.

### F. Catch Map

- **Pin colors:** own = navy, friends = green (matches Lovable).
- **Show / hide friends toggle** (Lovable).
- **Heatmap toggle:** dense fuzzy density rather than exact pins. Default-on for friends' catches; you always see your own as exact pins.
- **Secret Spot rule:** never expose exact GPS to friends; the catch shows in heatmap as a generic regional cluster only.
- **Conditions overlay:** current wind / temperature / tide on the map.
- **My Waters:** favorite a body of water; quick-log uses it as default location.
- **MPA awareness:** if a catch's GPS falls inside a marine protected area, the location resolves to the nearest non-MPA water feature for display; raw coordinates are still stored privately.

### G. Stats

- Species breakdown (Lovable).
- Catches over time (Lovable).
- **Time-of-day heatmap** of own catches.
- **Conditions correlation** ("your top catches: falling tide + 65–72°F water").
- **Personal map heatmap** of own catches.
- **vs Friends comparison:** "you out-fished 60% of friends this month." Friendly framing, no toxic ranking by default.

### H. Cross-cutting

- **Offline mode:** catches log to local store with no signal; sync on reconnect. Photos queue for upload. **Non-negotiable** — boats and remote rivers don't have LTE.
- **Onboarding:** pick avatar, set display name, pick home water, optional "find friends" by username or contacts.
- **Push + in-app notifications:** friend requests, tournament invites, tournament catch verified, "your buddy crushed it" feed highlights.
- **Visual system:** navy + orange palette, off-white background, soft cards, rounded corners (matches Lovable). Replace the current blue-gradient theme.
- **Bottom-nav (8 tabs to match Lovable):** Home / Catches / Log (FAB) / Stats / Tourneys / Map / Friends / Me. *Open question: 8 tabs is a lot — see Open Questions.*

## Deferred — explicitly not v1

- **v1.5:** photo species ID via on-device or hosted ML; voice-note transcription; tournament brackets / divisions.
- **v2:** community water / hatch reports; public spots; web app; admin dashboard for species curation.
- **v3:** AI lure / depth / time suggestions from your data + weather; coach mode; Apple Watch / Wear OS quick-log; Instagram Reels–style feed.

## Outside this product's identity

- **No public network.** We are not Fishbrain. Spot privacy is core to the product.
- **No marketplace / no in-app purchases of gear.**
- **No fishing license tracking / regulation enforcement** (legal liability surface).
- **No prize disbursement / payments in tournaments** (regulated, defer indefinitely or partner).

## Success criteria (v1 launch bar)

- A new user can sign up, complete onboarding, and log their first catch in under 90 seconds.
- A trip can be started, 5+ catches logged across the day, and a trip summary shared in under 5 taps.
- A 3-person tournament can be created, joined, and run end-to-end with a leaderboard updating live within 5 seconds of approval.
- The app loads and logs a catch fully offline; queue drains to Supabase on reconnect.
- Every screen renders cleanly in dark mode and at the system's largest dynamic-type setting.
- App passes App Store + Play Store review on first submission (privacy strings, location justifications, photo permissions).

## Visual direction

- **Palette:** deep navy primary (`~#102B47`), warm orange accent (`~#F08948`), off-white surface (`~#F5F7FA`), white cards.
- **Type:** clean, bold sans-serif; generous heading weights.
- **Cards:** rounded (`radiusLg`–`radiusXl`), soft single-shadow, no gradient fills.
- **Photo treatment:** photos are the hero — full-bleed within rounded cards, species label as a navy pill on top-left, metadata in a flat row below.
- **Bottom nav:** 8 tabs with center-FAB for Log (matches Lovable).
- **No background photography or hero gradients on chrome.** Replaces my current blue-gradient sign-in.

Concrete reference screenshots in `Assests/`:
- `Main Photo 1.jpg` — Home (stat tiles + recent catches).
- `Screenshot 2026-05-01 134101.jpg` — My Catches list.
- `Screenshot 2026-05-01 134126.jpg` — Log a Catch form.
- `Screenshot 2026-05-01 134148.jpg` — Stats (species + over time).
- `Screenshot 2026-05-01 134202.jpg` — Create Tournament.
- `Screenshot 2026-05-01 134224.jpg` — Catch Map.
- `Screenshot 2026-05-01 134240.jpg` — Friends.

## Dependencies / assumptions

- **Weather + tide API:** an external provider (e.g., OpenWeather, NOAA tides, StormGlass) is reachable from a Supabase edge function. *Assumption — vendor selection deferred to planning.*
- **Map tiles:** Lovable used Leaflet + OpenStreetMap. We'll use a Flutter-native map (Mapbox or Apple/Google maps). *Assumption — vendor selection deferred to planning.*
- **MPA dataset:** publicly available (NOAA / IUCN). *Assumption — confirm licensing in planning.*
- **Year-in-Review video export:** Flutter packages exist for video composition; performance on low-end Android is the risk.
- **Push notifications:** APNs (iOS) and FCM (Android) configured; Supabase has a notification trigger.
- **Voice-note transcription:** v1 stores audio only; transcription is v1.5.

## Open questions

1. **8 tabs is a lot for a phone bottom-nav.** Do we keep all 8 (Lovable parity) or collapse Stats + Map + Friends into a "More" overflow? *Recommend: keep all 8 with an icon-only compact bottom nav at small breakpoints. Validate in design pass.*
2. **Trip mode default:** when a user opens the Log button, do we offer "log a catch" vs "start a trip" or auto-detect (multiple catches close in time = a trip)? *Recommend: explicit Trip vs Catch in v1, auto-detect in v1.5.*
3. **Saltwater MPA dataset:** lock in a licensing-clean source before we ship, or plan a v1.1 follow-up?
4. **Year-in-Review timing:** strict end-of-calendar-year, or rolling "last 365 days" available any time?

## Risks

- **Offline-first changes everything.** Local store + sync queue is non-trivial; this risk is the highest in v1.
- **Realtime leaderboard at scale.** Supabase Realtime is fine for friends-only tournaments (≤100 members) but verify before promising.
- **Saltwater species table is a long tail** with regional variation — needs an admin curation tool earlier than spec implies.
- **Friends-only growth ceiling.** No discovery flywheel means user acquisition relies on share cards + tournament invites. Make those *gorgeous*.

## Schema delta vs current migrations

Already in `supabase/migrations/0001_init.sql`:
- profiles, friendships, species, catches (with `secret_spot`, geog point, photo_paths array), tournaments, tournament_members, tournament_entries, notifications, RLS, friend visibility view.

New tables / columns this brief introduces (planning will detail):
- `trips` (parent of catches), `trip_participants`, `trip_id` FK on catches.
- `clubs`, `club_members`, optional `club_id` on tournaments.
- `tournament_side_pots`, `tournament_chat_messages`.
- `catch_conditions` (denormalized read-side cache of weather/tide/moon).
- `catch_audio_notes` (path + duration + transcript).
- `badges`, `user_badges`, `personal_records`.
- `feed_reactions`, `comments`.
- `user_waters` (favorited bodies of water).
- `species` table needs `water_type` (freshwater / saltwater / both), `regions` (text array), `is_protected` flag.

## Handoff

Recommended next step: `/ce-plan` to break v1 into a sequenced milestone plan (visual system → catch flow → trips → tournaments → social → map/stats → cross-cutting), each milestone scoped to a 1–2 week increment.
