---
title: "fix: TestFlight bug batch — handle, nav clearance, catch log back, photo fit, share card"
type: fix
status: active
date: 2026-05-03
---

# fix: TestFlight bug batch — handle, nav clearance, catch log back, photo fit, share card

## Summary

Five user-reported bugs from the first TestFlight install, batched into one branch and shipped as `1.0.0+5`. Surgical fixes only — no redesigns of the screens these touch. The bottom-nav coverage bug and the "Tourneys" label wrap share the same root file (`app_shell.dart`) and ship in one unit.

---

## Problem Frame

The first real-device install of FWF v1.0.0+4 surfaced five UX bugs that aren't App-Store-blockers but make the app feel half-finished. All are bounded, well-isolated, and shippable in a same-day TestFlight build. Holding submission on these is the right call — App Reviewers will see them too on a fresh install, and a couple (the bottom-nav covering Sign Out, the share-card photo missing) make the first 30 seconds of the app feel buggy.

---

## Requirements

- R1. The Friends → "Your Handle" card displays the user's actual `profiles.username` value, not a derivation from email.
- R2. The bottom navigation bar must not visually obscure interactive elements at the bottom of any shell-route screen (Home, Catches, Tourneys, Map, Friends, Me).
- R3. The "Tourneys" label in the bottom nav must render on a single line on every supported iPhone width (375pt and up).
- R4. The catch log screen's leading toolbar button must reliably dismiss the screen and return the user to wherever they came from.
- R5. The catch detail screen's hero photo must fill the full width and height of the SliverAppBar's expanded area (no navy gutters around the photo).
- R6. The share-card export must include the catch's actual photo, not the navy fallback panel, when the catch has a photo.
- R7. The fixes ship as `1.0.0+5` to TestFlight, installable on the same Bunshin internal-testing group as `+4`.

---

## Scope Boundaries

- No redesign of any of the touched screens — surgical fixes only.
- No changes to the bottom nav's visual identity (raised log button, tab count, navy/orange palette).
- No changes to Supabase schema, RLS, or edge functions.
- No new test infrastructure — reuse the existing `flutter_test` setup.

### Deferred to Follow-Up Work

