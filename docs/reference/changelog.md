# Changelog

!!! info "Auto-generated"
    This page aggregates release notes from every Navio repository. The nightly build pipeline fetches GitHub releases via `gh api` and renders them here. Links below point to the canonical release pages.

Until the pipeline runs, consult:

## navio-core

[Releases on GitHub](https://github.com/nav-io/navio-core/releases)

Notable items to watch for:

-   Consensus-breaking upgrades (announced with target activation heights).
-   BLSCT protocol version bumps.
-   RPC additions / deprecations.

Recent releases:

-   **0.1.3** (latest) — `sendtoblsctaddress` now honors `subtractfeefromamount` and stores `comment`/`comment_to` on the sender's wallet ([#302](https://github.com/nav-io/navio-core/pull/302)); atomic-swap HTLC outputs auto-register as watch-only when built via `createblsctrawtransaction` ([#298](https://github.com/nav-io/navio-core/pull/298)); mainnet `chainTxData` populated for sync-progress estimation ([#303](https://github.com/nav-io/navio-core/pull/303)); staked-commitment gathering fixed before unstake selection.
-   **0.1.2** — robust BLSCT coin selection, consolidation, and spent-output tracking ([#296](https://github.com/nav-io/navio-core/pull/296)).
-   **0.1.1** — client-version bump; PoW→PoS mainnet bootstrap fix.
-   **0.1.0** — first stable release; activates **mainnet** (genesis 2026-07-01 13:00 UTC, genesis hash `0af3c23ae1ac4910693b7187ac61641d16d1cf49cba7acf8649d48e831d86b13`).

Unreleased (feature branches):

-   BIP-39 **mnemonic passphrase** — `createwallet mnemonic_passphrase` / `navio-wallet -mnemonicpassphrase` (`feat/mnemonic-bip39-passphrase`).

## navio-sdk

[Releases on GitHub](https://github.com/nav-io/navio-sdk/releases)

Notable items:

-   Breaking API changes.
-   Sync protocol compatibility updates.
-   New transaction primitives (tokens, NFTs, aggregation).

Recent releases (npm `navio-sdk`, bundling `navio-blsct`):

-   **0.1.16** — fee-calculation refactor; eliminates a spurious burn-address output on NAV sends. Bundles `navio-blsct ^1.1.15`.
-   **0.1.14** — `sendToMany` (multi-recipient single-tx sends) and transaction aggregation helpers.
-   **0.1.13** — token & NFT collection creation, minting, and sending.
-   **0.1.12** — watch-only wallet restore from BLSCT audit keys + audit-key export.

Unreleased (feature branches):

-   **RFQ atomic-swap trading** — taker/maker peer-to-peer token trading over encrypted p2p messaging (`rfq-swap-trading`). See [Token trading](../sdk/trading.md).

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
-   Block reward: 8 NAV (`2 * COIN * (nPosTargetSpacing / 30)`, with a 120 s target spacing). Max block 4 MB.
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
