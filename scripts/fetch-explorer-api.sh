#!/usr/bin/env bash
# Fetch navio-blocks, boot its API against a running naviod (or a stub),
# dump the OpenAPI JSON, and render it into docs/explorer/api/.
#
# Usage:
#     scripts/fetch-explorer-api.sh [ref]
set -euo pipefail

REPO="nav-io/navio-blocks"
REF="${1:-}"
WORK="$(mktemp -d)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/explorer/api"

trap 'pkill -P $$ || true; rm -rf "$WORK"' EXIT

if [[ -z "$REF" ]]; then
    REF="$(gh api "repos/$REPO/releases/latest" --jq '.tag_name' 2>/dev/null || echo '')"
fi
if [[ -z "$REF" ]]; then
    REF="master"
fi

echo "==> Cloning $REPO@$REF"
git clone --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$WORK/blocks" \
    || git clone --depth 1 "https://github.com/$REPO.git" "$WORK/blocks"

cd "$WORK/blocks"
echo "==> Installing"
npm ci --ignore-scripts
npm run build:shared
npm -w packages/api run build

# Attempt to dump OpenAPI JSON by running the API briefly.
echo "==> Dumping OpenAPI spec"
# The Fastify server typically exposes /docs/json. We run it with
# a dummy DB — no naviod required — and curl the endpoint.
export DB_PATH="$WORK/blocks/empty.db"
export RPC_HOST="127.0.0.1"
export RPC_PORT="33677"
export RPC_USER="dummy"
export RPC_PASSWORD="dummy"
export API_PORT="3099"
node packages/api/dist/index.js &
API_PID=$!

for i in {1..20}; do
    if curl -sf "http://localhost:3099/docs/json" -o "$WORK/openapi.json"; then
        break
    fi
    sleep 1
done

kill $API_PID 2>/dev/null || true

if [[ ! -s "$WORK/openapi.json" ]]; then
    echo "WARN: could not fetch OpenAPI spec; explorer API docs not regenerated."
    exit 0
fi

echo "==> Rendering to Markdown"
rm -rf "$OUT"
mkdir -p "$OUT"

# Prefer `widdershins` if installed; fall back to our minimal renderer.
if command -v widdershins >/dev/null 2>&1; then
    widdershins "$WORK/openapi.json" -o "$OUT/index.md" --summary --omitHeader
else
    python3 "$ROOT/scripts/_render-openapi.py" "$WORK/openapi.json" "$OUT"
fi

# Keep the JSON as a build artefact for debugging; .gitignore drops it from VCS.
cp "$WORK/openapi.json" "$OUT/openapi.json"

echo "==> Done."
