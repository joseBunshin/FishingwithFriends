#!/usr/bin/env bash
# scripts/ship.sh
#
# One-shot TestFlight build pipeline for Fishing with Friends.
#
# Run from the Mac. Pulls main, auto-bumps the pubspec build number,
# rebuilds dependencies, produces a signed release IPA, and opens
# Finder so you can drag the IPA into Transporter.
#
# Usage:
#   ./scripts/ship.sh             # pull main, bump build, build IPA
#   ./scripts/ship.sh --no-bump   # use the current pubspec version as-is
#
# The script bails early on every failure mode that bit us in batches
# 1-4: stale main, uncommitted changes, missing tools, version
# collision with an already-uploaded TestFlight build, missing IPA.

set -euo pipefail

# Colors for legibility (skipped when stdout isn't a terminal).
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
# Step 1 — environment sanity. Catch every wrong-machine / missing-tool
# case before we start touching git or the build tree.
# ---------------------------------------------------------------------

[[ "$(uname)" == "Darwin" ]] || die "This script must run on macOS."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not in a git repository."

for tool in git flutter pod xcodebuild; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found in PATH."
done

# Project root (one level up from scripts/).
cd "$(git rev-parse --show-toplevel)"

[[ -f pubspec.yaml ]] || die "No pubspec.yaml at $(pwd) — wrong directory."
[[ -d ios ]]          || die "No ios/ directory — not a Flutter iOS project."

# ---------------------------------------------------------------------
# Step 2 — clean working tree on main.
# Refuse to ship from a dirty tree (would silently include unintended
# changes) or from a feature branch (the IPA must come from main).
# ---------------------------------------------------------------------

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "main" ]]; then
  die "On branch '$current_branch'. Switch to main first: git checkout main"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "${RED}Uncommitted changes:${RESET}"
  git status --short
  die "Working tree is dirty. Commit, stash, or discard before building."
fi

say "On main with a clean tree."

# ---------------------------------------------------------------------
# Step 3 — sync with origin.
# ---------------------------------------------------------------------

say "Pulling latest main..."
git pull --ff-only origin main

# ---------------------------------------------------------------------
# Step 4 — version bump (unless --no-bump).
# Reads the +N suffix from pubspec, increments it, writes it back,
# commits, and pushes. If the push is blocked (branch protection),
# we fall back to a chore branch + PR — the build still proceeds
# from the local bump so you don't lose the build cycle.
# ---------------------------------------------------------------------

NO_BUMP=0
for arg in "$@"; do
  case "$arg" in
    --no-bump) NO_BUMP=1 ;;
    *) warn "Unknown argument: $arg" ;;
  esac
done

current_version="$(grep '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*//')"
marketing="${current_version%+*}"   # 1.0.0
build="${current_version##*+}"      # 19

if [[ "$NO_BUMP" == "1" ]]; then
  new_version="$current_version"
  say "Skipping bump (--no-bump). Version: $new_version"
else
  new_build=$((build + 1))
  new_version="${marketing}+${new_build}"
  say "Bumping pubspec: $current_version → $new_version"
  # Portable sed: write to a temp file, then move.
  tmp="$(mktemp)"
  sed "s|^version:.*|version: ${new_version}|" pubspec.yaml > "$tmp"
  mv "$tmp" pubspec.yaml

  git add pubspec.yaml
  git commit -m "chore: bump version to ${new_version}"
  if git push origin main 2>/dev/null; then
    say "Pushed bump directly to main."
  else
    warn "Direct push to main blocked (branch protection?). Creating PR branch."
    bump_branch="chore/bump-${new_version//+/-}"
    git checkout -b "$bump_branch"
    git push -u origin "$bump_branch"
    git checkout main
    if command -v gh >/dev/null 2>&1; then
      gh pr create --base main --head "$bump_branch" \
        --title "chore: bump version to ${new_version}" \
        --body "Automated bump from scripts/ship.sh." || warn "PR creation failed — open one manually."
    else
      warn "gh CLI not installed. Open a PR for branch $bump_branch manually."
    fi
    warn "Bump landed on local main but is on branch $bump_branch upstream. Merge before the next ship."
  fi
fi

# ---------------------------------------------------------------------
# Step 5 — clean build tree + dependency refresh.
# flutter clean wipes build/ and .dart_tool/. pod install picks up
# any iOS-side dep changes. pub get regenerates pubspec.lock.
# ---------------------------------------------------------------------

say "Cleaning build tree..."
flutter clean

say "Refreshing Flutter dependencies..."
flutter pub get

say "Refreshing CocoaPods..."
( cd ios && pod install )

# ---------------------------------------------------------------------
# Step 6 — quality gate. analyze + test must pass before building.
# Catches type errors, lint failures, and broken tests before we
# spend 10 minutes on a release build.
# ---------------------------------------------------------------------

say "Running flutter analyze..."
flutter analyze

say "Running flutter test..."
flutter test

# ---------------------------------------------------------------------
# Step 7 — release build.
# `flutter build ipa --release` produces a signed IPA in
# build/ios/ipa/ using the project's bundled signing config.
# ---------------------------------------------------------------------

say "Building release IPA (this takes 5-10 minutes)..."
flutter build ipa --release

# ---------------------------------------------------------------------
# Step 8 — verify and reveal.
# ---------------------------------------------------------------------

ipa_dir="build/ios/ipa"
ipa_count="$(find "$ipa_dir" -maxdepth 1 -name '*.ipa' 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$ipa_count" -gt 0 ]] || die "Build completed but no IPA found in $ipa_dir/"

ipa_path="$(find "$ipa_dir" -maxdepth 1 -name '*.ipa' | head -1)"
ipa_size="$(du -h "$ipa_path" | cut -f1)"

echo
echo "${GREEN}✓ Build complete.${RESET}"
echo "  Version: ${new_version}"
echo "  IPA:     ${ipa_path} (${ipa_size})"
echo
say "Opening Finder. Drag the IPA into Transporter to upload to App Store Connect."
open "$ipa_dir"
