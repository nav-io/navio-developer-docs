#!/usr/bin/env bash
# Fetch navio-sdk, run typedoc, copy markdown output into docs/sdk/api/.
#
# Usage:
#     scripts/fetch-sdk-docs.sh [ref]
#
# `ref` — tag or branch in nav-io/navio-sdk. Default: latest tag from GitHub.
set -euo pipefail

REPO="nav-io/navio-sdk"
REF="${1:-}"
WORK="$(mktemp -d)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/sdk/api"

trap 'rm -rf "$WORK"' EXIT

if [[ -z "$REF" ]]; then
    REF="$(gh api "repos/$REPO/releases/latest" --jq '.tag_name' 2>/dev/null || echo '')"
fi
if [[ -z "$REF" ]]; then
    REF="master"
fi

echo "==> Cloning $REPO@$REF into $WORK"
git clone --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$WORK/sdk" \
    || git clone --depth 1 "https://github.com/$REPO.git" "$WORK/sdk"

cd "$WORK/sdk"
echo "==> Installing dependencies"
npm ci --ignore-scripts

echo "==> Generating TypeDoc markdown"
npm run docs

echo "==> Copying into $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R docs/. "$OUT/"

# Keep placeholder for gitignore
touch "$OUT/.gitkeep"

echo "==> Done. Generated $(find "$OUT" -type f -name '*.md' | wc -l) markdown files."
