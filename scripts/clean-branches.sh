#!/usr/bin/env bash
# scripts/clean-branches.sh
#
# Prune merged / ancestor-of-main branches from origin and/or local clone.
#
# Usage:
#   ./scripts/clean-branches.sh                # dry-run, --remote scope
#   ./scripts/clean-branches.sh --yes          # actually delete on origin
#   ./scripts/clean-branches.sh --local        # dry-run, --local scope
#   ./scripts/clean-branches.sh --local --yes  # actually delete locally
#   ./scripts/clean-branches.sh --all --yes    # both, in one motion
#
# Eligibility (each branch is checked against BOTH conditions, OR'd):
#   A. Branch name appears in `gh pr list --state merged` head-refs.
#   B. `git merge-base --is-ancestor origin/<branch> origin/main` exits 0.
#
# A or B passing makes the branch eligible. Branches that fail both
# survive — they're genuinely WIP. Squash-merged branches typically
# pass A but fail B (squash creates a new commit on main). Pre-PR-
# workflow merges typically fail A but pass B.
#
# Local deletion uses `git branch -D` (capital, force) because squash-
# merged branches' tip commits are NOT ancestors of main, so `-d` would
# refuse — the eligibility check above is the safety net.
#
# `--remote` is the default scope so the local clone retains a reflog
# of the deleted branches' tips for recovery (GitHub does NOT retain
# a reflog post-deletion).

set -euo pipefail

# ---------------------------------------------------------------------
# Color setup
# ---------------------------------------------------------------------

if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  RED=$'\033[0;31m'
  RESET=$'\033[0m'
else
  GREEN='' YELLOW='' RED='' RESET=''
fi

say()  { echo "${GREEN}→${RESET} $*"; }
warn() { echo "${YELLOW}!${RESET} $*"; }
die()  { echo "${RED}✗${RESET} $*" >&2; exit 1; }

# ---------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------

SCOPE="remote"   # remote | local | all
DO_DELETE=0
SHOW_HELP=0

for arg in "$@"; do
  case "$arg" in
    --remote) SCOPE="remote" ;;
    --local)  SCOPE="local" ;;
    --all)    SCOPE="all" ;;
    --yes)    DO_DELETE=1 ;;
    --help|-h) SHOW_HELP=1 ;;
    *) warn "Unknown argument: $arg" ;;
  esac
done

if [[ "$SHOW_HELP" == "1" ]]; then
  cat <<'EOF'
Usage: ./scripts/clean-branches.sh [--remote|--local|--all] [--yes] [--help]

  --remote   (default) act on origin only
  --local    act on local clone only
  --all      both origin and local
  --yes      actually delete (without this, dry-run)
  --help     show this help

A branch is eligible for deletion if either:
  (A) its name appears in `gh pr list --state merged` head-refs, OR
  (B) `git merge-base --is-ancestor origin/<branch> origin/main` exits 0.

Pass both --remote and --local? Use --all instead.
EOF
  exit 0
fi

# ---------------------------------------------------------------------
# Environment sanity
# ---------------------------------------------------------------------

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not in a git repo."
command -v gh >/dev/null 2>&1 || die "gh CLI not found in PATH."
gh auth status >/dev/null 2>&1 || die "gh auth status failed — re-authenticate first."

cd "$(git rev-parse --show-toplevel)"

REPO_FULL_NAME="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
say "Repo: $REPO_FULL_NAME"

# Probe write-ish auth path. Read-only token would still pass auth
# status — we need to verify the token has scope for repo settings
# reads (the auto-delete probe below) so destructive ops have the
# privileges they need.
auto_delete_state="$(gh api "repos/$REPO_FULL_NAME" --jq .delete_branch_on_merge 2>/dev/null || echo unknown)"
if [[ "$auto_delete_state" != "true" ]]; then
  die "Repo has delete_branch_on_merge=$auto_delete_state. Enable it first (U1 of the cleanup plan) before running this script — otherwise the cleanup is just deferring the same accumulation."
fi

say "Auto-delete-on-merge confirmed ON."

# ---------------------------------------------------------------------
# Working tree sanity
# ---------------------------------------------------------------------

if [[ -n "$(git status --porcelain)" ]]; then
  echo "${RED}Uncommitted changes:${RESET}"
  git status --short
  die "Working tree is dirty. Commit, stash, or discard before running cleanup."
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "main" ]]; then
  say "Switching to main from '$current_branch' (clean tree, safe to checkout)..."
  git checkout main
  git pull --ff-only origin main
