---
title: "fix: TestFlight bug batch 2 — auth links, nav clearance, keyboard dismiss, tournament join + creator handle, polish"
type: fix
status: active
date: 2026-05-03
---

# fix: TestFlight bug batch 2 — auth links, nav clearance, keyboard dismiss, tournament join + creator handle, polish

## Summary

Thirteen items from the second TestFlight pass. Mix of follow-ups on previously-claimed fixes that didn't fully land (bottom-nav clearance, Tourneys label, share-card photo, catch-log back button), real new bugs (signup/recovery emails 403, keyboard won't dismiss, stale M6 placeholder), and missing UI surfaces (notification swipe-delete, tournament join-code entry, creator self-display). All shippable as `1.0.0+13` on a single bug-fix branch.

---

## Problem Frame

After v1.0.0+12 went out, the user found 13 issues in a fresh real-device pass. Some are App Store blockers (auth confirmation links 403 means signup is broken), some are visible polish issues (nav-bar covering content despite the prior fix), some are missing affordances (no way to enter a tournament join code despite the join-code feature existing), and a few are stale dev-status copy that escaped the v1 polish pass. Holding submission on these is the right call — App Reviewers will see them too.

---

## Requirements

- R1. Tapping the confirmation/recovery link in a signup or password-reset email lands on a working page that confirms the auth event, not a 403.
- R2. The bottom nav bar sits at the bottom of the safe-area such that no interactive element on Home, Catches, Tourneys, Map, Friends, or Me is covered or partially blocked.
- R3. The "Tourneys" label on the bottom nav renders fully on a single line on every supported iPhone width — no character truncation, no fade.
- R4. On the Catch Log screen, the leading toolbar button (or system back gesture) reliably dismisses the screen and visually reads as "back" to the user.
- R5. The share-card export contains the catch's actual photo, not a navy fallback panel, when the catch has a photo.
- R6. After entering a value in any numeric field (weight, length) on the Catch Log screen, the keyboard can be dismissed by tapping outside the field.
- R7. After entering text in the rig/lure/bait or notes fields, the keyboard can be dismissed by tapping outside.
- R8. The rig/lure/bait and notes fields use a hint-text pattern that disappears on focus, not the floating-label animation that "looks weird."
- R9. The Conditions row inside Additional Details no longer shows "auto-filled in M6" stub copy; M6 shipped, conditions populate after save.
- R10. Notifications can be deleted via swipe-left on each notification row.
- R11. When the creator invites friends, those invitees become tournament members in `accepted` status directly — no double-confirmation step where the creator must approve their own invites.
- R12. There's a discoverable entry point on the Tournaments tab where a non-friend angler can paste a join code to enter a tournament.
- R13. On the tournament Members tab, the creator's row in the Accepted section shows the creator's actual handle (or display name), not the `@angler` fallback.

---

## Scope Boundaries

- No redesign of Home, Tournaments, or Notifications screens — surgical fixes only.
- No changes to the underlying tournament join/accept state machine beyond what R11 requires.
- No new Supabase migrations beyond R10's notification-delete RLS policy and R11's invite-as-accepted clarification (already supported by 0022 if we choose `accepted` at insert time).
- Push notification delivery debugging stays deferred until a USB cable is available — out of scope for this batch.

### Deferred to Follow-Up Work

