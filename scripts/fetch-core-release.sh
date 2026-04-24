#!/usr/bin/env bash
# Pull recent release notes from each navio repo and render docs/reference/changelog.md.
#
# Requires: gh CLI, jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/reference/changelog.md"

REPOS=(
    "nav-io/navio-core"
    "nav-io/navio-sdk"
    "nav-io/libblsct-bindings"
    "nav-io/navio-blocks"
    "nav-io/navio-developer-docs"
)

{
    cat <<'HEADER'
# Changelog

Aggregated release notes across Navio repositories. Regenerated nightly.

HEADER

    for repo in "${REPOS[@]}"; do
        echo "## $repo"
        echo
        echo "[All releases on GitHub](https://github.com/$repo/releases)"
        echo
        gh api "repos/$repo/releases" --paginate \
            --jq '.[] | "### [\(.tag_name)](\(.html_url)) — \(.published_at | split("T")[0])\n\n\(.body // "_no body_")\n\n---\n"' \
            2>/dev/null | head -200
        echo
    done

    cat <<'FOOTER'

## Mainnet transition summary

Authoritative announcement: [Network Upgrade and Mainnet Transition Update (Medium)](https://medium.com/nav-coin/network-upgrade-and-mainnet-transition-update-40785628402d).

Key dates / heights:

- **~10,500,000** (Navcoin height): mainnet activation, estimated end of June 2026.
- **11,000,000** (Navcoin height): swap window closes.

Key parameters:

- Initial supply: 81,743,678 NAV migrated.
- Block reward: 8 NAV. Target block time 2 min. Max block 4 MB.
- BLSCT mandatory. PoPS consensus.
- Community fund removed at genesis; unspent legacy balance burned.
- Swap-window staking rewards burned.
FOOTER

} > "$OUT"

echo "==> Wrote $OUT ($(wc -l < "$OUT") lines)"
