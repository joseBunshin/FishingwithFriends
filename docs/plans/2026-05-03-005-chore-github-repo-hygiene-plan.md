---
title: "chore: GitHub repo hygiene — prune stale branches + auto-cleanup going forward"
type: refactor
status: active
date: 2026-05-03
---

# chore: GitHub repo hygiene — prune stale branches + auto-cleanup going forward

## Summary

Prune all 21 stale merged branches from the repo (origin + local clones), enable GitHub's auto-delete-on-merge so the problem doesn't recur, and add a small `scripts/clean-branches.sh` + PR template so the dev workflow stays tidy through the next batches of work.

---

## Problem Frame

Fourteen PRs have been merged in the last 36 hours (PRs #1–#14) — onboarding polish, four TestFlight bug batches, four auth-flow fixes, two docs PRs, the M7 release, and the ship-script chore. GitHub does not delete the head branches automatically by default. The result: 21 branches still on `origin` even though every single one has been merged and every commit is already on `main`. Local clones (Mac + Windows) carry the same accumulation. The repo's branch list is hard to scan and it's no longer obvious which branches are real WIP versus dead refs.

The fix is mechanical and low-risk — branch refs can be deleted without touching the underlying commits — but the *interesting* bit is making sure this doesn't accumulate again. One-time pruning without auto-cleanup just delays the same problem.

---

## Requirements

- R1. Every stale (merged) branch is deleted from `origin`. Only `main` and unmerged WIP branches remain.
- R2. Local clones (the orchestrator's Windows clone today, the Mac at next sync) prune stale branches in one command.
- R3. GitHub auto-deletes head branches when a PR is merged, so this state doesn't accumulate again.
- R4. `main` branch protection is verified. If it's missing, the plan surfaces the gap; the user resolves manually before U3 runs (cannot be a soft-deferred warning while destructive cleanup is happening on the same repo).
- R5. A `.github/pull_request_template.md` codifies the PR description shape we've been writing manually (Summary / Test plan / etc.) so future PRs don't drift.

---

## Scope Boundaries

- No git history rewriting. No force-pushes. No commit-level changes — only branch refs are touched, and only branches with merged PRs.
- No rename of `main`, no migration to a different default branch.
- No code changes to the app itself. This batch produces zero impact on `pubspec.yaml`, `lib/`, `test/`, `supabase/migrations/`, or any user-facing surface.
- GitHub Actions auto-build-on-merge — separate scope, offered as a follow-up batch. Not in this plan.
- CONTRIBUTING.md, CODE_OF_CONDUCT.md, GitHub Discussions enablement, issue templates, repo description / topics — all useful but out of scope for a tight cleanup plan. Tracked in Deferred.
- Tags, releases, GitHub Pages config — also out of scope.

### Deferred to Follow-Up Work

- **CONTRIBUTING.md and an issue template** — useful when the project has external contributors, premature for a solo project at v1.0 launch. Revisit if/when contributors join.
- **GitHub Actions auto-build-on-merge to TestFlight** — significant separate scope (macOS runner + Apple credentials in repo secrets + Transporter / altool wiring). The user explicitly named this as its own batch.
- **Repo description, topics, social card** — visibility polish for when the repo goes public. Out of the cleanup scope.
- **Audit `gitignore` entries** — `ios/Podfile.lock` did need to be committed (per the pod-install drift earlier today), but a broader `.gitignore` audit (verify `.dart_tool/`, `build/`, `.flutter-plugins-dependencies` are properly ignored) would be useful follow-up if Mac + Windows clones keep producing tracked-file drift.

---

## Context & Research

### Relevant Code and Patterns

- `scripts/sync-confluence.sh`, `scripts/sync-confluence.ps1`, `scripts/confluence_migrate.py`, `scripts/ship.sh` — existing script directory. New `scripts/clean-branches.sh` joins this set, follows the same shell-script convention as `ship.sh` (Bash, `set -euo pipefail`, color output, fail-loud guards).
- `scripts/ship.sh` — the closest existing script in style. New cleanup script should mirror its structure: env sanity check, dry-run-by-default, explicit confirmation before destructive ops.
- `.github/` — no existing files yet (no PR template, no workflows). The PR template lands at `.github/pull_request_template.md` per GitHub's convention.

### Institutional Learnings

- `docs/plans/2026-05-03-001-fix-fwf-bug-batch-plan.md` through `004-...-batch-4-plan.md` — the four prior bug-batch PRs all used the `fix/testflight-bug-batch-N` naming convention. The PR template can codify this pattern (and the conventional-commit prefix) so future batches don't re-invent the shape.
- `docs/plans/2026-05-03-002-fix-fwf-bug-batch-2-plan.md` and `003-...-batch-3-plan.md` — both noted a backlog of `docs/solutions/` entries that "still aren't written." That documentation backlog is separate from this plan, but the underlying issue (deferred docs accumulating) is the same kind of hygiene problem this plan addresses for branches. Worth noting only because it's a pattern.
- The `chore/ship-script-and-bump-19` push earlier today encountered a Podfile.lock drift the cleanup script needs to be aware of: `git status` checks should not auto-commit anything; the cleanup is strictly destructive on branch refs and never edits files.

### External References

- GitHub docs: "Managing the automatic deletion of branches" — the repo-level setting is at Settings → General → Pull Requests → "Automatically delete head branches." Available via the REST API at `PATCH /repos/{owner}/{repo}` with `{"delete_branch_on_merge": true}` — the `gh api` CLI can drive this without touching the web UI.
- `git push origin --delete <branch>` deletes a remote ref. `git fetch --prune` removes local stale-tracking refs. `git branch -d <branch>` (lowercase) refuses to delete branches not merged into the current HEAD — exactly the safety net we want for the local cleanup.

---

## Key Technical Decisions

- **Order of operations: settings first, then prune.** Enable `delete_branch_on_merge` and verify branch protection BEFORE deleting any branches. If U1's protection check returns 404 (no protection set), U3 does NOT run until the user manually adds protection via Settings → Branches. The bulk delete operates on the assumption that auto-delete will keep the state clean going forward AND that direct pushes to `main` are blocked — both must be real before destructive ops execute.
- **Bulk delete is a script, not a one-liner.** `scripts/clean-branches.sh` lists eligible branches, prints them, requires explicit `--yes` to actually delete. **Eligibility uses TWO complementary checks combined with OR**, because `gh pr list` alone misses ~7 of the 21 stale branches in this repo (M-series feature branches merged before the PR workflow started, plus other pre-PR-workflow merges):
  - **Check A:** branch name appears in `gh pr list --state merged --limit 200 --json headRefName --jq '.[].headRefName'`. This catches merged-PR branches.
  - **Check B:** `git merge-base --is-ancestor origin/<branch> origin/main` exits 0 — i.e., the branch's content is reachable from `main` even when the squash-merge commit isn't. This catches pre-PR-workflow merges AND defends against post-merge force-pushes that introduced new commits not yet on `main`.
  - A branch is eligible IF (Check A passes) OR (Check B passes). Both being false means the branch is genuinely WIP and survives.
  - The merge-base check on origin (`origin/<branch>` ancestor of `origin/main`) is intentionally on remote refs — eliminates local-only divergence as a confounder.
- **Squash-merged branches require `git branch -D` (capital), not `-d`.** The plan originally claimed `-d` "refuses to delete branches not merged into HEAD" as the safety net. That's true but USELESS here — squash-merged branches' tip commits are NOT ancestors of `main` (the squash creates a new commit on `main`), so `-d` would refuse to delete every PR branch we just merged. The eligibility checks above ARE the safety net; once a branch passes them, `-D` is correct because we've independently verified the content is on `main`.
- **The script handles both origin and local in one run, but `--remote` is the recommended first step.** `--remote` deletes from origin only, `--local` deletes locally only, `--all` does both. Default changes to `--remote` (NOT `--all`): origin's deletion is destructive without a server-side reflog (GitHub does not retain a reflog after branch deletion), but local clones retain a reflog of the deleted-from-origin branches via the previous fetch. Running `--remote` first means the local clone is the recovery point if something goes sideways. Run `--local` separately once you've confirmed origin is clean. `--all` exists for the case where you've already confirmed via dry-run and want one motion.
- **gh CLI auth scope must be verified up front.** Both U1's PATCH (mutating repo settings) and U1's protection-status read require `Administration: read and write` on a fine-grained PAT, OR the classic `repo` scope. The script preflights with `gh auth status` + a probe call (`gh api repos/joseBunshin/FishingwithFriends --jq .name`); if either fails, it bails before any destructive op.
- **The protection check returns HTTP 404 with a message body when protection isn't set up.** This is the EXPECTED state on a brand-new repo, not an error. The script must distinguish 404-no-protection from 404-wrong-repo by reading the body's `message` field — the former surfaces the gap and exits 2 (user resolves manually); the latter is a real error and exits 1. Without this handling, `set -euo pipefail` causes the script to crash on the protection check.
- **gh api flag: `-F`, NOT `-f`, for boolean values.** `-f / --raw-field` sends string `"true"`; the GitHub REST API expects JSON `true` and rejects the string. `-F / --field` does magic type coercion (literal `true`, `false`, `null`, integers convert to JSON types). All mutating gh api calls in this batch use `-F`.
- **PR template kept short.** Three sections — Summary, Test plan, Notes. Mirrors what we've been writing manually across PRs #5–#14. Doesn't try to cover every PR shape — small fixes can omit Test plan, refactors can leave Notes blank. The template is a default, not a contract.
- **No git history rewrites.** Branch refs only. The merge commits already on `main` are the source of truth and stay untouched.

---

## Open Questions

### Resolved During Planning

- **What if a stale-on-origin branch was actually unmerged WIP?** Cross-check with `gh pr list --state merged` — only branches mapped to a merged PR get deleted. An unmerged branch with no PR survives.
- **What about the local working tree's currently-checked-out branch?** Script refuses to delete the branch you're standing on. Switches to `main` first (after a `git pull`) so the deletion of the previous branch's ref doesn't trip on "current branch."
- **Does enabling auto-delete-on-merge affect existing branches?** No — only future merges. The one-time cleanup still has to run.

### Deferred to Implementation

- **Whether to run the bulk cleanup with `--remote` and `--local` separately or together** — depends on whether the user wants to inspect remote-pruned state before nuking locals. Default is together; flag exists for granular runs.
- **Whether the cleanup script should also `git remote prune origin`** — yes, but verify against any custom remote names the Mac clone may have. Decide at execution time.

---

## Implementation Units

- U1. **Repo settings: auto-delete-on-merge + branch protection sanity-check**

**Goal:** GitHub auto-deletes head branches on merge going forward; `main` branch protection rules are verified and any gap is surfaced.

**Requirements:** R3, R4

**Dependencies:** None

**Files:**
- No file changes — pure GitHub config via `gh` CLI.

**Approach:**
- **Auth preflight (must come first).** Verify `gh auth status` shows an authenticated context, and probe with `gh api repos/joseBunshin/FishingwithFriends --jq .name` to confirm the auth context has read access to this repo. If either fails, bail with a message naming the required scope (`Administration: read and write` on a fine-grained PAT, or classic `repo` scope) — the PATCH below requires it and silent 403s would leave the user debugging in the dark.
- Enable auto-delete-on-merge: `gh api -X PATCH "repos/joseBunshin/FishingwithFriends" -F delete_branch_on_merge=true`. **Note `-F` (capital), not `-f`** — `-f` sends the string `"true"`, which the GitHub REST API rejects; `-F` does magic type coercion to JSON boolean. Verify with `gh api repos/joseBunshin/FishingwithFriends --jq .delete_branch_on_merge` returning `true`.
- Read current `main` branch protection rules: `gh api "repos/joseBunshin/FishingwithFriends/branches/main/protection" 2>/dev/null`. **A 404 here is the EXPECTED state when protection isn't set up** — not an error. The body of the 404 response contains `{"message":"Branch not protected", ...}`. The script must catch the non-zero exit (under `set -e`), inspect the body, and route accordingly:
  - 404 with `"message":"Branch not protected"` → protection missing, surface the gap as a typed message and **exit 2** (user must add protection before running U3). Do NOT proceed to U2/U3 in the same script run.
  - 404 with any other message → real error (wrong repo / auth issue), exit 1.
  - 200 with a JSON body → protection exists. Verify `required_pull_request_reviews` is present and `enforce_admins.enabled` is `true` so the rule applies to the user as admin too. If either is missing, surface the gap and exit 2 same as 404-no-protection.
- The plan does NOT auto-apply protection rules — branch protection has dependencies (required status check names, reviewer counts) that should be set deliberately by the user, not scripted blindly. The hard exit on missing protection means the user's manual fix happens before the destructive U3 step, satisfying R4's "verified" condition before any branches get deleted.

**Patterns to follow:**
- The repo doesn't have prior `gh api` PATCH calls. Use the syntax shown in GitHub's REST docs verbatim.

**Test scenarios:**
- Test expectation: none — pure config change. Verification is the `gh api ... --jq .delete_branch_on_merge` round-trip showing `true`.

**Verification:**
- `gh api repos/joseBunshin/FishingwithFriends --jq .delete_branch_on_merge` returns `true`.
- `gh api repos/joseBunshin/FishingwithFriends/branches/main/protection` returns a non-error response with at least `required_pull_request_reviews` defined. If it returns a 404, this batch surfaces the gap — the user resolves manually via Settings → Branches.

---

- U2. **`scripts/clean-branches.sh` + `.github/pull_request_template.md`**

**Goal:** A reusable cleanup script for the local + remote branch pruning, plus a PR template that codifies the description shape we've been writing manually.

**Requirements:** R5 (template); supports R1, R2 (script).

**Dependencies:** U1 (specifically: `delete_branch_on_merge` enabled — that's the durable hygiene change. The branch-protection check in U1 is a separate gate that blocks U3 from running if protection is missing, but the script + template artifacts in U2 can land regardless. U2's only hard prerequisite from U1 is that the auto-delete setting is on, so the cleanup isn't deferring the same accumulation).

**Files:**
- Create: `scripts/clean-branches.sh`
- Create: `.github/pull_request_template.md`

**Approach:**

**Script (`scripts/clean-branches.sh`):**
- Bash, `set -euo pipefail`, mirroring `scripts/ship.sh` style. Cross-platform — runs on Mac and Windows (Git Bash); does NOT include `ship.sh`'s Darwin-only guard.
- Default mode: dry-run. Lists eligible branches that exist on origin and/or locally. Requires `--yes` to actually delete.
- **Auth preflight:** `gh auth status` must succeed AND `gh api repos/joseBunshin/FishingwithFriends --jq .name` must return the repo name. If either fails, bail with a typed message naming the required scope.
- **Eligibility (each branch checked independently against BOTH conditions, OR'd):**
  - **Check A — merged-PR head-ref intersection:** branch name appears in `gh pr list --state merged --limit 200 --json headRefName --jq '.[].headRefName'`. Higher `--limit` than the default 30 to cover repos with longer PR histories.
  - **Check B — merge-base ancestry:** `git merge-base --is-ancestor "origin/<branch>" "origin/main"` exits 0 (branch's content is reachable from main). Run this on origin refs (not local) to eliminate local-divergence as a confounder. Necessary because squash-merged branches AND pre-PR-workflow merges fail Check A but pass Check B.
  - Branch is eligible IF (Check A) OR (Check B). Both false → branch is genuinely WIP, survives.
- **Deletion:** use `git branch -D <branch>` (capital, force) for local — `-d` (lowercase) refuses to delete branches whose tip isn't an ancestor of HEAD, which is true for all squash-merged branches even though their content IS on main. The eligibility checks above are the safety net; once a branch passes them, `-D` is the correct tool. For remote: `git push origin --delete <branch>`.
- Exclusions hardcoded: never delete `main`, never delete the currently-checked-out branch (script switches to `main` first via `git checkout main && git pull --ff-only`).
- Flags: `--remote` (origin only — **default**, see Key Technical Decisions on why this changed from `--all`), `--local` (local only), `--all` (both), `--yes` (skip dry-run, actually delete), `--help` (usage).
- Exit codes: 0 on success, 1 on env failure (no `gh`, no git repo, auth missing, dirty tree), 2 on user-aborted dry-run.
- Always-on guards before any destructive op: working tree must be clean (refuse to proceed on uncommitted changes); current branch must be `main` after the switch (refuse if checkout failed); auto-delete-on-merge must be enabled on the repo (probe via `gh api repos/joseBunshin/FishingwithFriends --jq .delete_branch_on_merge` returning `true` — refuse to run the bulk delete otherwise, since that means U1 was skipped).

**PR template (`.github/pull_request_template.md`):**
- Three sections: `## Summary`, `## Test plan`, `## Notes` (optional). Mirrors the PRs we've been writing manually for #5–#14. Each section's body is left empty for the author to fill.
- Includes a comment hint at the top: `<!-- For multi-unit work, summarize each U-N briefly. For single bug fixes, one-paragraph summary is fine. -->`.

**Patterns to follow:**
- `scripts/ship.sh` — script style, color output, fail-loud guards, `set -euo pipefail`.
- The PRs already merged (#5 through #14) — their bodies are the corpus we're codifying. Look at #13 (batch-4) for a full-shape example; #8 (auth case fix) for a minimal example.

**Test scenarios:**
- Happy path (dry-run): run `scripts/clean-branches.sh` with no args on a fresh clone — prints the list of stale branches, exits 0, deletes nothing. Manual verification: `git branch -r` after the run shows the same branches as before.
- Happy path (delete): run with `--yes --remote` — origin's stale branches are gone (`git ls-remote origin` confirms), local untouched.
- Happy path (delete local): run with `--yes --local` — local's stale branches are gone (`git branch` confirms).
- Edge case: run from a non-`main` branch — script switches to `main`, pulls, then proceeds. Verify the original branch is in the deletion list and gets deleted.
- Edge case: run with no merged-PR branches present (clean repo) — script reports "nothing to clean," exits 0.
- Error path: run outside a git repo — script bails with a clear "not in a git repo" message, exit 1.
- Error path: `gh` not installed or not authenticated — script bails with a clear "gh CLI not found / authenticated" message, exit 1.

**Verification:**
- The script prints the list of merged branches when invoked without `--yes`. With `--yes`, the deletions actually happen and `git ls-remote origin` shows only `main` plus any unmerged WIP.
- The PR template renders in the GitHub UI's "Open new PR" form on the next branch push.

---

- U3. **One-time bulk cleanup of the 21 stale branches**

**Goal:** Every currently-stale (merged-PR) branch is deleted from `origin` and the orchestrator's local clone. The repo's branch list shows only `main` plus any genuinely-WIP branches.

**Requirements:** R1, R2

**Dependencies:** U1, U2 (auto-delete on, script + template ready).

**Files:**
- No file changes — destructive operation only on git refs (no commits touched).

**Approach:**

**Pre-step — orchestrator state.** The orchestrator running this plan is currently on the `chore/ship-script-and-bump-19` branch (already merged via PR #14). That branch IS one of the 21 stale targets. Before running the cleanup script, the orchestrator must:
1. Commit + push this plan + the U2 artifacts (`scripts/clean-branches.sh`, `.github/pull_request_template.md`) to a fresh branch (e.g., `chore/repo-hygiene-batch-5`).
2. Open + merge a PR for that branch (which adds it to the merged-PR set, making it self-cleaning under the auto-delete-on-merge setting U1 enabled).
3. Switch back to `main`, pull. Now the orchestrator is on `main`, the cleanup-script artifacts are on `main`, and the working tree is clean.

**Cleanup execution:**
- Run `scripts/clean-branches.sh --remote` (NO `--yes`) to dry-run the origin deletion. Confirm the printed list matches the 21 stale branches identified during planning (14 merged-PR head-refs + 7 ancestor-of-main feature branches).
- If correct, re-run with `--remote --yes`. After this, origin is clean. Verify with `git ls-remote origin | grep refs/heads`.
- Then run `scripts/clean-branches.sh --local` (dry-run again, since local state may have drifted) and `--local --yes` once confirmed.
- After both runs: `git branch -r` shows only `origin/main` plus `origin/HEAD`; `git branch` shows only `main`.
- The orchestrator's Mac clone (separate machine) runs the same script after the next `git pull`. The Mac may surface additional stale branches that don't exist on the Windows clone — same script handles both. Reflog on each local clone retains the deleted branches' tips for the gc reflogExpireUnreachable window (default 30 days for unreachable refs) — that's the ONLY recovery path, since GitHub does not retain a reflog after origin-side deletion.

**Patterns to follow:**
- N/A — this is a one-time execution of the script built in U2.

**Test scenarios:**
- Test expectation: none — invoking the U2 script in its already-tested mode. Verification is post-state observation.

**Verification:**
- `git ls-remote origin | grep -E 'refs/heads/'` shows only `main` and any genuinely-unmerged branches.
- `gh pr list --state merged --json headRefName --jq '.[].headRefName'` returns the same set of names but `git branch -r` no longer contains any of them.
- No commits lost from `main`'s history (sanity-check: `git log --oneline main -5` matches what's on origin/main pre-cleanup).

---

## System-Wide Impact

- **Interaction graph:** None — this batch touches no app code. The only system-level interaction is the GitHub API (settings change + branch deletes).
- **Error propagation:** The cleanup script is the only thing that throws errors; it bails fast and prints actionable messages. No other layers consume the script's output.
- **State lifecycle risks:** Branch deletion is destructive on the ref but not on commits. Every commit on every deleted branch is verified-on-main by the eligibility OR check (Check A merged-PR head-ref OR Check B `git merge-base --is-ancestor origin/<branch> origin/main`). If a branch were accidentally deleted that contained unique commits, those commits would be unreachable on origin (GitHub does NOT retain a reflog post-deletion — the only server-side record is the closed/merged PR's commit references) but recoverable via `git reflog --all` on a local clone that fetched the branch before deletion. The reflog window is `gc.reflogExpireUnreachable` (default 30 days, environment-dependent — Windows automated gc can compact sooner). The script's `--remote`-default-first ordering preserves the local clone as the recovery point. The dry-run gate plus eligibility OR check makes accidental deletion implausible.
- **API surface parity:** N/A.
- **Integration coverage:** Manual verification post-run.
- **Unchanged invariants:** `main`'s history, every merge commit, every tag, every PR record on GitHub, every issue, every release. The cleanup is strictly additive (auto-delete setting) plus subtractive (stale refs gone) — nothing existing changes shape.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Script accidentally deletes an unmerged branch that shares a name with a merged-then-recreated one | Source of truth is `gh pr list --state merged` head-ref names — only branches mapped to an actual merged PR are eligible. A namesake branch with no merged PR isn't in the deletion set. |
| User runs cleanup on a Mac with stale state different from Windows clone | Script is idempotent — re-running on a different machine just deletes that machine's stale local refs. Origin pruning is global so it only takes effect once. |
| Auto-delete-on-merge gets disabled later (intentionally or otherwise) | Easy to detect by re-running the cleanup script and seeing it find a non-empty stale list again. The script is the canary. |
| Branch protection on `main` is weaker than expected, surfaced by U1 verification | Plan does not auto-fix this. User resolves via Settings → Branches → Branch protection rules → Edit the `main` rule. The verification surfacing the gap is the deliberate intent — automated rule changes have too many subtleties (status check names, required-reviewer count) for a hygiene batch to set blindly. |
| Deletion of the current branch the user is standing on locally | Script switches to `main` (after `git pull`) before deleting any local ref. If the switch fails (uncommitted changes), script bails with a clear message before touching anything. The orchestrator's pre-step in U3 (commit plan + artifacts + merge PR + switch to main) ensures the starting state is clean by construction. |
| GitHub side has no reflog after branch deletion — accidentally-deleted-on-origin branches are unrecoverable from GitHub | The script defaults to `--remote` first, NOT `--all`. Running remote-first means the local clone retains a reflog of the recently-fetched branch tips for gc.reflogExpireUnreachable (default 30 days, environment-dependent on Git for Windows). If recovery is ever needed: `git reflog --all` on the local clone, identify the lost commit, `git branch <name> <sha>`, push back to origin. The 30-day window assumes default gc settings — automated gc on Windows clones can compact sooner. |
| `gh` CLI auth context lacks the `Administration: read and write` scope | Script preflights with `gh auth status` AND a probe call to the protection endpoint. If either fails (missing auth or insufficient scope), the script bails with a typed message naming the required scope, before any destructive op. The user can then re-authenticate `gh auth refresh -s repo` (classic) or update the fine-grained PAT, then retry. |
| `gh pr list --state merged` includes a closed-PR-same-name branch that was re-pushed with new unmerged commits | The eligibility OR'd check (Check B: `git merge-base --is-ancestor origin/<branch> origin/main`) is independent of `gh pr list`. If the current branch tip is not an ancestor of `origin/main`, Check B fails; if Check A also relies on a stale name match from a closed PR, the branch survives the merge-base test on the live tip. Both checks must agree (OR semantics) on a per-branch basis — name-only matches on stale closed PRs alone are insufficient unless the live ancestor check also passes. |
| The 7 pre-PR-workflow feature branches (`feat/m0-*` through `feat/m6-*`, `debug/push-registration-diagnostics`) survived because they don't appear in `gh pr list --state merged` | Check B (merge-base ancestry on `origin/main`) catches them. Verified during planning: each of those branches' tips IS reachable from `origin/main` (their work landed via PR #3 "Release v1.0.0" or similar batch merges that didn't preserve individual head-refs in the PR list). |

---

## Documentation / Operational Notes

- The script + PR template are the durable artifacts. After this batch, future PRs use the template by default and accumulated branches are kept in check by GitHub auto-deletion.
- A solutions doc isn't warranted here — the techniques (branch deletion, auto-delete setting, PR template convention) are GitHub-native and well-documented externally. The plan's own Approach sections + the script comments are sufficient.
- After both U2's script and U3's bulk cleanup land, the team has a "clean repo" baseline to grow from for the next round of work (push debug, App Store prep, GitHub Actions auto-build, etc.).

---

## Sources & References

- Origin: this batch was authored from direct user request during a /ce-plan session on 2026-05-03 (no upstream brainstorm doc).
- Related plans: `docs/plans/2026-05-03-001-fix-fwf-bug-batch-plan.md` through `docs/plans/2026-05-03-004-fix-fwf-bug-batch-4-plan.md` (the source of the merged-branch accumulation).
- Related code: `scripts/ship.sh` (style reference), `scripts/sync-confluence.sh` (existing script pattern).
- Related PRs: #1 through #14 (all merged; their head refs are the cleanup target set).
- External docs: GitHub REST API — `PATCH /repos/{owner}/{repo}` for `delete_branch_on_merge`; `GET /repos/{owner}/{repo}/branches/{branch}/protection` for branch-protection inspection.