- Wire iOS Universal Links / `CFBundleURLTypes` so the email confirmation link opens the app directly instead of bouncing through GitHub Pages. Web fallback in this batch is sufficient for v1.
- Move push registration call from `save_catch_controller.dart:75` (post-first-catch) to a sign-in / onboarding-completion hook. Decided as v1.1 work in the prior plan.
- Standalone "Pending invites" surface for the invitee side. The current notification + tournament detail entry covers v1; the dedicated screen is v1.1+.

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/auth/presentation/forgot_password_screen.dart:37` — `auth.resetPasswordForEmail(email)` is called WITHOUT `emailRedirectTo`. Defaults to Supabase's Site URL.
- `lib/features/auth/presentation/sign_in_screen.dart:51` — `auth.signUp(...)` is called WITHOUT `emailRedirectTo`. Same default behavior.
- `lib/core/router/app_shell.dart:67` — `Scaffold(extendBody: true, ...)` is the source of "content scrolls under the nav." The 88pt+viewPadding compensation we added to consumer screens can still be off by ~16-32pt on certain device classes; the deeper fix is to reconsider `extendBody: true` itself.
- `lib/core/router/app_shell.dart:160-170` — `_NavItem` Text uses `fontSize: 11`, `maxLines: 1`, `softWrap: false`, `overflow: TextOverflow.fade`. The fade truncates the trailing "s" in "Tourneys" at the smallest tab widths.
- `lib/features/me/presentation/me_screen.dart:228` — current `SizedBox(height: 88 + viewPadding.bottom)` trailing padding. Insufficient on the user's device.
- `lib/features/catches/presentation/catch_log_screen.dart:221-236` — leading IconButton uses `Icons.close` with canPop+go-home fallback. User reports "the arrow doesn't work" — the icon is X, not an arrow, which is the actual UX confusion.
- `lib/features/catches/presentation/widgets/additional_details_section.dart:42-53` — rig and notes fields use `labelText` (floating-label) instead of `hintText`. Line 88 has the stale "auto-filled in M6" copy. The whole `_ConditionsStub` is dead code now that M6 shipped.
- `lib/features/catches/presentation/widgets/unit_toggle_field.dart:172-180` — numeric weight/length fields use `keyboardType: numberWithOptions(decimal: true)`. iOS numeric keyboards have no Done button; tap-outside-to-dismiss is the standard escape.
- `lib/features/storytelling/application/share_card_export.dart` — `_prefetch` uses `http.get` + timeout (PR #5 fix). User still reports navy fallback. Possible causes: signed-URL resolution failing, image bytes not decoding, or the user is on a build that predates the fix.
- `lib/features/notifications/presentation/notifications_screen.dart:66` — `_NotificationTile` is plain `ListTile`; no `Dismissible` wrap. Repository at `lib/features/notifications/data/notifications_repository.dart` likely lacks a `delete(notificationId)` method.
- `lib/features/tournaments/presentation/widgets/members_tab.dart:219-224` — looks up `member.anglerId` in `friendsBundleProvider.profilesById`. The current user's own profile isn't in their friends bundle, so creators see `@angler` as the fallback in the Accepted section.
- `lib/features/tournaments/presentation/widgets/members_tab.dart:182` — copy says "they enter it from the Tournaments tab" but there's no UI on the Tournaments tab for that. Code/UI mismatch.
- `lib/features/tournaments/presentation/invite_friends_sheet.dart` — need to read to confirm what status creator-invited members get inserted with (R11).
- `supabase/migrations/0001_init.sql:376-380` — `notifications` table has `select_own` and `update_own` policies but no `delete_own`. R10 needs a migration adding `notifications_delete_own`.

### Institutional Learnings

- `docs/solutions/2026-05-01-storytelling-server-detection.md` — server-side trigger model. Not directly relevant.
- No prior solutions doc covers the share-card prefetch reliability issue or the auth-redirect 403; both are candidates for documentation after this batch lands.

### External References

- Skipped — every item is grounded in local patterns and prior context.

---

## Key Technical Decisions

- **Decision:** Set `extendBody: false` on the AppShell Scaffold and remove per-screen 88pt padding shims. **Rationale:** the per-screen compensation works but is fragile across device classes (iPhone SE, iPhone 16 Pro Max, iPad in compact width). With `extendBody: false`, the body stops at the nav bar's top edge automatically. The raised Log button still pokes above into the body area via the Stack's `clipBehavior: Clip.none`, so the visual identity is unchanged. This is a simpler model and matches how App Store reviewer expectations align with stock Material/Cupertino bottom nav.
- **Decision:** Replace `TextOverflow.fade` on nav labels with `FittedBox(fit: BoxFit.scaleDown)`. **Rationale:** scaleDown shrinks "Tourneys" to fit horizontally without truncating any character, and at typical widths it doesn't shrink at all. The fade approach lost a literal character of information; FittedBox preserves all six.
- **Decision:** Pass explicit `emailRedirectTo: 'https://josebunshin.github.io/fishingwithfriends/'` to both `auth.signUp` and `auth.resetPasswordForEmail`. **Rationale:** removes ambiguity from Supabase's Site URL fallback. Even if the dashboard's Site URL drifts, the client-side intent is unambiguous and easy to grep for.
- **Decision:** Tap-outside-to-dismiss via a top-level `GestureDetector` wrap on the Catch Log screen body, instead of adding a `keyboard_actions` dependency. **Rationale:** zero new dependencies, applies uniformly to weight, length, rig, notes. Standard Flutter pattern. Tradeoff: tap-outside also works for the form's other tap targets, which is correct UX (tapping the date picker should both close the keyboard AND open the picker — a double action that's natural).
- **Decision:** Switch rig/notes fields from `labelText` to `hintText`. **Rationale:** the floating-label animation is what the user finds "weird" — it physically moves the label into the top-left of the field. Hint text disappears on focus and reappears when empty. Cleaner, more predictable.
- **Decision:** Remove `_ConditionsStub` entirely from `additional_details_section.dart`. **Rationale:** M6 shipped; conditions populate after save and surface on the catch detail screen. The stub only confused users by promising a feature in M6 that's already delivered.
- **Decision:** Add a single "Enter join code" tile/button at the top of the Tournaments tab (above the partitioned list) that opens a sheet to paste the 8-char code. **Rationale:** discoverable, single-tap, doesn't add a new tab.
- **Decision:** Make creator-invited members `accepted` directly (skip the pending step) in the invite flow. **Rationale:** the creator is choosing whom to add — the pending step is redundant friction and the user's confusion confirms it. Non-friend join-code paths still go through pending → creator approval, which matches the original spec for cold invites.
- **Decision:** For the creator's own row in Accepted, fall back to `myProfileProvider` when `friendsBundleProvider` doesn't carry the current user's profile. **Rationale:** smallest change. Don't restructure the friends bundle to include self; just add a self-aware lookup.

---

## Open Questions

### Resolved During Planning

- **Should we replace the X icon on Catch Log with a back arrow?** Yes. The user's "the arrow doesn't work" is actually "I see an X and I expected an arrow"; the handler is fine, the icon is wrong. Switching to `Icons.arrow_back_ios_new` removes the confusion.
- **Should creator-invited members go directly to `accepted` or stay `pending`?** `accepted` (R11). Pending is for cold invites via join code, where the creator's approval IS load-bearing. For warm invites the creator is already approving by sending.
- **Is there a Supabase config issue causing the email 403?** Likely yes — the redirect-URL allowlist may not include the current GitHub Pages URL with the right glob, OR the Site URL is stale. Plan covers both client-side (`emailRedirectTo`) and dashboard-side (verify allowlist).

### Deferred to Implementation

- Whether `_prefetch` in `share_card_export.dart` needs additional logging or just needs verification on a fresh build — depends on what the implementer sees when reproducing R5.
- Exact value of `extendBody`-correction needed on the Map screen's Floating Action Buttons (recenter, layer toggle) — depends on visual testing post-AppShell change.

---

## Implementation Units

- U1. **Auth: explicit emailRedirectTo + verify Supabase URL allowlist**

**Goal:** Signup and password-reset email links land on the GitHub Pages confirmation page (no 403) and the user sees the right card (signup confirmed / set new password in app).

**Requirements:** R1

**Dependencies:** None. The Supabase dashboard verification is a prerequisite for testing but not for the code change.

**Files:**
- Modify: `lib/features/auth/presentation/sign_in_screen.dart`
- Modify: `lib/features/auth/presentation/forgot_password_screen.dart`

**Approach:**
- Pass `emailRedirectTo: 'https://josebunshin.github.io/fishingwithfriends/'` to both `auth.signUp(...)` and `auth.resetPasswordForEmail(...)`. Trailing slash is intentional — must match exactly what's in the Supabase redirect-URL allowlist.
- Pre-implementation dashboard verification (call out in PR description): in Supabase → Auth → URL Configuration, confirm:
  - Site URL: `https://josebunshin.github.io/fishingwithfriends/`
  - Redirect URLs (allowlist): includes `https://josebunshin.github.io/fishingwithfriends/**` (the `**` glob is required)
