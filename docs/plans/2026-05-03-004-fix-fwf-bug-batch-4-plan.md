---
title: "fix: TestFlight bug batch 4 — streak polish, home notifications, swipe-delete persistence"
type: fix
status: active
date: 2026-05-03
---

# fix: TestFlight bug batch 4 — streak polish, home notifications, swipe-delete persistence

## Summary

Three TestFlight bugs from 1.0.0+16 shipped together as v1.0.0+17. The Me-screen streak chip's subtitle renders as small black text on a navy hero strip (low contrast, ugly) and the primary label doesn't make clear what the streak tracks. The Home screen has no notifications affordance — users have to navigate to Me → Notifications to check unread. Notification swipe-to-delete (batch-2 U6) is broken: the row animates away locally but reappears on refresh because the Supabase `.delete()` is silently denied by RLS and the client doesn't detect the zero-rows-affected response.

---

## Problem Frame

This is the fourth TestFlight feedback batch. After 1.0.0+16 shipped:

- **Bug 1 (medium — UX clarity + visual polish):** "I see there is a streak counter in my Me section. What does that track? Logins? Or how many days in a row I've logged a fish? Also underneath that it says 'longest 1d'. That is really small and black. That needs to be reworked and made more visually pleasing." The streak provider tracks days-with-a-logged-catch (not logins, not app-opens) — but the on-screen label doesn't say so. The "longest" subtitle uses `bodySmall` (12pt) at the default `onSurface` (near-black) color, placed on a navy hero strip — low contrast, reads as muted dirt on dark navy.
- **Bug 2 (medium — adoption):** "Can we add a notifications button/counter to the home screen?" Notifications currently live one nav tap away (Me → Notifications). The unread count exists (`unreadNotificationCountProvider`) but is only surfaced in the Me screen's account list, not on Home. Per M2/M3/M6 origin notes, the bell affordance was deferred batch-after-batch; this batch lands it.
- **Bug 3 (high — data-loss appearance):** "Notifications go away when you swipe. But [they] don't actually delete and visually come back." Swipe animates the dismissal (Dismissible widget removes locally), but the next refresh re-fetches the row and re-renders it. Root cause: `notifications_repository.delete()` calls `_client.from('notifications').delete().eq('id', id)` without `.select()`. When RLS silently denies (zero affected rows, no exception), the client treats it as success. This is the third instance of the "silent failure swallowed by abstraction" anti-pattern across batches — batch-1 had it with `NetworkAssetBundle`, batch-2 had it with `_resolvePhotoUrl` returning null, this is the RLS variant.

---

## Requirements

- R1. The streak chip on the Me screen makes its tracked metric unambiguous (days-with-a-logged-catch) and renders with a visual treatment that fits the navy hero strip (no small black text on dark navy).
- R2. The Home screen surfaces a notifications affordance with an unread-count indicator that taps through to the existing `/me/notifications` screen.
- R3. Notification swipe-to-delete actually persists on the server, or surfaces a visible error and restores the row in the UI when it doesn't.
- R4. v1.0.0+17 ships with `flutter analyze` clean and `flutter test` green.

---

## Scope Boundaries

- Push-notification APNs token = NULL debugging — **deferred to a future batch** until USB cable available for Console.app device logs.
- Streak product redesign (PR-tier rewards, multi-day milestones, streak-loss notifications) — out of scope; this batch is visual polish + label clarity only.
- Notifications screen restructuring (filtering, pagination, kind icons) — out of scope; only the Home affordance is added.
- Establishing a project-wide `.select()`-after-delete convention across every Supabase delete site — too broad for this batch; only the notifications path is touched. Cataloged as a follow-up entry.

### Deferred to Follow-Up Work

