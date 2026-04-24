#!/usr/bin/env bash
# Fetch navio-core, extract BLSCT RPCs via extract-blsct-rpc.py, write docs/rpc/blsct.md.
# Also spins up a regtest naviod to dump `navio-cli help` for other categories — optional.
#
# Usage:
#     scripts/fetch-core-rpc.sh [ref]
set -euo pipefail

REPO="nav-io/navio-core"
REF="${1:-}"
WORK="$(mktemp -d)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

trap 'rm -rf "$WORK"' EXIT

if [[ -z "$REF" ]]; then
    REF="$(gh api "repos/$REPO/releases/latest" --jq '.tag_name' 2>/dev/null || echo '')"
fi
if [[ -z "$REF" ]]; then
    REF="master"
fi

echo "==> Cloning $REPO@$REF"
git clone --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$WORK/core" \
    || git clone --depth 1 "https://github.com/$REPO.git" "$WORK/core"

echo "==> Extracting BLSCT RPCs from source"
{
    cat "$ROOT/docs/rpc/_blsct_header.md" 2>/dev/null || cat <<'HEADER'
# BLSCT commands

All Navio-specific JSON-RPC commands. Auto-generated from `nav-io/navio-core` source.

HEADER
    python3 "$ROOT/scripts/extract-blsct-rpc.py" "$WORK/core"
} > "$ROOT/docs/rpc/blsct.md"

echo "==> Wrote $(wc -l < "$ROOT/docs/rpc/blsct.md") lines to docs/rpc/blsct.md"

# Optional: auto-populate category pages by running naviod in regtest + parsing `help`
# This requires the binary to be available; skip if not present.
if command -v naviod >/dev/null 2>&1; then
    echo "==> Generating category help pages via naviod regtest"
    "$ROOT/scripts/_fetch-rpc-help.sh" "$WORK/core" || echo "WARN: help extraction failed; category stubs kept"
else
    echo "naviod not in PATH — skipping live help extraction. Category pages remain as hand-written stubs."
fi

echo "==> Done."