- If the user reports 403 still after this change, the next layer is the `index.html` JS handler — but most likely it's a missing allowlist entry.

**Patterns to follow:**
- The Supabase Flutter SDK `signUp(email, password, emailRedirectTo)` signature is documented. Both calls use the same redirect URL.

**Test scenarios:**
- Happy path: New user signs up with a real email → email arrives → tap confirmation → lands on `https://josebunshin.github.io/fishingwithfriends/#type=signup` → "Email confirmed!" card shows.
- Happy path: User taps "Forgot password" → email arrives → tap link → lands on `#type=recovery` → "Open the app" card shows.
- Edge case: User taps the email link more than 1 hour after it was sent → Supabase rejects token → user lands on `#error=otp_expired` → expired-link card shows.
- Edge case: User taps the link from a desktop browser instead of phone → same flow renders, just no app to open.

**Verification:**
- A fresh signup completes without a 403 anywhere in the chain.
- A fresh password recovery completes without a 403.

---

- U2. **AppShell: extendBody:false + per-screen padding cleanup + Tourneys FittedBox**

**Goal:** Bottom nav sits at the bottom of the safe area without obscuring any content. Tourneys label renders fully without truncation.

**Requirements:** R2, R3

**Dependencies:** None

**Files:**
- Modify: `lib/core/router/app_shell.dart` (extendBody, _NavItem text)
- Modify: `lib/features/me/presentation/me_screen.dart` (remove the +88 padding shim)
- Modify: `lib/features/home/presentation/home_screen.dart` (remove the +88 padding shim)
- Modify: `lib/features/tournaments/presentation/tournaments_screen.dart` (remove)
- Modify: `lib/features/friends/presentation/friends_screen.dart` (remove)
- Modify: `lib/features/catches/presentation/catches_screen.dart` (remove)
- Test: `test/router/app_shell_test.dart` (extend the existing iPhone-SE label test)