fi

# ---------------------------------------------------------------------
# Build eligible-branch list
# ---------------------------------------------------------------------

say "Refreshing remote refs..."
git fetch --prune origin

# Source A: merged-PR head refs.
say "Reading merged-PR head refs from GitHub..."
mapfile -t merged_pr_refs < <(
  gh pr list --state merged --limit 200 --json headRefName --jq '.[].headRefName' \
    | sort -u
)

# Build the universe of branches we might touch.
mapfile -t origin_branches < <(
  git for-each-ref --format='%(refname:short)' refs/remotes/origin \
    | sed -e 's|^origin/||' \
    | grep -v '^HEAD$' \
    | grep -v '^main$' \
    | sort -u
)

mapfile -t local_branches < <(
  git for-each-ref --format='%(refname:short)' refs/heads \
    | grep -v '^main$' \
    | sort -u
)

# Eligibility check — returns 0 if branch is eligible.
is_eligible() {
  local branch="$1"
  # Check A — merged-PR head-ref name match.
  for ref in "${merged_pr_refs[@]:-}"; do
    if [[ "$ref" == "$branch" ]]; then
      return 0
    fi
  done
  # Check B — origin/<branch> is ancestor of origin/main.
  if git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    if git merge-base --is-ancestor "origin/$branch" "origin/main" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

eligible_origin=()
ineligible_origin=()
for b in "${origin_branches[@]:-}"; do
  [[ -z "$b" ]] && continue
  if is_eligible "$b"; then
    eligible_origin+=("$b")
  else
    ineligible_origin+=("$b")
  fi
done

eligible_local=()
ineligible_local=()
for b in "${local_branches[@]:-}"; do
  [[ -z "$b" ]] && continue
  if is_eligible "$b"; then
    eligible_local+=("$b")
  else
    ineligible_local+=("$b")
  fi
done

# ---------------------------------------------------------------------
# Print plan
# ---------------------------------------------------------------------

echo
say "Scope: ${SCOPE}    Mode: $([[ $DO_DELETE == 1 ]] && echo DELETE || echo dry-run)"

if [[ "$SCOPE" == "remote" || "$SCOPE" == "all" ]]; then
  echo
  echo "${GREEN}Origin — eligible (${#eligible_origin[@]}):${RESET}"
  for b in "${eligible_origin[@]:-}"; do echo "  - $b"; done
  if [[ ${#ineligible_origin[@]} -gt 0 ]]; then
    echo "${YELLOW}Origin — surviving (${#ineligible_origin[@]}):${RESET}"
    for b in "${ineligible_origin[@]:-}"; do echo "  - $b"; done
  fi
fi

if [[ "$SCOPE" == "local" || "$SCOPE" == "all" ]]; then
  echo
  echo "${GREEN}Local — eligible (${#eligible_local[@]}):${RESET}"
  for b in "${eligible_local[@]:-}"; do echo "  - $b"; done
  if [[ ${#ineligible_local[@]} -gt 0 ]]; then
    echo "${YELLOW}Local — surviving (${#ineligible_local[@]}):${RESET}"
    for b in "${ineligible_local[@]:-}"; do echo "  - $b"; done
  fi
fi

if [[ "$DO_DELETE" != "1" ]]; then
  echo
  warn "Dry-run only. Re-run with --yes to actually delete."
  exit 2
fi

# ---------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------

if [[ "$SCOPE" == "remote" || "$SCOPE" == "all" ]]; then
  echo
  say "Deleting eligible origin branches..."
  for b in "${eligible_origin[@]:-}"; do
    [[ -z "$b" ]] && continue
    if git push origin --delete "$b" 2>&1 | tail -1; then
      :
    else
      warn "Failed to delete origin/$b — continuing."
    fi
  done
fi

if [[ "$SCOPE" == "local" || "$SCOPE" == "all" ]]; then
  echo
  say "Deleting eligible local branches..."
  for b in "${eligible_local[@]:-}"; do
    [[ -z "$b" ]] && continue
    # -D (capital) because squash-merged branches' tips are not
    # ancestors of HEAD even though their content is on main. The
    # eligibility check above is the safety net.
    if git branch -D "$b" 2>&1 | tail -1; then
      :
    else
      warn "Failed to delete local $b — continuing."
    fi
  done
fi

echo
say "Cleanup complete. Re-run --remote dry-run to verify origin state."