- **Audit the remaining `lib/**/*.delete()` call sites.** This batch's U3 covers notifications + catches + tournaments. The remaining three — `reactions_repository.dart`, `friends_data_source.dart`, `device_tokens_repository.dart` — are lower-impact and deferred to batch-5 along with the broader convention work.
- **Capture `docs/solutions/2026-05-03-rls-silent-delete.md`** documenting the migration-0027 pattern + the `.select()`-after-delete detection idiom + the `pg_policies` verification query. Joins the existing solutions backlog (batch-1, batch-2, batch-3 each owed entries that haven't been written).
- **Streak streak-loss UX** (soft-reset messaging, "rest day" copy when the streak is broken) — origin spec calls streaks "soft (resets gracefully)" but the resetting messaging hasn't been designed.

---

## Context & Research

### Relevant Code and Patterns

- `lib/features/me/presentation/me_screen.dart` — renders `StreakChip` inside the navy hero strip after homeWater + bio. Also contains `_NotificationsTrailing` (around line 233), which is the existing orange-pill unread-count pattern to mirror for Bug 2.
- `lib/features/storytelling/presentation/widgets/streak_chip.dart` — the chip widget. Currently a `Column[_Pill, Text('longest ${longest}d', style: bodySmall)]`. The subtitle is the source of Bug 1's "small and black" complaint.
- `lib/features/storytelling/application/streak_provider.dart` — derives `current` and `longest` from distinct local-day fishing dates on `myCatchesProvider`. Confirms streak tracks days-with-a-logged-catch.
- `lib/features/home/presentation/home_screen.dart` — owns its own `AppBar(title: 'Home', actions: [SyncPill()])`. Bug 2's bell goes here, before `SyncPill`.
- `lib/features/notifications/data/notifications_repository_provider.dart` — `unreadNotificationCountProvider` is a synchronous `Provider<int>` derived from `myNotificationsProvider`. Reuse on Home for Bug 2.
- `lib/features/notifications/data/notifications_repository.dart` — the `delete(String id)` method. Bug 3's source. No `.select()` chain; no row-count check.
- `lib/features/notifications/presentation/notifications_screen.dart` — the Dismissible swipe handler. `onDismissed` calls `repo.delete(id)` and invalidates `myNotificationsProvider`. Catches `AppException` only.
- `supabase/migrations/0027_notifications_delete_own.sql` — the RLS policy that should grant the delete. Already in main; verification step in U3 confirms it's live in the user's Supabase.
- `lib/features/tournaments/data/tournaments_data_source.dart` (around line 106) — `await _client.from('tournament_members').insert(rows).select();` is the closest existing pattern for `.select()`-after-mutation. Mirror the style for the new `delete().select()`.
- `lib/features/home/presentation/widgets/stat_tile.dart` — the navy/orange "kicker + value" stat treatment. Reference for Bug 1's visual rework if the subtitle becomes a small uppercase kicker.
- `lib/core/widgets/section_label.dart` — orange-bar + uppercase letterSpaced label. Another reference for the kicker treatment.
- `lib/core/theme/app_colors.dart` — `AppColors.mist` is the off-white mist color used for muted text on navy.

### Institutional Learnings

- `docs/plans/2026-05-01-006-feat-m5-storytelling-plan.md` — M5 R6 + Key Decision codify "streak computed client-side from `catches.caught_at`, never stored." Origin requirements (`docs/brainstorms/fishing-with-friends-v1-requirements.md` line 88) call streaks "soft (resets gracefully)" — design intent is forgiving, not punitive.
- `docs/plans/2026-05-01-003-feat-m2-trips-and-feed-plan.md` + `docs/plans/2026-05-01-004-feat-m3-tournaments-plan.md` — both deferred the bell/unread-count UI from M2 → M3 → M6. M6 wired push delivery + preferences but never specified a Home AppBar bell. This batch is the long-overdue UI surface.
- `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md` — batch-2 U6 introduced the swipe-to-delete + migration 0027. Did not chain `.select()` and did not verify zero-rows-affected. This batch's U3 is patching that blind spot.
- Three batches in a row have shipped a "silent failure swallowed by abstraction" bug: batch-1 with `NetworkAssetBundle` (prefetch errors silent), batch-2 with `_resolvePhotoUrl` (caught exception → null), this batch's RLS-denied delete. The emerging convention is "make failure modes loud" — add `debugPrint`, surface user-visible errors, never let an absent-result look like success. Documenting this convention as a `docs/solutions/` entry is overdue.

### External References

None gathered. The codebase has clear local patterns for every change in this batch.

---

## Key Technical Decisions

- **Bug 1 fix shape: clarify primary label + restyle subtitle, no chip rebuild.** Change the primary label from `"{N}-day streak"` to `"{N}-day fishing streak"` so the tracked metric is unambiguous. Restyle the subtitle from `bodySmall onSurface` (default near-black) to a small uppercase kicker treatment in `AppColors.mist` (matching the rest of the navy hero strip's muted-text style). Keep the existing `_Pill` shape (orange flame + navy rounded rect with white label) — that part already works visually.
- **Bug 1: don't add a tooltip.** The clarified primary label is sufficient; a tap-to-explain tooltip adds complexity for marginal value and the tracked-metric question only really comes up once.
- **Bug 2 fix shape: bell + orange dot in Home AppBar.** Add `IconButton(icon: Icons.notifications_outlined, onPressed: () => context.push('/me/notifications'))` to `home_screen.dart`'s AppBar `actions`, **before** the existing `SyncPill`. Overlay an orange dot indicator (no count number) when `unread > 0`. Rationale: the count badge in `me_screen.dart:233-264` is a list-row treatment with horizontal space; on a compact AppBar a dot indicator is more legible. The Notifications screen itself shows the count.
- **Bug 2 navigation: `context.push`, not `go`.** Mirrors `me_screen.dart:202` and the existing notifications-related navigation. `/me/notifications` is a top-level `GoRoute` outside the shell, so `push` keeps a back stack the user can return from.
- **Bug 3 fix shape: `.select('id')` chain on the delete + visible error.** Modify `notifications_repository.delete(id)` to chain `.select('id')` (NOT bare `.select()`) so PostgREST returns just the id of the deleted row(s) — sufficient for the empty-list check, and avoids returning the full notification payload over the wire on every successful delete. Treat empty list as RLS denial → throw `NetworkFailure("Couldn't delete that notification. Try again.")`. The Dismissible's existing `onDismissed` `try/catch` already invalidates `myNotificationsProvider` on `AppException` (which causes the swiped row to reappear) and shows a SnackBar — the new throw lights up that path.
- **Bug 3: no new SQL migration.** Migration 0027 already exists and was applied per the user's earlier confirmation. The verification step in U3 has the user re-confirm the policy is live (`pg_policies` query) before declaring the fix shipped — if 0027 isn't actually applied, the `.select('id')` change still surfaces the symptom instead of hiding it.
- **Bug 3 scope expansion: bring `markRead`, `markAllRead`, `catches.delete`, and `tournaments.delete` into this batch.** Same `.select('id')`-on-mutation pattern. Reasoning: (a) the new Home bell (U2) makes a silent-`markRead`-failure user-visible as an orange dot that never clears — high-confusion failure if it ever happens; (b) `catches.delete` and `tournaments.delete` touch higher-value data than notifications and a silent no-op there is a worse UX than the notification bug itself; (c) marginal cost — single-line change per site, single-test pair per site. The remaining three delete sites (`reactions`, `friendships`, `device_tokens`) are still deferred to a follow-up — lower-impact and would push U3 over budget.
- **No new SQL migrations.** This batch is pure client-side. Migrations 0027 + 0028 from batch-2 remain in effect.
- **Version bump:** 1.0.0+16 → 1.0.0+17.

---

## Open Questions

### Resolved During Planning

- **What does the streak track?** Days-with-a-logged-catch. Verified via `streak_provider.dart` reading `myCatchesProvider`'s `caught_at` distinct local dates. Not logins, not trips, not sessions.
- **Where does the Home bell affordance go — AppBar or somewhere else?** AppBar actions slot before `SyncPill`. `home_screen.dart` already owns its AppBar; the AppShell does not.
- **Should the unread badge show a count or a dot?** Dot on the AppBar (compact). The count is shown on the Notifications screen and on the Me account-list row.
- **Is migration 0027 already on main?** Yes — confirmed by file listing. Applied to the user's Supabase project per their earlier confirmation. Verification step in U3 keeps it visible.

### Deferred to Implementation

- **Exact font size / weight / letter-spacing on the new "longest" subtitle.** The Approach in U1 names the visual style direction (small uppercase kicker, mist color) but the precise typography numbers belong in execution alongside the device repro.
- **Whether to use Material 3's `Badge` widget or a manual `Stack`-overlaid orange dot for the Home bell.** Codebase has no `Badge` precedent — but if Material 3's API is cleaner, prefer it. Decide at execution time after a quick prototype.
- **Whether to log a structured analytics event when delete fails.** Out of scope for this batch but worth noting if telemetry infrastructure lands later.

---

## Implementation Units

- U1. **Streak chip clarity + visual polish**

**Goal:** The Me-screen streak chip's primary label clarifies the tracked metric; the "longest" subtitle renders with a visual treatment that fits the navy hero strip.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Modify: `lib/features/storytelling/presentation/widgets/streak_chip.dart`
- Test: `test/features/storytelling/streak_chip_test.dart` (extend existing if present, else new)

**Approach:**
- Update the primary label from `"{N}-day streak"` to `"{N}-day fishing streak"`. The flame icon already conveys "streak"; the "fishing" qualifier disambiguates from logins / trips / app-opens. Singular form when current == 1 ("1-day fishing streak").
- Restyle the longest subtitle from `Text('longest ${longest}d', style: bodySmall)` to a small uppercase kicker. **Locked typography:** fontSize 11, fontWeight w800, letterSpacing 1.2, color `AppColors.mist`. **Locked format:** `"LONGEST · {N} {DAY|DAYS}"` (singular when longest == 1). This format is more legible than the abbreviated "3D" form, matches the kicker style used by `SectionLabel`, and avoids an exec-time tuning cycle.
- Keep the existing `_Pill` shape (orange flame in a navy rounded rect with white label). Don't rebuild the chip; this is a typography + copy fix, not a structural rework.
- Verify the chip still renders `SizedBox.shrink()` when `current == 0 && longest == 0` (empty state hides the chip — preserved from current behavior).

**Patterns to follow:**
- `lib/core/widgets/section_label.dart` — uppercase letterSpaced label treatment.
- `lib/features/me/presentation/me_screen.dart` — handle/bio render with `AppColors.mist` on navy. Same color family for the new subtitle.

**Test scenarios:**
- Happy path: pump `StreakChip` with `Streak(current: 3, longest: 5)` and assert the rendered text contains "3-day fishing streak" and "LONGEST · 5 DAYS".
- Edge case: pump with `Streak(current: 0, longest: 0)` — assert the widget renders nothing visible (`SizedBox.shrink()` — both `find.text(...)` and `find.byIcon(Icons.local_fire_department)` find zero matches).
- Edge case: pump with `Streak(current: 1, longest: 1)` — assert "1-day fishing streak" + "LONGEST · 1 DAY" (singular grammar applied to both).
- Edge case: pump with `Streak(current: 5, longest: 0)` — primary label renders, subtitle does not (the existing chip hides the subtitle when `longest <= 0`; `Streak.longest` is a non-nullable `int`, so `longest: null` is invalid — `longest: 0` is the correct way to exercise the subtitle-hidden branch).

**Verification:**
- On a real or simulated device with at least one logged catch, the Me hero strip shows a navy chip with an orange flame and "{N}-day fishing streak" — and a small mist-colored uppercase subtitle for the longest-streak value. No black-on-navy text.

---

- U2. **Home AppBar notifications affordance**

**Goal:** A bell icon with an unread indicator on the Home screen AppBar that taps through to `/me/notifications`.

**Requirements:** R2

**Dependencies:** None

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Test: `test/features/home/home_screen_test.dart` (extend existing — has a `_wrap` harness)

**Approach:**
- Add an `IconButton` to `HomeScreen`'s AppBar `actions`, positioned before the existing `SyncPill`. Icon: `Icons.notifications_outlined`. `onPressed`: `() => context.push('/me/notifications')`.
- Overlay an orange dot **only when `unread > 0`**. Read the count via `ref.watch(unreadNotificationCountProvider)`. The provider is a synchronous `Provider<int>` that returns 0 when the underlying `myNotificationsProvider` is in loading or error state — so loading and error implicitly map to "no dot" with no special UI handling. The dot only appears once the provider has confirmed AsyncData with a non-zero count.
- Implementation choice (deferred): Material 3's `Badge` widget OR a manual `Stack` with a `Positioned` `Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.orange, shape: BoxShape.circle))`. Prototype both at exec time; pick whichever renders cleanly at iPhone SE width.
- Tooltip: `'Notifications'` (or include the unread count, e.g., `unread > 0 ? 'Notifications ($unread unread)' : 'Notifications'`).
- Verify the existing `SyncPill` action still renders correctly after the bell is added.

**Patterns to follow:**
- `lib/features/notifications/presentation/notifications_screen.dart` — AppBar actions composition with `tooltip` + `onPressed: context.push(...)`.
- `lib/features/me/presentation/me_screen.dart` (`_NotificationsTrailing` around line 233) — the orange-pill unread treatment, even though we're using a dot here.

**Test scenarios:**
- **Test harness extension prerequisite:** the existing `_wrap` GoRouter in `test/features/home/home_screen_test.dart:19-36` registers `/home`, `/log`, `/catches`, `/friends` only — no `/me/notifications` route. Extend `_wrap` to include a stub `GoRoute(path: '/me/notifications', builder: (_, __) => const Scaffold(body: Text('notifications screen')))` before writing the integration scenario below; without it, the bell tap throws "no route matched."
- Happy path (no unread): pump HomeScreen via the extended `_wrap` harness with `unreadNotificationCountProvider.overrideWithValue(0)` — assert `find.byIcon(Icons.notifications_outlined)` exists and no orange dot is visible (find a Container with the orange dot decoration; the locator depends on the Badge-vs-Stack implementation choice — capture the locator after the prototype lands).
- Happy path (unread): pump with `unreadNotificationCountProvider.overrideWithValue(3)` — assert the bell renders AND the orange dot is visible.
- Integration: tap the bell — assert the new location is `/me/notifications`. Mirror the existing "Find Anglers CTA navigates to /friends" test pattern at `home_screen_test.dart:94-105`.

**Verification:**
- On a real device, opening the app to Home shows a bell icon in the top-right (left of the sync indicator). With 0 unread, no badge. With ≥1 unread, an orange dot. Tap → notifications screen opens with a back affordance.

---

- U3. **Notification swipe-delete actually persists (+ adjacent silent-RLS hygiene)**

**Goal:** Swiping a notification away actually deletes the row server-side. If the delete is denied (RLS / network / migration not applied), the user sees a SnackBar and the row reappears in the UI. Same `.select('id')` hygiene applied to a small set of adjacent mutations to prevent the next "still silently failing" report.

**Requirements:** R3

**Dependencies:** None

**Files:**
- Modify: `lib/features/notifications/data/notifications_repository.dart` (`delete`, `markRead`, and `markAllRead` methods)
- Modify: `lib/features/catches/data/catches_data_source.dart` (the catches `.delete()` call site)
- Modify: `lib/features/tournaments/data/tournaments_data_source.dart` (the tournaments `.delete()` call site)
- Test: `test/features/notifications/data/notifications_repository_test.dart` (new file — repository currently uncovered)

**Approach:**

**Primary fix — notification delete (the user-reported bug):**
- Chain `.select('id')` (NOT bare `.select()`) after `.delete().eq('id', id)`. The single id column is sufficient to detect the empty-list / RLS-denial case AND avoids returning the full notification row (including the `payload` jsonb with deeplinks, friend ids, etc.) over the wire on every successful delete. Mirror this scoped-column pattern across all three sites in this unit.
- Treat empty list as a permission failure: throw `NetworkFailure("Couldn't delete that notification. Try again.")` — locked copy, no Retry CTA (matches the existing SnackBar-only pattern in the app, where retry is "swipe again").
- The existing `onDismissed` handler in `notifications_screen.dart` already catches `AppException` and shows a SnackBar + invalidates `myNotificationsProvider` (which re-fetches and re-renders the row). The new throw routes through that path naturally; no UI changes needed.
- Add a `debugPrint` in the empty-rows branch with a recognizable prefix (e.g., `'notifications-delete: zero rows affected for id=$id; RLS denial or stale session'`) so the next time this fails in TestFlight there's a clear signal in the logs.

**Adjacent silent-RLS hygiene (in-batch, scoped tightly):**
- **`markRead` and `markAllRead`** — apply the same `.select('id')` pattern to both update mutations. The new Home AppBar bell (U2) shows an orange dot when `unread > 0`; if `notifications_update_own` regresses or the auth context goes stale, the dot would stay lit forever with no error surfaced and the user would assume the app is broken. Same `.select('id')` chain detects the silent failure and makes it loud (SnackBar + `debugPrint`).
- **`catches.delete()`** at `lib/features/catches/data/catches_data_source.dart` — apply the same `.select('id')` pattern. Higher-value than notifications: if the delete silently no-ops, the user thinks they removed a catch but it's still on their feed. Single-line change at the data source level, mirrors the pattern.
- **`tournaments.delete()`** at `lib/features/tournaments/data/tournaments_data_source.dart` — apply the same `.select('id')` pattern. Same reasoning — a "deleted" tournament that's still live is a worse UX than a notification that won't dismiss.
- The other three sites (`reactions_repository.dart`, `friends_data_source.dart`, `device_tokens_repository.dart`) are deferred to a follow-up batch — lower-impact and the scope expansion would push U3 over budget.

**Pre-flight verification:**
- Before declaring U3 done, run `select policyname from pg_policies where tablename = 'notifications';` in Supabase SQL Editor against the production project. Confirm `notifications_delete_own` is present. If absent, re-apply migration 0027.
- Same query for `catches` (look for `catches_delete_own` or equivalent owner-scoped policy from `0001_init.sql`) and `tournaments` (look for `tournaments_delete_creator` or equivalent). If any are missing or have a different predicate than expected, the `.select('id')` change still surfaces the symptom — the user just sees a SnackBar instead of a silent-success illusion.

**Patterns to follow:**
- `lib/features/tournaments/data/tournaments_data_source.dart` (around line 106) — `await _client.from('tournament_members').insert(rows).select();` is the existing `.select()`-after-mutation style. Match the formatting.
- `supabase/migrations/0027_notifications_delete_own.sql` — the policy template.

**Test scenarios:**

*Notification delete:*
- Happy path: stub the Supabase client so `.from('notifications').delete().eq('id', x).select('id')` returns a non-empty list. Call `repo.delete(x)`. Assert no exception is thrown.
- Error path (RLS denial silent): stub the response to return an empty list. Call `repo.delete(x)`. Assert it throws `NetworkFailure` with the locked copy "Couldn't delete that notification. Try again." AND emits a `debugPrint` containing `'notifications-delete'`.
- Error path (PostgrestException): stub the client to throw `PostgrestException`. Assert the existing `NetworkFailure` wrapper still fires (preserving prior behavior).

*Notification mark-read mutations (parallel coverage so an RLS regression on update doesn't silently ship):*
- Happy path: `markRead` returns non-empty list → no exception.
- Error path (RLS denial silent): `markRead` returns empty list → throws `NetworkFailure` + emits a `debugPrint` containing `'notifications-mark-read'`.
- Same shape for `markAllRead` (happy + silent-denial).

*Catches and tournaments delete (defensive — exercises the hygiene fix without depending on a known bug):*
- Happy path each: `.delete().eq('id', x).select('id')` returns non-empty → no exception.
- Error path each (silent denial): empty list → throws `NetworkFailure` with a clearly-different `debugPrint` prefix per site (`'catches-delete'`, `'tournaments-delete'`) so log lines are searchable.

**Verification:**
- On a real device with migration 0027 applied: swipe to delete → row stays gone after pull-to-refresh, after killing+relaunching the app, and after viewing the notification on a second device.
- On a simulated denial (e.g., temporarily revoke 0027 in a dev project): swipe → SnackBar fires + row reappears + `debugPrint` log line is visible. Restore 0027 after verification.

---

- U4. **Version bump + final QA**

**Goal:** Ship 1.0.0+17 with a clean quality gate.

**Requirements:** R4

**Dependencies:** U1, U2, U3

**Files:**
- Modify: `pubspec.yaml` (`version: 1.0.0+16` → `version: 1.0.0+17`)

**Approach:**
- Bump pubspec version. Run `flutter analyze` + `flutter test` from a clean tree; address any issues introduced by U1–U3. The repo's existing 269 tests should remain green; new tests added in U1, U2, U3 should pass.

**Patterns to follow:**
- `docs/plans/2026-05-03-003-fix-fwf-bug-batch-3-plan.md` U4 — the version-bump-and-final-QA pattern.

**Test scenarios:**
- Test expectation: none — pure config bump. Verification is the analyze + test pass.

**Verification:**
- `flutter analyze` reports no issues.
- `flutter test` reports all tests passing (including new tests from U1, U2, U3).
- `pubspec.yaml` shows `1.0.0+17`.

---

## System-Wide Impact

- **Interaction graph:** U2 adds a new entry point from `/home` to `/me/notifications` (existing route, no new screen). U3 modifies one Supabase delete call site; the Dismissible's existing error path picks up the new throw. U1 has zero interaction-graph effect — pure presentation.
- **Error propagation:** U3's new throw flows through the existing `AppException` catch in `notifications_screen.dart`'s `onDismissed`, which already shows a SnackBar + invalidates the provider. No new error surfaces introduced.
- **State lifecycle risks:** None. All three units are client-side; no DB writes, no cache state changes, no migrations.
- **API surface parity:** U3 changes the shape of `notifications_repository.delete` from "always-succeed-or-throw on PostgrestException" to "throw on RLS denial too." Single internal consumer (`notifications_screen.dart`) — already handles thrown `AppException`s. No public API.
- **Integration coverage:** U2 has a synthetic-router widget test exercising the actual go_router push behavior. U3 has unit tests for both success and silent-denial paths via stubbed Supabase responses.
- **Unchanged invariants:** No changes to authentication, RLS migrations (no new SQL), push-notification handlers, or the notifications screen body itself (only the repository it calls).

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Migration 0027 was rolled back or never applied — bug 3 fix surfaces the symptom but the underlying RLS denial is "real" | The `.select()` change makes the failure visible (SnackBar + log line). U3's verification step explicitly has the user query `pg_policies` to confirm 0027 is live before declaring shipped |
| Material 3 `Badge` widget renders inconsistently on iPhone SE vs Pro Max | Manual `Stack` + `Positioned` orange dot is a fallback path that has zero device-class variance. Prototype both in U2; commit whichever renders cleanly at 320pt and 414pt |
| New "fishing streak" copy clashes with future product framing (e.g., if the team later adds streaks for other actions) | Streak product redesign is explicitly Out of Scope. If the model later changes, the copy is one string in `streak_chip.dart` to update |
| User has stale Supabase schema cache and 0027's `notify pgrst, 'reload schema'` didn't reach their session | Verification step at exec time queries `pg_policies` directly. If the policy is present in `pg_policies` but PostgREST still denies, the user can force-cycle by issuing a small unrelated DDL or by restarting their Supabase project |

---

## Documentation / Operational Notes

- Capture two `docs/solutions/` entries on completion (joining the four-entry backlog from prior batches):
  - `docs/solutions/2026-05-03-rls-silent-delete.md` — why `.delete()` silently no-ops under RLS, the `for delete to authenticated using (...)` template + `notify pgrst`, the `.select()`-after-delete detection idiom, the `pg_policies` verification query.
  - `docs/solutions/2026-05-04-make-failure-modes-loud.md` — the cross-cutting convention extracted from three batches of "silent failure swallowed by abstraction" bugs (NetworkAssetBundle → http.get, signed-URL null-on-throw → debugPrint + SnackBar, RLS-denied delete → `.select()` chain). Promotes the per-bug fixes into a project-wide convention.
- TestFlight QA matrix for v1.0.0+17: walk U1–U3 verification on a real device. Record outcomes in the PR body.
- No Supabase dashboard changes required.

---

## Sources & References

- Origin: this batch was authored from direct user TestFlight feedback during a /ce-plan session on 2026-05-03 (no upstream brainstorm doc).
- Related plans: `docs/plans/2026-05-01-006-feat-m5-storytelling-plan.md` (M5 streak spec), `docs/plans/2026-05-01-003-feat-m2-trips-and-feed-plan.md` + `docs/plans/2026-05-01-004-feat-m3-tournaments-plan.md` (bell-affordance deferral history), `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md` (U6 introduced the swipe-delete bug 3 patches), `docs/plans/2026-05-03-003-fix-fwf-bug-batch-3-plan.md` (most recent batch's plan structure).
- Related code: `lib/features/storytelling/presentation/widgets/streak_chip.dart`, `lib/features/storytelling/application/streak_provider.dart`, `lib/features/me/presentation/me_screen.dart`, `lib/features/home/presentation/home_screen.dart`, `lib/features/notifications/data/notifications_repository.dart`, `lib/features/notifications/presentation/notifications_screen.dart`, `lib/features/tournaments/data/tournaments_data_source.dart` (for the `.select()` pattern reference), `supabase/migrations/0027_notifications_delete_own.sql`.
- Related PRs: #12 (batch-3 merged), #11 (auth implicit flow merged).