**Approach:**
- In `AppShell.build`, change `Scaffold(extendBody: true, ...)` to `extendBody: false`. The Stack's `clipBehavior: Clip.none` plus the raised Log button's `top: -22` already let the FAB visually overlap the nav bar; the body no longer scrolls under the nav, eliminating the per-device clearance fragility entirely.
- In `_NavItem` Text, replace `maxLines: 1, softWrap: false, overflow: TextOverflow.fade` with `FittedBox(fit: BoxFit.scaleDown, child: Text(...))`. Tourneys (8 chars) renders at 100% on iPhone SE+ and scales 80-90% on the tightest widths.
- In each shell-route screen, remove the trailing `SizedBox(height: 88 + MediaQuery.viewPaddingOf(context).bottom)` (or the equivalent in SliverPadding bottom). Replace with the original natural trailing padding — the screens used to have a trailing AppSpacing.xxl-ish gap; restore that.
- Map screen positioned controls — keep their `bottom:` offsets as-is; with `extendBody: false`, those land in the body area which now ends at the nav bar's top, so they fit without overlap.

**Patterns to follow:**
- The existing `tabPaths` static for tests is preserved.

**Test scenarios:**
- Happy path: At iPhone 15 Pro width (393pt), all six tab labels render single-line.
- Edge case: iPhone SE (375pt), "Tourneys" still renders all 8 characters (FittedBox scales rather than truncates).
- Integration: Me screen scrolled to the bottom — the "Sign out" tile is fully visible above the nav bar with no overlap.
- Integration: Home / Tournaments / Friends / Catches scrolled to bottom — last item fully visible.

**Verification:**
- TestFlight on real iPhone: visually confirm Tourneys label complete, Sign Out button fully tappable, no content scrolls behind nav.

---

- U3. **Catch Log: back arrow icon + tap-outside keyboard dismiss**

**Goal:** Catch Log's leading toolbar button visually reads as a back arrow; tapping anywhere outside a text field dismisses the keyboard.

**Requirements:** R4, R6, R7

**Dependencies:** None

**Files:**
- Modify: `lib/features/catches/presentation/catch_log_screen.dart`
- Test: `test/features/catches/catch_log_screen_test.dart` (extend if exists, create if missing)

**Approach:**
- Change leading icon from `Icons.close` to `Icons.arrow_back_ios_new`. Keep the existing `canPop()` + `context.go(home)` fallback handler — that part already works.
- Wrap the Catch Log body's outer `Form` in a `GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => FocusScope.of(context).unfocus())`. Translucent ensures the GestureDetector doesn't swallow taps from buttons, fields, etc. — it just adds a "tap on empty space dismisses keyboard" behavior.

**Patterns to follow:**
- `lib/features/catches/presentation/catch_detail_screen.dart:60-63` uses `Icons.arrow_back` for its leading. Mirror that.

**Test scenarios:**
- Happy path: Open Catch Log → see back arrow → tap → returns to previous tab.
- Happy path: Type in weight field → tap blank area below the form → keyboard dismisses.
- Happy path: Type in length field → tap blank area → keyboard dismisses.
- Happy path: Type in rig → tap blank area → keyboard dismisses.
- Happy path: Type in notes → tap blank area → keyboard dismisses.
- Edge case: While saving, tap back arrow → button disabled, no action (existing behavior preserved).

**Verification:**
- Tap arrow always returns to previous screen.
- Numeric and text fields can all be exited via tap-outside.

---

- U4. **Additional Details: hint text + remove M6 stub**

**Goal:** Rig/lure/bait and Notes fields use disappearing hint text. The "auto-filled in M6" stub is gone.

**Requirements:** R8, R9

**Dependencies:** None

**Files:**
- Modify: `lib/features/catches/presentation/widgets/additional_details_section.dart`

