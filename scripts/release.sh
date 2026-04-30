#!/usr/bin/env bash
# Bump SemVer in plugin.json + marketplace.json, commit, tag, push.
# Usage: ./scripts/release.sh <patch|minor|major> [--dry-run] [--no-push]

set -euo pipefail

cd "$(dirname "$0")/.."

bump="${1:-}"
dry_run=false
no_push=false
for arg in "${@:2}"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --no-push) no_push=true ;;
    *) echo "unknown flag: $arg" >&2; exit 64 ;;
  esac
done

if [[ ! "$bump" =~ ^(patch|minor|major)$ ]]; then
  echo "usage: $0 <patch|minor|major> [--dry-run] [--no-push]" >&2
  exit 64
fi

if ! command -v jq >/dev/null; then
  echo "error: jq is required" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree dirty — commit or stash first" >&2
  git status --short >&2
  exit 1
fi

current=$(jq -r '.version' .claude-plugin/plugin.json)
if [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: current version '$current' is not SemVer" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<<"$current"
case "$bump" in
  patch) patch=$((patch + 1)) ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
esac
next="$major.$minor.$patch"

echo "  $current → $next"

if $dry_run; then
  echo "(dry-run; no changes written)"
  exit 0
fi

tmp=$(mktemp)
jq --arg v "$next" '.version = $v' .claude-plugin/plugin.json >"$tmp" && mv "$tmp" .claude-plugin/plugin.json
jq --arg v "$next" '.plugins[0].version = $v' .claude-plugin/marketplace.json >"$tmp" && mv "$tmp" .claude-plugin/marketplace.json

git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "release: v$next"
git tag -a "v$next" -m "v$next"

echo "  tagged v$next locally"

if $no_push; then
  echo "  (skipping push due to --no-push)"
  echo "  push manually with: git push origin HEAD --follow-tags"
  exit 0
fi

if git remote get-url origin >/dev/null 2>&1; then
  branch=$(git symbolic-ref --short HEAD)
  git push origin "$branch" --follow-tags
  echo "  pushed $branch and tag v$next to origin"
else
  echo "  no 'origin' remote configured — push manually with:"
  echo "    git remote add origin git@github-destreamed:destreamed/claude-plugin.git"
  echo "    git push -u origin HEAD --follow-tags"
fi
