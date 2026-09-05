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
-   **P2P encrypted messaging** — application-agnostic encrypted broadcast overlay (kind-blind relay + mandatory per-message PoW + 1-layer ECIES), carrying aggregation cover-traffic, RFQ token swaps, and standing orders. Identity/prekey split with opt-in persistent identity and manual/periodic prekey rotation, Dandelion++ stem routing, and the `NODE_P2PMSG` service bit. New RPCs `getp2pmsginfo`, `rotatep2pmsginbox`, `sendp2pping` ([#263](https://github.com/nav-io/navio-core/pull/263)). See [P2P encrypted messaging](../concepts/p2p-messaging.md).
-   **blst arithmetic backend** — replaces herumi/mcl with vendored supranational/blst for BLS12-381 arithmetic; ~2× full-chain reindex on x86_64, with verification-heavy ops (MSM, set-membership verify, deserialization) the biggest wins ([#387](https://github.com/nav-io/navio-core/pull/387)). Fixed-base MSM precompute for the range-proof generators + parallel `RecoverAmounts` ([#389](https://github.com/nav-io/navio-core/pull/389)).
-   **Deterministic G1 subgroup check** — the batched subgroup check moves from a random-linear-combination (which accepted an order-3-torsion point ~1/3 of the time, non-deterministically per node) to a deterministic per-point check ([#394](https://github.com/nav-io/navio-core/pull/394)).
-   **Verifier hardening** — proof-deserialization length bounds and identity-commitment early-out rejects on the range-proof and set-membership verifiers ([#390](https://github.com/nav-io/navio-core/pull/390)).
-   **ConnectBlock performance** — reuse the staked-commitment set and per-output content hashes across the connect scans, memoise the PoS body hash, and parallelise BLSCT output hashing ([#391](https://github.com/nav-io/navio-core/pull/391), [#392](https://github.com/nav-io/navio-core/pull/392)).
-   **Wallet / crypto fixes** — no longer abort the node on an exhausted or locked keypool (returns a clean `RPC_WALLET_KEYPOOL_RAN_OUT`) ([#395](https://github.com/nav-io/navio-core/pull/395)); correct `HKDF_Expand`'s final-pass output iterator in EIP-2333 key generation ([#397](https://github.com/nav-io/navio-core/pull/397)).

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