**Approach:**
- Change `labelText: 'Rig / lure / bait'` to `hintText: 'Rig / lure / bait'` on the rig field. Remove `alignLabelWithHint: true` from the notes field and change its `labelText: 'Notes'` to `hintText: 'Notes'`.
- Delete `_ConditionsStub` class entirely. Remove its instantiation from the children list. Remove the `SizedBox(height: AppSpacing.md)` that preceded it.

**Patterns to follow:**
- Other fields in the codebase that use hintText: `catch_log_screen.dart:316` (Location field uses `hintText: 'Lake, river, or city'`). Mirror that pattern.

**Test scenarios:**
- Happy path: Tap rig field → hint disappears → type → text appears.
- Happy path: Clear rig field → hint reappears.
- Happy path: Open Catch Log, expand Additional Details → no "auto-filled in M6" copy is present anywhere.

**Verification:**
- Visually inspect the additional-details section on TestFlight; confirm clean fields with hint text and no dev-status copy.

---

- U5. **Share card: verify photo prefetch + add SnackBar fallback**

**Goal:** Sharing a catch with a photo produces a card with the catch's photo, not the navy panel.

**Requirements:** R5

**Dependencies:** None

**Files:**
- Modify: `lib/features/storytelling/application/share_card_export.dart`

**Approach:**
- The current `http.get` + 8s timeout fix from PR #5 is correct in principle. Three things may still be wrong:
  1. The signed URL resolution fails silently (`_resolvePhotoUrl` returns null when an exception is caught).
  2. The fetched bytes are an unsupported codec (HEIC) on iOS, but Image.memory falls back rather than failing visibly.
  3. The user is on a build that predates the fix — verify with TestFlight version first.
- Add minimal explicit logging: when `_resolvePhotoUrl` returns null, `debugPrint('share-card: signed URL resolution returned null for catch ${catch_.id}')`. When `_prefetch` returns null, that already logs.
- If after rebuilding and reinstalling user still sees the navy fallback: surface a SnackBar via the calling context with the failure reason ("photo couldn't load — sharing without it"). Don't block the share — just communicate.
- Verify the catch's `photoPaths` array is non-empty before falling through (already done at line 68).

**Patterns to follow:**
- The existing `_prefetch` returns null with debugPrint on failure. Mirror that for `_resolvePhotoUrl`.

**Test scenarios:**
- Happy path: Catch with a single JPEG photo → share → resulting share-sheet preview includes the photo.
- Edge case: Catch with no photos → share card renders fallback (existing behavior, verify still correct).
- Error path: Signed-URL resolution fails (mock throw on `signedUrl`) → SnackBar surfaces "photo couldn't load" → card still exports without photo.
- Error path: HTTP returns 404 → SnackBar surfaces same → fallback panel.

**Verification:**
- On a TestFlight build with `1.0.0+13`, share a catch that has a known-good photo. iOS share sheet preview shows the photo.
- If still broken: the debugPrint output (visible in Console.app once cable is available) names the failure mode.

---

- U6. **Notifications: swipe-to-delete + RLS migration**

**Goal:** Users can swipe-left on a notification row to delete it. Repository handles the delete; RLS allows it.

**Requirements:** R10

**Dependencies:** Migration 0027 must be applied to prod Supabase before the client-side delete works.

**Files:**
- Create: `supabase/migrations/0027_notifications_delete_own.sql`
- Modify: `lib/features/notifications/data/notifications_repository.dart` (add `delete(id)` method)
- Modify: `lib/features/notifications/presentation/notifications_screen.dart` (Dismissible wrap)
- Test: `test/features/notifications/notifications_screen_test.dart` (create if missing)

**Approach:**
- Migration 0027 adds:
  ```sql
  create policy notifications_delete_own on public.notifications
    for delete to authenticated using (recipient_id = auth.uid());
  notify pgrst, 'reload schema';
  ```
- Repository gains `Future<void> delete(String notificationId) async` that calls `from('notifications').delete().eq('id', id)`.
- In `_NotificationTile`, wrap the `ListTile` in `Dismissible(key: ValueKey(notification.id), direction: DismissDirection.endToStart, background: Container(color: scheme.error, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: AppSpacing.lg), child: Icon(Icons.delete_outline, color: scheme.onError)), onDismissed: ...)`.
- `onDismissed`: call `repo.delete(notification.id)` and `ref.invalidate(myNotificationsProvider)`. Wrap in try/catch with snackbar on failure.

**Patterns to follow:**
- The repository's existing `markRead(id)` shape — single-row update by id.
- Standard Flutter `Dismissible` pattern with ValueKey from the notification id.

