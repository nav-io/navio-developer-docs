#!/usr/bin/env bash
# Fetch libblsct-bindings TS binding, run typedoc, copy markdown output into docs/blsct-lib/api/.
#
# Usage:
#     scripts/fetch-blsct-docs.sh [ref]
set -euo pipefail

REPO="nav-io/libblsct-bindings"
REF="${1:-}"
WORK="$(mktemp -d)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/blsct-lib/api"

trap 'rm -rf "$WORK"' EXIT

if [[ -z "$REF" ]]; then
    REF="$(gh api "repos/$REPO/releases/latest" --jq '.tag_name' 2>/dev/null || echo '')"
fi
if [[ -z "$REF" ]]; then
    REF="main"
fi

echo "==> Cloning $REPO@$REF"
git clone --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$WORK/bindings" \
    || git clone --depth 1 "https://github.com/$REPO.git" "$WORK/bindings"

# TS binding lives under ffi/ts
cd "$WORK/bindings/ffi/ts"

echo "==> Installing TS binding dependencies (skipping native build)"
npm ci --ignore-scripts

echo "==> Generating TypeDoc markdown"
# Some versions need a tsconfig / entry; adjust if the repo uses a different entry point.
npx typedoc --plugin typedoc-plugin-markdown --out docs-md src/index.ts

echo "==> Copying into $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R docs-md/. "$OUT/"
touch "$OUT/.gitkeep"

echo "==> Done."
