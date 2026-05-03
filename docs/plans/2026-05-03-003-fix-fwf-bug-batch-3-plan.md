---
title: "fix: TestFlight bug batch 3 — navigation trap, friends layout, share photo race"
type: fix
status: active
date: 2026-05-03
---

# fix: TestFlight bug batch 3 — navigation trap, friends layout, share photo race

## Summary

Three TestFlight-reported defects shipped together as v1.0.0+16. The Catch Log success path lands users in a screen with no working back affordance (root cause: `context.go` strips the entire route stack). The Friends/Crew search-result rows render with the username collapsed to one character per line and no avatar for new signups. The share-card export still produces a navy panel where the fish photo should be — the third pass at this bug, this time fixing the underlying cause (`Image.memory` doesn't decode synchronously, so the offscreen `RepaintBoundary` paints before the image is ready).

---

## Problem Frame

This is the third TestFlight feedback batch in 72 hours. Batch-2 shipped 13 fixes; the user has been testing 1.0.0+13 → 1.0.0+15 (auth implicit-flow, in-flight via PR #11) and surfaced these three regressions during walkthroughs:

- **Bug 1 (high — only escape is force-quit):** "When the user hits Log a Catch from the main bar and they add the catch, it is impossible to go back to the main menu by pressing the back button on the page. Nothing works. You can delete the catch but you still can't leave the page. You have to exit the application completely."
- **Bug 2 (high — catastrophic first-impression):** "When a new [user] signs up and they look for their crew, the formatting is really weird. The username is long vertically. No avatar. Nothing — just a weird format that goes the length of the page. Super odd."
- **Bug 3 (high — App Reviewers see this; only viral surface):** "And the catch share is still not populating the fish photo, just a navy blue screen." (This is the third bug-batch attempt at this issue — batch-1 swapped `NetworkAssetBundle` for `http.get`; batch-2 added a SnackBar fallback; the user reports the photo *still* doesn't make it into the captured PNG.)

---

## Requirements

- R1. Tapping "Log a Catch" → submitting → arriving on the catch detail or celebration screen leaves the user with a working back affordance that returns them to the bottom-tab shell. No code path strands the user with an empty navigator stack.
- R2. A newly-signed-up user opening the Friends tab and searching for an angler sees a properly-formatted result row (avatar, primary line on a single ellipsized row, secondary line, trailing "Add" pill) at iPhone SE width and above.
- R3. Sharing a catch with a photo produces a PNG share card that contains the actual fish photo, not the navy `_PhotoFallback` panel — for both freshly-uploaded photos and ones loaded from cache.
- R4. v1.0.0+16 ships with `flutter analyze` clean and `flutter test` green.

---

## Scope Boundaries

- Push-notification APNs token = NULL debugging — **deferred to batch-4** until USB cable available for Console.app device logs.
- Auth/email-redirect work — **already in flight** via PR #11 (1.0.0+15, implicit flow). This plan does not re-touch auth.
- The architectural rewrite of the share-card to a server-side render pipeline — flagged in batch-1's Scope Boundaries as a v1.1+ refactor. This plan delivers the third client-side fix; if it doesn't hold up, batch-4 escalates to server-side rendering.
- General UI polish unrelated to these three bugs.
- New features.

### Deferred to Follow-Up Work

- **`safeBack(BuildContext)` helper** in `lib/core/router/`: abstract the `canPop()`-or-`go(home)` pattern and apply it to every back affordance in the app (notifications, edit profile, settings, tournament detail, trip detail, year-in-review). Batch-3 fixes only the trap caused by U1; the broader audit + refactor goes to a follow-up PR so this batch stays focused.
- **Backfill the four owed `docs/solutions/` entries** (`bottom-nav-clearance`, `share-card-prefetch`, `bottom-nav-extend-body`, `supabase-auth-redirect`) plus a new `go-router-stack-replacement` entry. Track in batch-4 cleanup.
- **Widget-test guard for the `_AnglerRow` layout regression** (would have caught bug 2 before TestFlight). This batch ships a targeted regression test under U2; the broader suite of friend-screen widget tests goes to follow-up.

---

## Context & Research

### Relevant Code and Patterns

- `lib/core/router/app_router.dart:108-222` — single `GoRouter`. Six bottom-tab routes live inside the `ShellRoute`; `/log`, `/catches/:id`, `/celebrate/:catchId`, `/profile/:userId`, etc. are top-level `GoRoute`s outside the shell.
- `lib/features/catches/presentation/catch_log_screen.dart:185, 192` — the bug-1 source. `_save()` success calls `context.go('/celebrate/${saved.id}')` (celebratory branch) or `context.go('/catches/${saved.id}')` (default branch). `context.go` *replaces* the matched configuration → the `[/home, /log]` stack is discarded → the user lands on `/catches/:id` with no underlying route.
- `lib/features/catches/presentation/catch_log_screen.dart:218-235` — the leading IconButton's `canPop()`-or-`go(home)` handler is the established pattern in this codebase; battle-tested in batch-1 and batch-2.
- `lib/features/catches/presentation/catch_detail_screen.dart:60-63, 84` — bare `context.pop()` calls with no `canPop()` guard. After arriving via `context.go(...)`, the stack is empty; pop is a silent no-op on iOS, leaving the user stuck.
- `lib/features/storytelling/presentation/celebration_screen.dart` — same pattern likely applies; the celebration screen's "open the catch" / "back" affordances need the same defensive treatment.
- `lib/features/friends/presentation/friends_screen.dart:256-332` — `_AnglerRow`, the shared row widget for `_SearchResultRow`, `_PendingRow`, `_FriendRow`. Constructed Row[Avatar(48px), Spacer(12), Expanded(Column[Text, Text?]), Spacer(8), trailing]. Username Text has `maxLines:1`, `overflow:TextOverflow.ellipsis`. The structure looks correct on paper.
- `lib/features/friends/presentation/friends_screen.dart:84-87, 227-235` — `_SearchResults` is wrapped in an outer `Padding(horizontal: AppSpacing.lg)`, AND `_AnglerRow` has its own `Container(padding: horizontal: AppSpacing.lg)`. That's 32px each side total for search rows vs 16px for pending/accepted rows — unusual but not enough to cause the symptom described.
- `lib/features/profile/presentation/widgets/avatar_view.dart:25-37` — `AvatarView` is `ClipOval(SizedBox(width: radius*2, height: radius*2, child: ...))`. Always has explicit dimensions; placeholder shows while signed URL resolves. Should never collapse to zero unless something deeper is wrong.
- `lib/core/theme/app_spacing.dart` — `AppSpacing.lg = 16`. Constants are sane; not the cause of bug 2.
- `lib/features/storytelling/presentation/widgets/share_card.dart:64-74` — `_Photo` widget. When `photoBytes != null`, returns `Image.memory(photoBytes!, fit: BoxFit.cover, errorBuilder: ...)`. **The bug-3 source**: `Image.memory` ships bytes off to `instantiateImageCodec` asynchronously. The `ImageStream` completes 1-3 frames later. The capture pipeline's `flushPaint()` runs synchronously and paints the unloaded image — falls through to `_PhotoFallback` (the navy panel). No `frameBuilder`, no precache step.
- `lib/features/storytelling/application/share_card_export.dart:98-121` — `_prefetch` correctly fetches bytes via `http.get` with 8s timeout. Returns `Uint8List?`. Confirmed working per user logs in batch-2 — bytes ARE arriving. The race is downstream.
- `lib/features/storytelling/application/share_card_export.dart:123-173` — `_capture` builds the offscreen pipeline manually: `RenderRepaintBoundary` + `PipelineOwner` + `BuildOwner` + `RenderView` (1080×1920) + `flushLayout/flushCompositingBits/flushPaint` + `repaint.toImage()`. No precache or decode-await step before `flushPaint()`.
- `test/features/storytelling/share_card_test.dart` — only tests `ShareCard` widget render via `pumpAndSettle` (which awaits image decoding inside a normal MaterialApp tree, masking the offscreen-capture race). The export pipeline itself is uncovered by tests.

### Institutional Learnings

- `docs/plans/2026-05-03-001-fix-fwf-bug-batch-plan.md` — batch-1 U5 swapped `NetworkAssetBundle.load('')` for `http.get(...).timeout(8s)` because `NetworkAssetBundle` swallowed errors silently. **Did not fix the decode race.**
- `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md` — batch-2 U5 added a SnackBar fallback when prefetch returned null and surfaced `debugPrint` failure logs. **Bandaid; did not fix the decode race.** Batch-1's Scope Boundaries explicitly flagged this pipeline as "known fragility, server-side render is the proper v1.1+ refactor."
- `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md` — batch-2 U3 changed the Catch Log dismiss icon (the **pre-submit** affordance — what fires when the user backs out before saving) from `Icons.close` to `Icons.arrow_back_ios_new` because the X-icon semantic didn't match user expectations of a back button. The dismiss handler itself was working; only the icon changed. **Bug 1 here is a different problem entirely:** a *post-submit* navigation trap on the destination screen the user lands on after submitting. Fixing batch-2's icon did not touch this, and the present plan does not re-touch the dismiss handler.
- `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md` — batch-2 U9 (creator's row in tournament Members) established the `myProfileProvider`-fallback-to-`friendsBundleProvider` self-aware lookup pattern. Already in `friends_screen.dart:55-62` for the username card.
- `docs/solutions/2026-05-01-storytelling-server-detection.md` — confirms the storytelling layer (PR/badge detection) is decoupled from share-card client rendering. The decode-race fix here doesn't interact with PR/badge logic.
- **Documentation gap finding:** Four `docs/solutions/` entries promised by batch-1 (`bottom-nav-clearance`, `share-card-prefetch`) and batch-2 (`bottom-nav-extend-body`, `supabase-auth-redirect`) were never written. Tracked in Deferred to Follow-Up Work above.

### External References

None gathered. Bugs are well-patterned (go_router behavior, Flutter image decode lifecycle, list row layout) and local Flutter knowledge plus the codebase's own conventions are sufficient.

---

## Key Technical Decisions

- **Bug 1 fix shape: `pushReplacement` over `safeBack` audit.** Replace `context.go(...)` with `context.pushReplacement(...)` on the two `_save()` success paths. **Rationale:** `pushReplacement` swaps the top of the stack only — the underlying shell route survives, so `canPop()` returns true on the destination. Defense-in-depth: also add the `canPop()`-or-`go(home)` guard in `catch_detail_screen.dart`'s back IconButton, post-delete handler, and `_NotAvailable.Back` button. The full `safeBack` helper audit (every back button in the app) goes to a follow-up PR — that scope is bigger than this batch.
- **Bug 2 fix shape: device repro first, then minimal layout fix.** The static read of `friends_screen.dart` doesn't show a clear cause — `_AnglerRow`'s structure looks correct on paper at iPhone SE width. **Rationale:** the symptom (vertical text, no avatar, full-page-length) is canonical for a Row with unbounded constraints. The exec-time job is to (a) reproduce on a real device or matching simulator, (b) capture a Flutter Inspector tree, (c) identify which ancestor is supplying unbounded width or which descendant lost an `Expanded`/`Flexible`. The fix will likely be one or two lines. A widget test at iPhone SE width prevents regression. **Deferred to implementation:** which specific widget gets the bound — `_AnglerRow`'s outer Container, the `_SearchResults` Padding, or the parent ListView's child — depends on what the device repro shows.
- **Bug 3 fix shape: pre-decode bytes to `ui.Image` before capture.** Replace `Image.memory(bytes)` in `_Photo` with a pre-decoded `ui.Image` rendered via `RawImage`. The exporter calls `ui.instantiateImageCodec(bytes)` + `await codec.getNextFrame()` to produce a `ui.Image` *before* building the offscreen tree. **Rationale:** `ui.Image` is already a GPU-side resource — `flushPaint()` has nothing to wait for. This eliminates the race at the source rather than papering over it. The four lower-quality alternatives (frame-pumping loops, `precacheImage` against an isolated `BuildOwner` it can't reach, `Image.memory.frameBuilder` polling, longer timeouts on prefetch) all leave the race intact.
- **Bug 3 architectural escape hatch:** if pre-decoding still produces navy in the wild (e.g., HEIC handling on iOS, very large photos OOMing the codec), batch-4 escalates to the deferred server-side render. This plan does not pre-build that.
- **Version bump:** 1.0.0+15 → 1.0.0+16. PR #11 (auth implicit flow) is independent and already at +15; this batch slots in directly above it.
- **No new SQL migrations.** Migrations 0027 + 0028 from batch-2 are already applied per user confirmation. Batch-3 is pure client-side.
- **Test seam for share-card decode:** extract `Future<ui.Image?> _decodeImage(Uint8List bytes)` as a static or instance helper on `ShareCardExporter`. Unit-test the helper independently with a known-good fixture PNG. The full offscreen-capture path remains uncovered (would require widget-test infrastructure that doesn't exist yet) but the decode invariant — "given good bytes, return a non-null `ui.Image`" — is testable.

---

## Open Questions

### Resolved During Planning

- **Why does `context.go` strand the user on `/catches/:id`?** `go_router` ^14.6.2 docs + verified file structure: `go()` replaces the matched configuration. Top-level `GoRoute` configurations sit outside the `ShellRoute`, so there's no underlying route to pop back to. `pushReplacement` swaps top-of-stack only, leaving the shell route below.
- **Is the share-card prefetch returning bytes successfully or failing silently?** Per batch-2 user logs, prefetch IS returning bytes — the SnackBar fallback never fires. The race is between byte-arrival and decode-completion, downstream of prefetch.
- **Should bug 1 fix every back affordance in the app, or just the trap?** Just the trap for this batch. Full audit deferred to follow-up to keep this batch shippable in one TestFlight cycle.

### Deferred to Implementation

- **Bug 2 root cause localization.** The static read can't pinpoint which widget supplies unbounded constraints. Exec-time: reproduce on device → Flutter Inspector → identify the chain → minimum fix.
- **Whether `_PendingRow` and `_FriendRow` are also broken.** New signups have empty `pendingIncoming` and `accepted`, so they only see search-result rows. Reproduce on a test account with friends to verify.
- **Whether the celebration screen has the same pop trap as the catch detail.** Read `celebration_screen.dart` during U1 implementation; if it has bare `context.pop()` calls, fix them in the same unit.
- **Exact `RawImage` widget shape vs `Image.memory` swap.** Likely `RawImage(image: decoded, fit: BoxFit.cover)`; verify against the existing 1080×1920 layout at execution time.

---

## Implementation Units

- U1. **Catch Log post-submit navigation trap**

**Goal:** Eliminate the dead-end after submitting a catch. After `_save()` success, the user can always return to the bottom-tab shell via the back button.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Modify: `lib/features/catches/presentation/catch_log_screen.dart` (the two `context.go` calls in `_save()` success branches)
- Modify: `lib/features/catches/presentation/catch_detail_screen.dart` (back IconButton, post-delete pop, `_NotAvailable.Back` button)
- Modify: `lib/features/storytelling/presentation/celebration_screen.dart` (verify and fix any bare `context.pop()` calls)
- Test: `test/features/catches/presentation/catch_log_screen_test.dart` (extend existing test) or add `catch_detail_screen_back_test.dart` if the existing test file isn't a fit

**Approach:**

This unit covers two independent fixes that share a symptom but protect different flows. Both must land — the executor cannot ship one without the other and consider U1 done.

**Part A — `pushReplacement` on `_save()` success (fixes the in-app trap):**
- In `_save()`, swap both `context.go('/celebrate/...')` and `context.go('/catches/...')` for `context.pushReplacement(...)`. The semantic is "replace the Log Catch screen with the destination" — preserving the underlying shell route as the pop target.
- This is the only fix that helps users who tapped "Log a catch" from a tab; nothing else restores the shell route below their destination.

**Part B — Defensive `canPop`-or-`go(home)` guards (fixes cold-launch / deep-link / post-delete traps):**
- In `catch_detail_screen.dart`, replace bare `context.pop()` in the SliverAppBar leading IconButton, the delete success handler, and the `_NotAvailable` back button with the established `if (canPop) pop else go(home)` pattern. Mirror `catch_log_screen.dart:228-234`.
- Read `celebration_screen.dart` during implementation and specify the three exit states explicitly:
  - **Back affordance / "Done" button** (user dismisses celebration): `if (canPop) pop else go(home)`. This handles both the "user came from /log via pushReplacement" path (canPop=true → returns to /home) and the cold-launch / deep-link path (canPop=false → routes to /home).
  - **"See catch" button**: switch from `context.go('/catches/$catchId')` to `context.pushReplacement('/catches/$catchId')` so the underlying shell route is preserved on the catch detail screen. Same reasoning as Part A.
  - **`_Fallback` "See catch" button** (rendered when the celebration outcome doesn't load): same `pushReplacement` swap. Even though Part B's `catch_detail_screen.dart` defensive guards backstop a residual `go` here, the `pushReplacement` swap eliminates the trap at the source rather than relying on downstream defense.
  - **Auto-advance timer** (if celebration auto-routes after N seconds): use `pushReplacement` for the same reason, never `go`.
- Part B is the only fix that helps users who arrived at `/catches/:id` via a push notification, deep link, or post-delete navigation. `pushReplacement` does nothing for those flows because there's no `_save()` involved — the canPop guards are the safety net.

**Patterns to follow:**
- `lib/features/catches/presentation/catch_log_screen.dart:228-234` — the `canPop`-or-`go(home)` pattern that's the convention here.

**Test scenarios:**
- Happy path: After saving a catch (non-celebratory), Catch Detail's back button returns to the previous shell route. Use `pumpWidget` with a synthetic `GoRouter` mirroring the production routes; push `/log` from `/catches`; submit; assert post-submit location is `/catches/:id` AND `canPop()` returns true.
- Happy path (celebratory): Same as above but the catch triggers a PR; assert location is `/celebrate/:id` AND `canPop()` returns true.
- Edge case: `_NotAvailable` (catch was deleted server-side between detail-load and back-press) — back button still routes home, no exception.
- Error path: Cold-launch directly to `/catches/:id` (deep link / push notification) — `canPop()` returns false; back button routes to `/home`, no silent no-op.

**Verification:**
- On a real or simulated device, after tapping "Log a catch" from any tab, submitting a catch lands on detail (or celebration) with a working back chevron that returns to that tab. Force-quitting is no longer the only escape.

---

- U2. **Friends search-row layout regression**

**Goal:** New-user Friends tab search renders properly-formatted result rows at iPhone SE width and above. Avatar visible, username on a single ellipsized line, trailing "Add" pill.

**Requirements:** R2

**Dependencies:** None

**Execution note:** Reproduce-first. Localize the bug on a real device or matching simulator (iPhone SE size class is the most likely culprit) before changing code. Capture a Flutter Inspector tree of the broken state — that tree pinpoints which ancestor supplies unbounded width or which descendant lost a layout bound.

**Files:**
- Modify: `lib/features/friends/presentation/friends_screen.dart` (likely scope: `_AnglerRow`, `_SearchResults`, or the `_Body` ListView's child wrapping)
- Test: `test/features/friends/presentation/friends_screen_test.dart` (new file — no friends-presentation widget tests exist yet)

**Approach:**
- **Step 1 — repro (≤30 min):** run on iPhone SE simulator with a fresh signup account; type a search query; capture the broken state via Flutter Inspector. Compare layout tree against a known-good build (1.0.0+12 or earlier).
- **Step 2 — localize:** the symptom (vertical text, no avatar, full-page-length) is canonical for a `Row` with unbounded constraints. Walk the parent chain from `_AnglerRow.Container` upward to find the unbounded ancestor. Most likely candidates: an `IntrinsicWidth` introduced as a parent, a `Wrap` widget, a missing `Expanded`/`Flexible`, or an outer scroll container that doesn't constrain cross-axis.
- **Step 3 — fix:** apply the minimum bound. Likely a single `Expanded` or width assignment. Do NOT defensively `FittedBox` everything — the bug-2 root cause is one specific widget chain, not "Text needs scaling."
- **Step 4 — guard:** add a widget test that pumps `_AnglerRow` (or the `FriendsScreen` body) at iPhone SE width with a sample profile, asserts avatar is visible, asserts the username Text is laid out on a single line (`tester.getSize` width > height for the username's render box).

**Concrete fallback if Step 1 repro fails after 30 minutes:** ship a defensive width-bound fix without root-cause certainty. Specifically: wrap `_AnglerRow`'s primary text Column in an `Expanded` if it isn't already (defense-in-depth even though the static read suggests it is), and add the widget test from Step 4 at three breakpoints: 320pt (iPhone SE 1st gen), 375pt (iPhone SE 2nd/3rd gen), and 414pt (iPhone Pro Max). Defensive bounding is cheap to ship; an unreproducible bug blocking the batch is expensive. A defensive fix that doesn't address the root cause is acceptable here because the symptom (vertical text, no avatar) cannot be silently reintroduced by a future change without the widget test catching it.

**Patterns to follow:**
- `lib/core/router/app_shell.dart` Tourneys-label fix from batch-2 U2 (`FittedBox(scaleDown)`) — *only* if the bug turns out to be that Text needs scaling. Most likely this is NOT the right fix here.
- `test/router/app_shell_test.dart` — the iPhone-SE-width pattern for layout regression tests.

**Test scenarios:**
- Happy path (regression guard): At 375pt width, `_SearchResultRow` with a profile (avatar URL set, displayName "Bobby Bait", handle "@bbait") renders avatar (48px square), primary "Bobby Bait" on a single line, secondary "@bbait" on a second line, trailing "Add" pill — total row height < 80pt.
- Edge case: Profile with no displayName (only handle "@bbait" set) — primary line shows handle, no secondary line, row height < 64pt.
- Edge case: At 320pt width (iPhone SE 1st gen) — row still renders horizontally; username ellipsizes if too long, doesn't wrap to multi-line.
- Integration: Apply the same fix to `_PendingRow` and `_FriendRow` if execution discovers those are also broken (they share `_AnglerRow`); the test should pump all three row types at iPhone SE width.

**Verification:**
- On iPhone SE simulator with a fresh signup account, searching for an angler shows the expected 3-line row layout (avatar | display name + handle | Add pill). No vertical text. No missing avatar.

---

- U3. **Share-card image decode race**

**Goal:** Share-card export PNG contains the actual fish photo, not the navy `_PhotoFallback`. Third-pass fix: address the underlying async-decode race instead of papering over it.

**Requirements:** R3

**Dependencies:** None

**Execution note:** Test-first for the new `_decodeImage` helper. The full offscreen-capture path is hard to widget-test, but the decode invariant ("given good bytes, return a non-null `ui.Image` with width > 0 and height > 0") is unit-testable. Write that test before changing the production decode path.

**Files:**
- Modify: `lib/features/storytelling/presentation/widgets/share_card.dart` (`_Photo` widget — accept `ui.Image?` instead of `Uint8List?`, render via `RawImage`)
- Modify: `lib/features/storytelling/application/share_card_export.dart` (decode bytes to `ui.Image` before building the offscreen tree; add `_decodeImage(Uint8List)` helper; extract a `_captureForTest` seam that exposes the synthetic-tree capture pipeline so tests can assert end-to-end output)
- Test: `test/features/storytelling/share_card_export_test.dart` (new file — exporter currently uncovered)
- Test fixture: `test/fixtures/share-card-photo-jpeg.bin` (small JPEG bytes — committed for the decode helper test)
- Test fixture: `test/fixtures/share-card-photo-heic.bin` (HEIC magic-byte sequence — used to confirm the HEIC-detection path returns a typed error rather than a generic null)

**Approach:**
- Add `Future<ui.Image?> _decodeImage(Uint8List bytes)` on `ShareCardExporter`. Implementation: `await ui.instantiateImageCodec(bytes)` → `await codec.getNextFrame()` → return `frame.image`. Wrap in try/catch; return null on decode failure (HEIC issues, OOM, malformed bytes); log via `debugPrint` for parity with the existing prefetch error path.
- **Falsification guards inside `_decodeImage`** — the diagnosis ("`Image.memory` async-decode races `flushPaint()`") is asserted, not yet verified by instrumentation. The two prior batches each shipped fixes that turned out to be wrong, so this batch pre-builds the data that would let batch-4 skip straight to the real cause if this one also fails:
  - **HEIC magic-byte detection.** Inspect the first 12 bytes of the input. JPEG starts `FF D8 FF`; PNG starts `89 50 4E 47`; HEIC contains `ftypheic` (or `ftyphevc`/`ftypheix`) at bytes 4-11. If the bytes are HEIC, return null with `debugPrint('share-card decode: HEIC bytes (len=${bytes.length}); flutter codec cannot decode')` so the SnackBar fallback fires immediately rather than burning the 8s decode timeout. iOS Photos library returns HEIC for many photos and `instantiateImageCodec` cannot decode it; this is a credible fourth-pass cause that the plan must rule out.
  - **Large-image downsample.** Pass `targetWidth: ShareCard.width.toInt()` (1080) to `ui.instantiateImageCodec` so the codec downsamples in place. This avoids GPU texture-limit silent-no-op rendering on older iOS devices when source photos exceed 4096px on either axis.
  - **Diagnostic logging.** Emit a single `debugPrint('share-card decode: format=$format, sourceLen=${bytes.length}, decoded=${image.width}x${image.height}')` line on success. If the rewrite ships and TestFlight reports navy-panel symptoms a fourth time, this log line is the data needed to localize between codec failure, paint race, and signed-URL TTL.
- **Pre-flight verification before the production rewrite ships** — write a minimal repro test that constructs a synthetic `RenderView` + `PipelineOwner` + `BuildOwner` matching `share_card_export.dart:128-159`, attaches a `RawImage` with a known-good fixture `ui.Image`, runs `flushLayout/flushCompositingBits/flushPaint`, calls `repaint.toImage()`, decodes the resulting PNG, and asserts the center pixel matches the fixture. **If this minimal repro doesn't render the image, the plan's core fix is wrong before any production code changes.** The test belongs in `share_card_export_test.dart` and runs as part of normal `flutter test`. This is the load-bearing test — without it, U3 ships on the same kind of unverified diagnosis that produced batches 1 and 2.
- In `exportAndShare`, after `_prefetch` returns bytes, call `_decodeImage(bytes)` and pass the `ui.Image?` (instead of `Uint8List?`) into `_capture` and through to `ShareCard`. **In the `_capture` call site, pass `photoUrl: null` whenever `photoImage` is non-null** — this prevents a future regression where `photoImage` decode silently fails and `_Photo` falls through to the `CachedNetworkImage` path inside the offscreen tree, re-enabling the original race the plan is trying to eliminate.
- Update `ShareCard.photoBytes` parameter to `ui.Image? photoImage` (rename consistent with the new shape). Update `_Photo`: when `photoImage != null`, render `RawImage(image: photoImage, fit: BoxFit.cover)`; otherwise fall through to existing `CachedNetworkImage` path (the on-screen, non-export rendering path doesn't have the race because it's inside a normal Material tree that awaits decode via `pumpAndSettle`).
- Keep the existing SnackBar fallback (batch-2 U5). If decode returns null with `hasPhoto && !decoded`, surface "Couldn't load the photo for this share card. Sharing without it." — this message stays correct since the fallback navy panel still renders.

**Technical design:** *(directional; the implementer should treat this as design intent, not implementation specification)*

```
ShareCardExporter.exportAndShare(catch_):
  photoUrl = await _resolvePhotoUrl(catch_)
  bytes = photoUrl == null ? null : await _prefetch(photoUrl)
  decoded = bytes == null ? null : await _decodeImage(bytes)
  if hasPhoto && decoded == null: SnackBar("Couldn't load…")
  pngBytes = await _capture(catch_, photoUrl, decoded)
  // ... existing share path

_capture(catch_, photoUrl, decoded):
  // Build offscreen tree with ShareCard(photoImage: decoded)
  // _Photo renders RawImage(image: decoded) when decoded != null
  // ui.Image is GPU-side already — flushPaint paints it synchronously
```

**Patterns to follow:**
- `lib/features/storytelling/application/share_card_export.dart:98-121` — the existing `_prefetch` shape (try/catch/log pattern) is the model for `_decodeImage`'s error handling.

**Test scenarios:**
- Happy path: `_decodeImage` with a known-good fixture JPEG (`test/fixtures/share-card-photo-jpeg.bin`) returns a non-null `ui.Image` with width and height matching the fixture.
- Edge case (HEIC detection): `_decodeImage` with HEIC magic-byte bytes (`test/fixtures/share-card-photo-heic.bin`) returns null and emits the HEIC-specific `debugPrint` line. This rules out the credible fourth-pass cause where iOS Photos library bytes flow through the prefetch but Flutter's codec can't decode them.
- Edge case (oversized source): `_decodeImage` with a 4096×4096 fixture returns a `ui.Image` with `width == 1080` (downsampled via `targetWidth`).
- Error path: `_decodeImage` with malformed bytes (e.g., `Uint8List.fromList([0, 1, 2])`) returns null without throwing; `debugPrint` is called with a recognizable prefix.
- Error path: `_decodeImage` with empty `Uint8List(0)` returns null without throwing.
- **Integration (load-bearing — the test that validates the actual fix):** synthetic `RenderView` + `PipelineOwner` + `BuildOwner` matching the production capture pipeline; attach a `RawImage` with the known-good fixture `ui.Image`; flush layout/compositing/paint; call `repaint.toImage()`; decode the resulting PNG; assert the center pixel matches the fixture (i.e., is NOT navy). This is the test that proves the rewrite eliminates the race. If this test fails, the diagnosis is wrong and U3 should not ship — falling back to deferring share-card to the v1.1+ server-side render is the correct response.

**Verification:**
- On a real device, sharing a catch with a recently-uploaded photo produces a share card with the photo visible (not the navy panel). Repeat with a catch that has a cached photo (already shown elsewhere in the app) — also produces the photo. Repeat with a catch that has no photo — produces the existing fallback (navy + fish icon), which is correct behavior.

---

- U4. **Version bump + final QA**

**Goal:** Ship 1.0.0+16 with a clean quality gate.

**Requirements:** R4

**Dependencies:** U1, U2, U3

**Files:**
- Modify: `pubspec.yaml` (`version: 1.0.0+15` → `version: 1.0.0+16`)

**Approach:**
- Bump pubspec version. Run `flutter analyze` + `flutter test` from a clean tree; address any issues introduced by U1–U3. The repo's existing tests should remain green; new tests added in U1, U2, U3 should pass.
- Update `MEMORY.md` if any institutional learning emerged worth capturing (e.g., "go_router `context.go` strips back stack — use `pushReplacement` for in-place destination").

**Patterns to follow:**
- `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md` U10 — the version-bump-and-final-QA pattern.

**Test scenarios:**
- Test expectation: none — pure config bump. The verification step is the analyze + test pass.

**Verification:**
- `flutter analyze` reports no issues.
- `flutter test` reports all tests passing (including the new tests from U1, U2, U3).
- `pubspec.yaml` shows `1.0.0+16`.

---

## System-Wide Impact

- **Interaction graph:** U1's navigation fix has narrow blast radius — only the catch-log success path and the catch-detail back affordances. The `pushReplacement` choice doesn't affect any deep-link handlers (push notifications still route via `context.go` from cold launch, which is correct because there's no shell stack to preserve in that flow).
- **Error propagation:** U3's `_decodeImage` error path mirrors the existing `_prefetch` error path — null return + `debugPrint` log + downstream SnackBar fallback. No new error surfaces introduced.
- **State lifecycle risks:** None. All three units are pure client-side; no DB writes, no cache state, no migrations.
- **API surface parity:** `ShareCard`'s constructor changes from `photoBytes: Uint8List?` to `photoImage: ui.Image?`. One internal consumer (`share_card_export.dart`); update both sites in the same commit. No public API.
- **Integration coverage:** U1 has a synthetic-router widget test that exercises the actual go_router behavior (not mocked). U2 has an iPhone-SE-width regression test. U3 has unit-level decode invariant tests; the full offscreen-capture path remains uncovered (acknowledged as a follow-up gap).
- **Unchanged invariants:** No changes to authentication (PR #11 owns that), no changes to RLS, no changes to migrations, no changes to push-notification handlers.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Bug 2 device repro doesn't reveal an obvious unbounded constraint, leaving the root cause murky | Capture screenshot + Flutter Inspector tree; if root cause is non-obvious after one hour of investigation, escalate to ce-debug for adversarial inspection rather than blind-fixing |
| `pushReplacement` on `/celebrate/:id` interacts oddly with the celebration screen's own navigation away from itself (e.g., if celebration auto-routes to detail after 3 seconds via `context.go`, this introduces a different trap) | U1 includes reading `celebration_screen.dart` and applying the same defensive pattern to its own navigation calls |
| `ui.Image` has surprise platform behavior on iOS HEIC photos that doesn't reproduce in tests | Decode helper logs failures via `debugPrint`; SnackBar fallback survives. If TestFlight feedback shows HEIC-specific failures, batch-4 escalates to server-side render |
| Adding `RawImage` regresses the on-screen ShareCard preview (currently `Image.memory` which is correct in a normal MaterialApp tree) | `_Photo` keeps the existing `Image.memory` and `CachedNetworkImage` paths for the non-export case; only the `photoImage: ui.Image?` path is new. The export path is the only consumer of the new path |
| Test fixture PNG bloats the repo | Fixture is one ~10KB low-resolution PNG; commit under `test/fixtures/` (existing convention) |

---

## Documentation / Operational Notes

- Capture two `docs/solutions/` entries on completion (in addition to the four already owed from prior batches):
  - `docs/solutions/2026-05-04-go-router-stack-replacement.md` — `context.go` strips the back stack; use `pushReplacement` for in-place destination swaps where a back affordance is expected.
  - `docs/solutions/2026-05-04-share-card-image-decode.md` — `Image.memory` is async-decode; offscreen `RepaintBoundary.toImage()` paints unloaded image; pre-decode to `ui.Image` + render via `RawImage` to eliminate the race.
- TestFlight QA matrix for the v1.0.0+16 build: walk through U1–U3 verification steps on a real device. Record outcomes in the PR body.
- No Supabase dashboard or environment changes required.

---

## Sources & References

- Origin: this batch was authored from direct user TestFlight feedback during a /ce-plan session on 2026-05-03 (no upstream brainstorm doc).
- Related plans: `docs/plans/2026-05-03-001-fix-fwf-bug-batch-plan.md`, `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md`
- Related code: `lib/core/router/app_router.dart`, `lib/core/router/app_shell.dart`, `lib/features/catches/presentation/catch_log_screen.dart`, `lib/features/catches/presentation/catch_detail_screen.dart`, `lib/features/friends/presentation/friends_screen.dart`, `lib/features/profile/presentation/widgets/avatar_view.dart`, `lib/features/storytelling/presentation/widgets/share_card.dart`, `lib/features/storytelling/application/share_card_export.dart`
- Related institutional context: `docs/solutions/2026-05-01-storytelling-server-detection.md`
- Related PRs: #5 (batch-1 merged), #7 (batch-2 merged), #11 (1.0.0+15 auth implicit flow, in flight)