**Test scenarios:**
- Happy path: Swipe a notification row to the left → row animates away → row is gone from the list after refresh.
- Edge case: Swipe-to-delete an unread notification → unread count drops by 1 (the unread provider auto-recomputes).
- Error path: Network failure during delete → SnackBar shows "couldn't delete notification" → list invalidates and the row reappears.
- Integration: Two users — User A's notification can't be deleted by User B (RLS enforcement, verifiable via direct SQL test).

**Verification:**
- Migration applied, swipe-delete works, deleted notifications stay deleted across app restarts.

---

- U7. **Tournaments: enter-join-code surface on Tournaments tab**

**Goal:** A non-friend angler with a join code has a clear UI to enter it.

**Requirements:** R12

**Dependencies:** None — backend join-code flow already works (existing `joinByCode` flow on the server side).

**Files:**
- Modify: `lib/features/tournaments/presentation/tournaments_screen.dart`
- Create: `lib/features/tournaments/presentation/join_by_code_sheet.dart`
- Test: `test/features/tournaments/join_by_code_sheet_test.dart`

**Approach:**
- Add a second action button in the AppBar actions (next to the existing "+ Create" button) — an `Icons.qr_code_2_outlined` or `Icons.password` icon that opens `JoinByCodeSheet`.
- ALSO add a tappable card at the top of the partitioned list (above "Live now" / "Open for entry") titled "Have a join code?" that opens the same sheet. Two entry points because the AppBar action is easy to miss.
- `JoinByCodeSheet` is a `showModalBottomSheet` with: title "Enter join code", a single TextField (uppercase formatting, max 8 chars), a Submit button. On submit: call existing tournaments repository `joinByCode(code)` method (verify it exists; if not, add it). On success: pop sheet, navigate to `/tournaments/<new-tournament-id>`. On failure (bad code, already a member, expired, closed): error text inline.

**Patterns to follow:**
- `lib/features/tournaments/presentation/create_tournament_sheet.dart` — modal bottom sheet pattern. Mirror its structure.
- `lib/features/tournaments/presentation/widgets/members_tab.dart:172-178` — uppercase 8-char join code styling. Use the same uppercase input formatter.

**Test scenarios:**
- Happy path: User taps "Have a join code?" → enters valid 8-char code → submits → sheet pops → user is on tournament detail screen as a pending member.
- Edge case: Input less than 8 chars → submit button disabled.
- Edge case: Input lowercase → auto-uppercased.
- Error path: Code doesn't match any tournament → "Invalid code" inline error.
- Error path: User is already a member → "You're already in this tournament" inline error.
- Error path: Tournament has ended → "This tournament is closed" inline error.
- Edge case: User is the creator of the tournament with this code → graceful no-op or "You created this one" message.

**Verification:**
- Two test accounts: A creates a tournament, B uses code from A's screen to join via B's Tournaments tab → B appears as pending member on A's Members tab.

---

- U8. **Tournaments: creator-invited members go directly to `accepted`**

**Goal:** When the creator uses Invite Friends to add anglers, those anglers' member rows insert with `status='accepted'` directly. No double-confirmation by the creator.

**Requirements:** R11

**Dependencies:** RLS policy `tournament_members_insert_creator` from migration 0022 already permits any status — no migration changes needed.

**Files:**
- Modify: `lib/features/tournaments/presentation/invite_friends_sheet.dart` (or whatever file owns the insert call — verify during implementation)
- Modify: `lib/features/tournaments/data/tournaments_repository.dart` (verify the method that creator calls; ensure it inserts `status='accepted'` not `'pending'`)
- Test: extend whatever existing test exercises the invite flow, or add one.

**Approach:**
- Find the call site where the invite flow inserts member rows. The tournament_members table accepts both `pending` and `accepted` per migration 0001 schema; the creator-insert RLS policy from 0022 doesn't constrain status. Just change the insert payload from `'pending'` to `'accepted'`.
- Notify invitees: existing tournament_invite notification trigger fires regardless of status. Verify the invitee gets a notification "you were added to <tournament>" — content might need a copy tweak from "you've been invited" to "you've been added" since there's no pending step.
- Cold-invite (join code) flow stays at `pending` — that's a different code path.

**Patterns to follow:**
- The existing creator-invite insertion logic — just flip one field value.

**Test scenarios:**
- Happy path: Creator invites friend X → X immediately appears in the Accepted section of the Members tab → no Pending entry.
- Happy path: X (the invitee) opens their notifications → sees "added to <tournament>" notification → tapping it goes to the tournament detail.
- Integration: Creator invites X via the sheet, then opens Members tab → no Approve/Reject buttons appear for X (since X is already accepted).
- Regression: Cold-invite flow (User Y enters the join code) still goes to `pending` and shows the creator the Approve/Reject buttons.