- A global `ShellAwarePadding` helper or `Scaffold` extension that automatically computes nav-bar clearance — for v1, the fix is per-screen padding (4-5 screens) and the helper can come later if more shell-route screens get added.
- Replacing the share-card's offscreen `RenderRepaintBoundary` capture with a server-side render pipeline — the fragility of pre-warming the image cache is a known smell, but a proper fix is a v1.1+ refactor.
- iOS deep-link handling for password-reset emails (separate plan; see `docs/EMAIL_TEMPLATES.md` "Mobile deep linking (post-launch)").
- Universal Links / Associated Domains (separate plan).

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/friends/presentation/friends_screen.dart` — the offending `_UsernameCard` reads `user.email.split('@').first` instead of `myProfileProvider.username`.
- `lib/features/profile/data/my_profile_repository_provider.dart` — `myProfileProvider` is the canonical source for the signed-in user's profile; `me_screen.dart` already uses it correctly.
- `lib/core/router/app_shell.dart` — `extendBody: true` on Scaffold (line 66) lets content scroll behind the 72pt bottom nav. The `_NavItem` widget's Text has no `maxLines`/`overflow` constraints.
- `lib/features/me/presentation/me_screen.dart:225` — trailing `SizedBox(height: AppSpacing.xxl)` (32pt) is not enough to clear the 72pt nav + safe-area inset.
- `lib/features/catches/presentation/catch_log_screen.dart:222` — leading `IconButton` uses `context.pop` as a tear-off (extension-method tear-off may not satisfy `VoidCallback` reliably).
- `lib/features/catches/presentation/catch_detail_screen.dart:99-104` — `SliverAppBar(expandedHeight: 320)` with `FlexibleSpaceBar.background = CatchPhotoCarousel`. Carousel wraps in `AspectRatio(4/3)` which under-fills 320pt at typical iPhone widths and exposes the navy `backgroundColor`.
- `lib/features/catches/presentation/widgets/catch_photo_carousel.dart:56-57` — the `AspectRatio(4/3)` wrap is what causes the navy gutter.
- `lib/features/storytelling/application/share_card_export.dart:78-89` — `_prefetch` uses `NetworkAssetBundle.load('')` to fetch signed-URL bytes. Returns `null` on any exception, silently. When `null`, the share card falls through to an async `CachedNetworkImage` that the offscreen `toImage()` capture doesn't wait for.
- `lib/features/storytelling/presentation/widgets/share_card.dart:60-84` — `_Photo` correctly uses `Image.memory(photoBytes, fit: BoxFit.cover)` when bytes are pre-warmed; the bug is purely on the prefetch side.

### Institutional Learnings

- `docs/solutions/2026-05-01-storytelling-server-detection.md` — server-side trigger for PRs/badges; not directly relevant but confirms storytelling is decoupled from share-card rendering.
- No prior solutions doc exists for the share-card photo race or bottom-nav clearance; both are new findings worth documenting in `docs/solutions/` after the fix lands.

### External References

- Skipped — local patterns are sufficient. All five bugs are well-understood Flutter idioms (provider wiring, Scaffold padding, `context.pop` tear-off, BoxFit, image prefetch).

---

## Key Technical Decisions

- **Decision:** Add bottom padding per-screen rather than a global `ShellAware` widget. **Rationale:** 4-5 shell-route screens to update vs. 1 new abstraction; an abstraction is the right call once we add more screens. YAGNI for v1.
- **Decision:** Drop `AspectRatio(4/3)` from `CatchPhotoCarousel` rather than recompute `expandedHeight` to match. **Rationale:** Letting the photo fill whatever space the SliverAppBar gives it adapts to future hero-strip designs without re-tuning numbers; `BoxFit.cover` already handles wide vs. tall photos correctly.
- **Decision:** Replace `NetworkAssetBundle` in the share-card prefetch with `package:http` `get` (with explicit `Duration` timeout). **Rationale:** `NetworkAssetBundle` swallows errors silently and is intended for asset bundles, not arbitrary URLs. Using `http.get` makes failure modes explicit (status code, timeout) and lets us log + retry.
- **Decision:** Wrap `context.pop` in an explicit lambda + `canPop` check + fallback to `context.go(AppRoutes.home)`. **Rationale:** Eliminates extension-method-tear-off ambiguity AND handles the cold-launch edge case where the stack is empty.
- **Decision:** Keep the X icon on Catch Log (not change to a back arrow). **Rationale:** X = "discard, don't save" is the right semantic for a creation form; back arrow implies pushing further into a flow. The bug is that X doesn't work, not that it's the wrong icon.

---

## Open Questions

### Resolved During Planning

- **Should bug 2's nav-clearance fix be global or per-screen?** Per-screen for v1 (4-5 files); abstract once the count grows.
- **Should the share-card use a different rendering strategy?** No — keep the offscreen `RenderRepaintBoundary` approach; just fix the prefetch.

### Deferred to Implementation

- The exact bottom padding value depends on `MediaQuery.viewPaddingOf(context).bottom + 72`. Implementer can either inline this or extract a named constant (`kBottomNavClearance`). Either is fine.
- Whether `package:http` is already in the dependency tree (transitively via Supabase) or needs an explicit `pubspec.yaml` entry. Implementer to verify with `flutter pub deps | grep http`.

---

## Implementation Units

- U1. **Wire Friends "Your Handle" card to myProfileProvider**

**Goal:** The "Your Handle" card on the Friends page reflects the user's actual `profiles.username`, including after the user changes it via Edit Profile.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Modify: `lib/features/friends/presentation/friends_screen.dart`
- Test: `test/features/friends/friends_screen_test.dart` (create if missing)

**Approach:**
- Replace the email-derivation in `_Body.build` (lines 55-56) with a watch on `myProfileProvider`.
- Display order of preference: `profile.handle` (canonical), `'@${profile.username}'` (fallback if `handle` getter doesn't exist), `'@${user.email.split('@').first}'` (emergency fallback only when profile hasn't loaded yet).
- Inspect `Profile.handle` getter in `lib/features/friends/domain/profile.dart` — it likely already returns `'@$username'`. Use it directly.

**Patterns to follow:**
- `lib/features/me/presentation/me_screen.dart:24-32` — `MeScreen` already uses `myProfileProvider` to display the handle. Mirror that wiring exactly.

**Test scenarios:**
- Happy path: `myProfileProvider` returns a profile with `username='joe'` → "Your Handle" card displays `@joe`.
- Edge case: `myProfileProvider` is loading (AsyncValue.loading) → card shows skeleton or email-derived fallback, doesn't crash.
- Edge case: `myProfileProvider` returns `null` (not yet onboarded) → card shows email-derived fallback.
- Integration: After Edit Profile changes the username from `joe123` to `bigfishjoe`, navigating to Friends shows `@bigfishjoe` (use `ProviderContainer` override to simulate the update).

**Verification:**
- On a TestFlight build, sign up → change handle in Edit Profile → tap Friends tab → "Your Handle" card shows the new handle, not the email-derived one.

---

- U2. **Fix bottom nav clearance + Tourneys label wrap**

**Goal:** No bottom-nav-shell screen has interactive content obscured by the nav bar; the "Tourneys" label fits on one line on the smallest supported iPhone (375pt width).

**Requirements:** R2, R3

**Dependencies:** None

**Files:**
- Modify: `lib/core/router/app_shell.dart` (label wrap fix)
- Modify: `lib/features/me/presentation/me_screen.dart` (Sign Out clearance)
- Modify: `lib/features/home/presentation/home_screen.dart` (verify clearance)
- Modify: `lib/features/catches/presentation/catches_screen.dart` (verify clearance — `SliverPadding` `AppSpacing.xxxl` may already be enough)
- Modify: `lib/features/tournaments/presentation/tournaments_screen.dart` (verify clearance)
- Modify: `lib/features/friends/presentation/friends_screen.dart` (verify clearance — already has `SizedBox(height: AppSpacing.xxl)` trailing)
- Modify: `lib/features/map/presentation/map_screen.dart` (verify FAB / map controls aren't blocked)
- Test: `test/router/app_shell_test.dart` (extend the existing test for the label-wrap regression)

**Approach:**
- **Label wrap fix (`app_shell.dart`, `_NavItem`):** Add `maxLines: 1`, `overflow: TextOverflow.fade`, `softWrap: false` to the Text widget. Drop `fontSize` from 11 to 10 if "Tourneys" still wraps at 375pt. Test on the iPhone SE (375pt) viewport in widget tests.
- **Clearance fix (per shell-route screen):** For each screen with scrollable content, add a trailing `SizedBox(height: kBottomNavClearance)` where `kBottomNavClearance = MediaQuery.viewPaddingOf(context).bottom + 80` (72pt nav + ~8pt breathing room). Inline the calculation rather than introducing a global constant for this batch.
- For `Map` screen: if it has overlay controls (recenter button, layer toggle), shift them up by the same value via `Positioned(bottom: kBottomNavClearance + spacing)`.

**Patterns to follow:**
- `me_screen.dart:225` — already adds trailing `SizedBox`; just bump it from `AppSpacing.xxl` to the proper clearance.
- `catches_screen.dart:93-95` — already uses `AppSpacing.xxxl` (48pt) which is borderline; bump it up.

**Test scenarios:**
- Happy path: At iPhone 15 Pro width (393pt), every nav label renders on a single line.
- Edge case (375pt — iPhone SE): "Tourneys" label fits on a single line (this is the regression test).
- Edge case (430pt — iPhone 15 Pro Max): nothing changes.
- Integration: At iPhone SE viewport, a widget test that scrolls Me screen to bottom asserts the "Sign out" `ListTile` is fully visible (its bottom edge ≤ the nav bar's top edge).

**Verification:**
- TestFlight on iPhone: tap Me → scroll to bottom → "Sign out" tile fully visible above nav bar.
- TestFlight: confirm "Tourneys" label is single-line on the bottom nav.

---

- U3. **Fix catch log close button + add stack-empty fallback**

**Goal:** Tapping the close (X) button on the Catch Log screen always returns the user to the previous screen — or to Home if the stack is empty (cold-launch edge case).

**Requirements:** R4

**Dependencies:** None

**Files:**
- Modify: `lib/features/catches/presentation/catch_log_screen.dart`
- Test: `test/features/catches/catch_log_screen_test.dart` (create or extend)

**Approach:**
- Replace `onPressed: saving ? null : context.pop` (tear-off) with an explicit lambda:
  ```
  onPressed: saving ? null : () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
  ```
- This eliminates the extension-method-tear-off ambiguity and handles the case where the user reached `/log` via a deep link or fresh launch with no route to pop back to.

**Patterns to follow:**
- `catch_detail_screen.dart:60-63` — uses `() => context.pop()` (lambda) for its leading IconButton. Mirror that pattern.

**Test scenarios:**
- Happy path: User on Home → taps FAB → Log Catch screen → taps X → returns to Home.
- Edge case (cold-launch / empty stack): Mount Log Catch as the only route → tap X → navigates to Home (verify via `routeInformationProvider` change).
- Edge case (saving): While `saveCatchControllerProvider.isLoading` is true, the X button is disabled. Tapping does nothing.
- Integration: Save in progress → user taps X → no pop happens.

**Verification:**
- TestFlight: From any tab, tap the center Log FAB → Log Catch screen opens → tap X → returns to the originating tab.

---

- U4. **Make catch detail hero photo fill the SliverAppBar (no navy gutters)**

**Goal:** On the Catch Detail screen, the hero photo at the top fills the full SliverAppBar expanded area without a navy strip showing above or below the image.

**Requirements:** R5

**Dependencies:** None

**Files:**
- Modify: `lib/features/catches/presentation/widgets/catch_photo_carousel.dart`
- Test: `test/features/catches/catch_photo_carousel_test.dart` (create if missing)

**Approach:**
- Drop the `AspectRatio(aspectRatio: 4/3)` wrap around `PageView.builder` (line 56-57). Let the PageView fill whatever space its parent (the FlexibleSpaceBar background) gives it.
- The image children already use `BoxFit.cover` which correctly crops to fill any aspect ratio.
- Remove the `AspectRatio(aspectRatio: 4/3)` wrap on the no-photos placeholder (line 39-41) too, OR keep it but wrap in `Positioned.fill`. Pick whichever keeps the placeholder visually centered.
- Verify the hero transition still works — the `Hero(tag: 'catch-photo-<id>')` wrap is at the per-page level, not the AspectRatio level, so it's unaffected.

**Patterns to follow:**
- `catch_card.dart:40-49` — already uses `AspectRatio(aspectRatio: 1)` correctly because the grid cell has known dimensions. The detail-screen carousel is different — the SliverAppBar provides the dimensions.

**Test scenarios:**
- Happy path: Landscape catch photo → renders with no navy gutters in SliverAppBar.
- Happy path: Portrait catch photo → renders with no navy gutters (cropped sides via BoxFit.cover).
- Edge case: Catch with no photo → placeholder fills the SliverAppBar without navy gutters.
- Edge case: Catch with multiple photos → page dots remain visible at bottom; swipe between photos works.
- Integration: Hero transition from Catches grid to Catch Detail still animates smoothly (manual visual check; no widget test).

**Verification:**
- TestFlight: Open any catch from the Catches grid → detail screen → photo fills full top area → no navy strip visible.

---

- U5. **Fix share-card photo prefetch (replace NetworkAssetBundle with http.get)**

**Goal:** Sharing a catch produces a card with the catch's actual photo, not the navy fallback panel.

**Requirements:** R6

**Dependencies:** None

**Files:**
- Modify: `lib/features/storytelling/application/share_card_export.dart`
- Modify: `pubspec.yaml` (add `http: ^1.2.0` if not already transitively present)
- Test: `test/features/storytelling/share_card_export_test.dart` (create if missing) — exercise the prefetch with a mocked HTTP response.

**Approach:**
- Replace the `NetworkAssetBundle` block in `_prefetch` (lines 78-89) with `http.get(Uri.parse(url)).timeout(const Duration(seconds: 8))`.
- Return `response.bodyBytes` on `200`, `null` otherwise.
- Add a `debugPrint('share-card prefetch failed: $e')` in the catch block so future failures aren't silent.
- Optionally: add a 2nd fallback — if `_prefetch` returns null, await a `precacheImage(NetworkImage(url), context)` before calling `_capture`, so the offscreen render at least has a chance against the network image cache. (Keep this lightweight; not the primary fix.)

**Patterns to follow:**
- `lib/features/notifications/...` doesn't help here — push is unrelated.
- The Supabase client uses `http` internally; `package:http` is almost certainly already in the dep tree.

**Test scenarios:**
- Happy path: `http.get` returns 200 + JPEG bytes → `_prefetch` returns those bytes → ShareCard renders `Image.memory` → exported PNG contains the photo (size > 50 KB, not the ~2 KB of the fallback).
- Edge case: `http.get` returns 404 → `_prefetch` returns null → ShareCard falls through to `CachedNetworkImage` → exported PNG shows the navy fallback (acceptable degraded state, with a `debugPrint` in logs).
- Edge case: `http.get` times out (8s) → `_prefetch` returns null → same degraded fallback.
- Edge case: Catch has no photos (`photoPaths.isEmpty`) → `_resolvePhotoUrl` returns null → ShareCard renders the fallback panel directly (no prefetch attempted). Already correct, just verify.
- Integration: On TestFlight, share a catch with a real Supabase Storage photo → resulting share-sheet preview includes the photo.

**Verification:**
- TestFlight: Open a catch with a photo → tap the share icon (top right of detail screen) → iOS share sheet appears with the catch's photo as the preview thumbnail.
- Backstop: `flutter logs` (or Console.app) shows no `share-card prefetch failed` line during a successful share.

---

- U6. **Bump version + ship 1.0.0+5 to TestFlight**

**Goal:** All five fixes shipped to internal testers as a single TestFlight build.

**Requirements:** R7

**Dependencies:** U1, U2, U3, U4, U5

**Files:**
- Modify: `pubspec.yaml` — bump `version: 1.0.0+4` → `version: 1.0.0+5`

**Approach:**
- `flutter clean && flutter pub get && flutter build ipa --release`
- Upload via Xcode → Window → Organizer → Distribute App → App Store Connect → Upload (same as `+4`)
- Wait for Apple processing (~10–30 min)
- Internal testers (Bunshin team) get the update notification automatically; tap Update in TestFlight.

**Test expectation:** none — this is a release-and-distribution unit, no behavior change.

**Verification:**
- TestFlight on iPhone shows version `1.0.0 (5)` available.
- After updating, run the §QA matrix below covering all five bugs back-to-back.

---

## Post-build TestFlight QA matrix

A single sweep on a real iPhone after `1.0.0 (5)` lands:

- [ ] **Bug 1:** Sign in → Friends tab → "Your Handle" card shows the actual handle (not email local-part). Edit Profile → change username → Friends tab again → card reflects the new handle.
- [ ] **Bug 2a:** Me tab → scroll to bottom → "Sign out" tile is fully visible, not obscured by the nav bar.
- [ ] **Bug 2b:** Bottom nav → "Tourneys" tab label is single-line on the iPhone you're testing.
- [ ] **Bug 3:** Tap center Log FAB → Catch Log screen → tap X → returns to the previous tab. Repeat from a different tab.
- [ ] **Bug 4:** Open any catch from the grid → detail screen → photo fills the full top area, no navy gutters above or below.
- [ ] **Bug 5:** From the catch detail, tap the share icon → iOS share sheet preview shows the catch photo, not a navy panel.

If any item fails: identify the unit, hot-fix, bump to `1.0.0+6`, re-upload, retest.

---

## System-Wide Impact

- **Interaction graph:** None of the fixes change any callbacks, middleware, or observers. All changes are local to single widgets / providers.
- **Error propagation:** U5 makes share-card photo prefetch failures explicit (logged via `debugPrint`) instead of silent. No user-facing error change.
- **State lifecycle risks:** None. No state machines or persistence changes.
- **API surface parity:** No public API changes. All modifications are internal.
- **Integration coverage:** U1's profile flow already has integration tests for the Me screen — adding parity for Friends tab. U5's share flow is best verified manually on real device (offscreen rendering is hard to test in widget tests).
- **Unchanged invariants:** Supabase schema, RLS policies, edge functions, and auth flow are explicitly not changed by this batch.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| `package:http` may not be a direct dependency, requiring a `pubspec.yaml` add. | U5's first sub-task is `flutter pub deps \| grep http` to verify. If absent, add `http: ^1.2.0` and re-run `pub get`. |
| Bumping bottom-nav font from 11→10 (if needed) makes the bar feel unbalanced visually. | Only drop the font if `maxLines: 1, overflow: fade` doesn't hold the wrap on iPhone SE width. Most likely the overflow handling alone is enough. |
| Removing `AspectRatio` from `CatchPhotoCarousel` breaks the no-photo placeholder layout. | U4's test scenario covers the no-photo case explicitly; verify visually on simulator before shipping. |
| Share-card prefetch fix surfaces a different latent bug (image too large, codec issue, etc.). | The `debugPrint` added in U5 will surface this on the next test build; iterate from there. Acceptable to ship with the fallback if the photo fails — that's still better than today's "always navy". |
| App Reviewers test bug 2 (nav coverage) on a small-screen iPhone we don't have. | Widget tests at 375pt cover the iPhone SE case — the smallest currently-supported width. |

---

## Documentation / Operational Notes

- After this batch ships and is verified on TestFlight, capture two short solutions docs in `docs/solutions/`:
  - `2026-05-03-bottom-nav-clearance.md` — the per-screen padding pattern, why we chose it over a global widget.
  - `2026-05-03-share-card-prefetch.md` — why `NetworkAssetBundle` is wrong for arbitrary URLs, and the `http.get` + timeout pattern.
- Update `docs/deployment/ios-checklist.md` §7 (real-device QA matrix) to include the five bugs as explicit checkboxes for future release builds.

---

## Sources & References

- Direct user reports (Jose Diaz, 2026-05-03 TestFlight install, build 1.0.0+4)
- Code:
  - `lib/features/friends/presentation/friends_screen.dart`
  - `lib/core/router/app_shell.dart`
  - `lib/features/catches/presentation/catch_log_screen.dart`
  - `lib/features/catches/presentation/catch_detail_screen.dart`
  - `lib/features/catches/presentation/widgets/catch_photo_carousel.dart`
  - `lib/features/storytelling/application/share_card_export.dart`
  - `lib/features/storytelling/presentation/widgets/share_card.dart`
- Related: `docs/deployment/ios-checklist.md`, `docs/solutions/2026-05-01-storytelling-server-detection.md`
