# Changelog

!!! info "Auto-generated"
    This page aggregates release notes from every Navio repository. The nightly build pipeline fetches GitHub releases via `gh api` and renders them here. Links below point to the canonical release pages.

Until the pipeline runs, consult:

## navio-core

[Releases on GitHub](https://github.com/nav-io/navio-core/releases)

Notable items to watch for:

-   Consensus-breaking upgrades (announced with target activation heights).
-   **0.1.0** — first stable release; activates **mainnet** (genesis 2026-07-01 13:00 UTC, genesis hash `0af3c23ae1ac4910693b7187ac61641d16d1cf49cba7acf8649d48e831d86b13`).
-   BLSCT protocol version bumps.
-   RPC additions / deprecations.

## navio-sdk

[Releases on GitHub](https://github.com/nav-io/navio-sdk/releases)

Notable items:

-   Breaking API changes.
-   Sync protocol compatibility updates.
-   New transaction primitives (tokens, NFTs, aggregation).

## libblsct-bindings

[Releases on GitHub](https://github.com/nav-io/libblsct-bindings/releases)

Notable items:

-   New language bindings (Python, and upcoming C / Rust / Go).
-   Bulletproofs++ activation.
-   WASM bundle size / performance improvements.
-   Browser API changes.

## navio-blocks

[Releases on GitHub](https://github.com/nav-io/navio-blocks/releases)

Notable items:

-   New REST endpoints.
-   Indexer schema migrations.
-   Frontend design / UX changes.

## navio-developer-docs

[Releases on GitHub](https://github.com/nav-io/navio-developer-docs/releases)

This site itself.

## Mainnet transition summary

Authoritative announcement: [Network Upgrade and Mainnet Transition Update (Medium)](https://medium.com/nav-coin/network-upgrade-and-mainnet-transition-update-40785628402d).

Key dates / heights:

-   **~10,500,000** (Navcoin height): mainnet activation, estimated end of June 2026.
-   **11,000,000** (Navcoin height): swap window closes.

Key parameters:

-   Initial supply: 81,743,678 NAV migrated.
-   Block reward: 4 NAV (`2 * COIN * (nPosTargetSpacing / 30)`). Target block time 60 s. Max block 4 MB.
-   BLSCT mandatory. PoPS consensus (both mainnet and testnet).
-   Community fund removed at genesis; unspent legacy balance burned.
-   Swap-window staking rewards burned.

## How to consume changes

Recommended operator workflow when a new release drops:

1.  Read the release notes.
2.  If consensus-breaking, upgrade **before** activation height.
3.  Dry-run on regtest.
4.  Schedule maintenance window for staking nodes (staking briefly offline during upgrade).
5.  Upgrade in staging first if running production services.