**Verification:**
- The invite flow lands at `accepted` directly, observable via Supabase SQL `select status from tournament_members where tournament_id = ... and angler_id = ...`.

---

- U9. **Tournaments: creator's own row resolves their handle in Accepted**

**Goal:** On the Members tab, the creator's row in the Accepted section shows their actual handle/display name, not `@angler` fallback.

**Requirements:** R13

**Dependencies:** None

**Files:**
- Modify: `lib/features/tournaments/presentation/widgets/members_tab.dart`

**Approach:**
- In `_MemberRow.build`, before reading from `friendsBundleProvider.profilesById`, also watch `currentUserProvider` and `myProfileProvider`. If `member.anglerId == currentUser.id`, prefer `myProfile` over the friends bundle.
- Concrete logic:
  ```
  final me = ref.watch(currentUserProvider);
  final myProfile = ref.watch(myProfileProvider).valueOrNull;
  final bundleProfile = bundle?.profilesById[member.anglerId];
  final profile = (member.anglerId == me?.id) ? myProfile : bundleProfile;
  ```
- Same fallback chain after that — `displayName ?? handle ?? '@angler'`.

**Patterns to follow:**
- `lib/features/me/presentation/me_screen.dart:24-32` already uses both providers in tandem.
- `lib/features/friends/presentation/friends_screen.dart:55-62` (post-PR-#5 fix) — same self-aware pattern.

**Test scenarios:**
- Happy path: Creator opens their own tournament's Members tab → in the Accepted section, their row shows their actual handle (`@joe123` or display name "Joe Diaz") — NOT `@angler`.
- Happy path: Same view from a participant's perspective (non-creator) → creator's row shows the creator's handle (this already works because the creator is in the participant's friends bundle if they're friends; if not, falls through to public profile lookup — verify this works or note as known limitation).
- Edge case: Creator has no display name set → row shows `@username`.

**Verification:**
- Visually confirm on TestFlight — creator's own row in Accepted section reads the right name.

---

- U10. **Bump version + ship 1.0.0+13**

**Goal:** All fixes shipped to internal testers as a single TestFlight build.

**Requirements:** All R1–R13

**Dependencies:** U1–U9 complete and merged.

**Files:**
- Modify: `pubspec.yaml` — bump `1.0.0+12` → `1.0.0+13`

**Approach:**
- Standard release cycle. `flutter clean && flutter pub get && flutter build ipa --release`. Upload via Transporter (NOT Xcode Organizer per the prior plan's lesson). Apply migration 0027 in Supabase SQL editor.

**Test expectation:** none — release-and-distribution unit, no behavior change.

**Verification:**
- Supabase SQL editor: confirm migration 0027 applied (`select policyname from pg_policies where tablename = 'notifications';` includes `notifications_delete_own`).
- TestFlight on iPhone shows version `1.0.0 (13)` available.
- Run the post-build QA matrix below covering all 13 bugs.

---

## Post-build TestFlight QA matrix

A single sweep on a real iPhone after `1.0.0 (13)` lands:

- [ ] **Bug 1:** Sign up with a fresh email → tap confirmation link → lands on the GitHub Pages page with "Email confirmed!" card. No 403.
- [ ] **Bug 1 (recovery):** Tap "Forgot password" with an existing email → tap link → lands on "Open the app" recovery card. No 403.
- [ ] **Bug 2 (Home):** Home tab → scroll to bottom → no content covered by nav bar.
- [ ] **Bug 2 (Me):** Me tab → scroll to bottom → Sign Out tile fully tappable, not blocked.
- [ ] **Bug 3:** Bottom nav → "Tourneys" reads with all 8 characters, no fade.
- [ ] **Bug 4:** Tap Log FAB → leading icon is a back arrow → tap → returns to previous tab.
- [ ] **Bug 5:** Open a catch with a photo → tap share → iOS share sheet preview shows the photo (not navy).
- [ ] **Bug 6:** In Catch Log, type a value in weight or length → tap below the form → keyboard dismisses.
- [ ] **Bug 7:** Type in rig/lure/bait → tap blank area → keyboard dismisses.
- [ ] **Bug 8:** Open Additional Details → no "auto-filled in M6" placeholder visible. The Conditions stub is gone.
- [ ] **Bug 9:** Type in notes → tap blank area → keyboard dismisses.
- [ ] **Bug 10:** Notifications → swipe-left on any row → row deletes → stays gone after pull-to-refresh.
- [ ] **Bug 11:** Creator invites friend X → on Members tab, X is in Accepted section directly, no Pending step.
- [ ] **Bug 12:** Tournaments tab → "Have a join code?" entry visible → enter valid code → joined.
- [ ] **Bug 13:** Creator's own row in Members → Accepted shows real handle, not `@angler`.

---

## System-Wide Impact

- **Interaction graph:** AppShell `extendBody` change affects all six shell-route screens — verified via Phase 1 research that no screen currently relies on extendBody:true for a specific overlap effect.
- **Error propagation:** auth `emailRedirectTo` failures surface as Supabase exceptions (existing handling). Notification delete failures surface as SnackBars. Share-card prefetch failures surface as SnackBars and degrade to fallback (existing behavior).
- **State lifecycle risks:** Notification deletion is a hard delete (not soft) — once gone, it's gone. Acceptable for v1; if soft-delete is wanted later, separate migration.
- **API surface parity:** The `delete(id)` method on `NotificationsRepository` is new; no existing call sites need to change.
- **Integration coverage:** U1's auth flow needs a real-email roundtrip to verify (already covered in QA matrix). U6's RLS is verifiable via direct SQL.
- **Unchanged invariants:** All Supabase migrations 0001–0026 stay valid. The push notification pipeline (deferred) is unaffected. The friends bundle and profile providers are read-only used; not restructured.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| The 403 on auth links has a different root cause than missing `emailRedirectTo` (e.g., GitHub Pages truly returning 403). | After U1 ships, verify by manually constructing the redirect URL and hitting it directly in a browser. If it 200s, U1 is the fix. If it 403s, the issue is GitHub Pages config. |
| `extendBody: false` causes a visual regression on the raised Log button (Stack overflow no longer pokes above the body). | Smoke-test on the simulator before commit. The `clipBehavior: Clip.none` on the inner Stack is what makes the overflow visible regardless of extendBody value. |
| FittedBox shrinks "Tourneys" too aggressively on iPhone SE, making it visibly smaller than other labels. | Min font size guard: wrap in `FittedBox` with `fit: BoxFit.scaleDown` (only shrinks, never grows). Visual on iPhone SE simulator before commit. |
| Notification delete migration 0027 silently fails to apply (user forgets to run it). | U10's verification step explicitly checks the policy exists in `pg_policies`. PR description calls out the manual SQL editor step. |
| `joinByCode` repository method doesn't exist or has a different signature than expected. | U7's first sub-task is `grep -rn joinByCode lib/`. If absent, add it during U7. |
| Creator-invited members previously got a "you've been invited" notification — semantically wrong now that they're auto-accepted. | U8 includes copy update from "invited" to "added"; verify before commit. |

---

## Documentation / Operational Notes

- After U10 lands and the QA matrix is green, capture two `docs/solutions/` entries:
  - `2026-05-04-bottom-nav-extend-body.md` — why `extendBody: false` is the right default for AppShell, with the prior padding-shim approach as an anti-pattern reference.
  - `2026-05-04-supabase-auth-redirect.md` — the explicit `emailRedirectTo` pattern + Supabase URL allowlist gotchas, in case the dashboard config drifts again.
- Update `docs/deployment/ios-checklist.md` §7 (real-device QA matrix) to include the bug-batch-2 items.

---

## Sources & References

- Direct user reports (Jose Diaz, 2026-05-03 TestFlight pass on `1.0.0+12`)
- Code:
  - `lib/features/auth/presentation/forgot_password_screen.dart`
  - `lib/features/auth/presentation/sign_in_screen.dart`
  - `lib/core/router/app_shell.dart`
  - `lib/features/me/presentation/me_screen.dart`
  - `lib/features/catches/presentation/catch_log_screen.dart`
  - `lib/features/catches/presentation/widgets/additional_details_section.dart`
  - `lib/features/catches/presentation/widgets/unit_toggle_field.dart`
  - `lib/features/storytelling/application/share_card_export.dart`
  - `lib/features/notifications/presentation/notifications_screen.dart`
  - `lib/features/tournaments/presentation/widgets/members_tab.dart`
  - `lib/features/tournaments/presentation/tournaments_screen.dart`
- Related: `docs/plans/2026-05-03-001-fix-fwf-bug-batch-plan.md` (predecessor; this batch's #2, #4, #5 are revisits of items shipped there)
- External: Supabase Auth `emailRedirectTo` docs (skipped external research; SDK signature is well-known)
