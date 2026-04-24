# Consensus & supply

Navio runs **Proof-of-Private-Stake (PoPS)** on **every network** — mainnet, testnet, signet, regtest. There is no PoW phase in the shipping implementation. The differences between networks are difficulty limits, activation heights, minimum-stake thresholds on regtest, and genesis supply. For the full mathematical + cryptographic treatment see [BLSCT → Proof-of-Private-Stake](../blsct/pops.md).

## What PoPS is (in one paragraph)

Every block is produced by a validator that holds a locked BLSCT output whose Pedersen commitment is currently in the on-chain **staked commitment set**. To mint a block the validator attaches a two-part zero-knowledge proof: (1) a **set-membership proof** showing it controls *some* commitment in the set without revealing which one, and (2) a **range proof** showing the hidden stake amount in that commitment satisfies the kernel-hash eligibility inequality for this specific block. No validator identity, stake amount, or linkage across successive blocks is ever revealed on-chain.

## Shared consensus parameters

| Parameter                          | Value (source: `kernel/chainparams.cpp`)        |
| ---------------------------------- | ----------------------------------------------- |
| Consensus algorithm                | Proof-of-Private-Stake (PoPS)                   |
| Target block time (`nPosTargetSpacing`) | **60 s** (1-minute blocks)                 |
| Retarget window (`nPosTargetTimespan`)  | **1800 s** (30 min → retarget every 30 blocks) |
| Block reward (`nBLSCTBlockReward`)  | $2 \cdot \text{COIN} \cdot (\text{nPosTargetSpacing} / 30) = \mathbf{4~NAV}$ per block |
| Minimum stake (`nPePoSMinStakeAmount`) — mainnet / testnet / signet | **10,000 NAV**          |
| Minimum stake — regtest             | 100 NAV                                         |
| Max supply                          | **Uncapped** — no fixed money-supply ceiling; inflation continues at the per-block reward rate |
| Transaction protocol                | BLSCT mandatory                                 |

### Why "private stake"

Classical PoS reveals who is staking (kernel-hash math uses the UTXO, which is public). Navio's PoPS replaces that with:

-   **Pedersen-committed stake amounts** on every staked output — amount is hidden.
-   **Modified RingCT 3.0 set-membership proof** over the committed set — staker identity hidden.
-   **Bulletproofs++ range proof** against a per-block minimum-value target — eligibility provable in ZK.
-   **Block-bound entropy** ($\eta_{\text{FS}}$ from the parent block, $\eta_\varphi$ from the block's tx list) — no grinding, no replay, no cross-block linkage of a single staker's blocks.

Full math, verifier equations, and implementation walk-through: [BLSCT → PoPS](../blsct/pops.md).

## Networks

### Mainnet

| Parameter             | Value                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| Activation (expected) | Navcoin block height **10,500,000** (est. end of June 2026)                   |
| Swap window close     | Navcoin block height **11,000,000**                                          |
| Initial genesis supply | **81,743,678 NAV** (projected Navcoin supply at swap close, migrated 1:1)   |
| Community fund        | **Removed**         |
| Block reward          | 4 NAV                                                                        |
| Minimum stake         | 10,000 NAV                                                                   |
| `posLimit` (difficulty ceiling) | `0x00000000ffffffff…`                                              |

Announcement: [Navio mainnet transition update](https://medium.com/nav-coin/network-upgrade-and-mainnet-transition-update-40785628402d).

### Testnet

| Parameter             | Value                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| Consensus             | PoPS from genesis onward                                                      |
| Block reward          | 8 NAV                                                                        |
| Minimum stake         | 10,000 NAV                                                                   |
| `posLimit`            | `0x0000ffffffffffff…` (easier — faster retarget, smaller set of active stakers) |
| Genesis supply bootstrap | Chain-specific, see `chainparams.cpp`; includes a transparent genesis output used to bootstrap the testnet staker set |

### Signet / Regtest

Regtest uses `nPePoSMinStakeAmount = 100 * COIN` so local dev networks can stake without large funding. Signet mirrors testnet rules.

## Staked commitment set

Validators publish a special BLSCT transaction whose output is tagged as a **staked commitment**. Consensus maintains the set of unspent staked commitments in the UTXO view (`CCoinsViewCache::GetStakedCommitments`). An `OP_STAKED_COMMITMENT_UNSPENT` flag marks active entries; commitments become `STAKED_COMMITMENT_SPENT` when the staker unlocks.

Set invariants:

-   `|stakedCommitments| ≥ 2` — single-commitment set rejected (set membership proof impossible to construct).
-   Padded to next power of two (cap `N = 1024`) with non-malleable dummy points for the set-membership proof.
-   Publicly observable: size + raw commitment points. **Not** observable: owner labels, stake amounts, linkage to past/future blocks from same staker.

## Fee handling

| Source                                   | Fate                                                          |
| ---------------------------------------- | ------------------------------------------------------------- |
| Regular BLSCT transaction fees           | **Burned**                                                     |
| OP_RETURN outputs                        | **Burned** — provably unspendable, reduces circulating supply  |

### Default fee calculation

Wallet default fee is computed directly from transaction size — no fee-market estimation, no validator tip. Source: [`src/blsct/wallet/txfactory_global.h`](https://github.com/nav-io/navio-core/blob/master/src/blsct/wallet/txfactory_global.h) / [`txfactory_base.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/wallet/txfactory_base.cpp).

```
fee_satoshis = GetTransactionWeight(tx) * BLSCT_DEFAULT_FEE
             = serialized_size_bytes * 125
```

`BLSCT_DEFAULT_FEE = 125` (sat/byte). `GetTransactionWeight` returns the serialized size of the tx with witness data (`::GetSerializeSize(TX_WITH_WITNESS(tx))`). When `fSubtractFeeFromAmount` is set, the same formula is applied per-output via `GetTransactioOutputWeight`.

### Deflationary pressure when blocks fill

Fees are burned, not paid to the validator. This flips the supply equation under load:

-   **Block reward (minted):** `nBLSCTBlockReward = 4 NAV` (or 8 NAV if `nPosTargetSpacing = 120`, derived from `2 * COIN * (spacing/30)`).
-   **Full-block fees (burned):** `4_194_304 bytes * 125 sat/byte ≈ 5.24 NAV` at max block size (4 MB).

Net supply change per full block ≈ `4 NAV minted − 5.24 NAV burned = −1.24 NAV`. At sustained full blocks, **NAV becomes net-deflationary**: more coins are burned via fees than minted as staking rewards. Under light load (empty or near-empty blocks), the coinstake subsidy dominates and supply inflates at the usual rate. The chain therefore has no hard supply cap but a built-in deflationary feedback loop proportional to demand for blockspace.

## Supply invariants

-   **Supply evolves monotonically as: prev + coinstake subsidy − transaction fee burns − OP_RETURN burns − swap-window burns at mainnet genesis.** Cumulative total per block is published by the explorer at `/api/supply/block/:height`.
-   **No supply cap.** Navio does not enforce a fixed-money-supply ceiling. Under light load, per-block inflation runs at `nBLSCTBlockReward`; under heavy load, fee burns exceed the subsidy and net supply shrinks.
-   **Fee invariants under BLSCT.** Fees are committed in a cleartext field of the transaction (BLSCT commits amounts, not fees) so the chain can sum and enforce them even when per-output values are hidden.

## Staking mechanics

Locking: [`stakelock`](../rpc/blsct.md#stakelock). Unlocking: [`stakeunlock`](../rpc/blsct.md#stakeunlock). Minimum stake: 10,000 NAV (100 NAV on regtest). The standalone [`navio-staker`](../node/staking.md) daemon polls for eligible commitments and assembles PoPS proofs.

## Reorgs and finality

Navio uses probabilistic finality. Chain selection is analogous to Bitcoin's "most chain work" rule but accumulates **PoS target** rather than PoW work — the paper's §7.2.3 and the shipping `CompareProofOfStake*` logic select the leaf with lower accumulated target (= higher effective stake weight). Confirmation guidance:

-   1–2 confirmations for low-value transfers.
-   6 confirmations for typical exchange deposits.
-   30+ confirmations for mainnet-level high-value flows or cross-chain atomic swaps.

See [Exchange integration](../guides/exchange-integration.md#reorg-handling) for production reorg handling.

## Source tree references

-   Consensus params: [`src/kernel/chainparams.cpp`](https://github.com/nav-io/navio-core/blob/master/src/kernel/chainparams.cpp), [`src/consensus/params.h`](https://github.com/nav-io/navio-core/blob/master/src/consensus/params.h).
-   Proof construction: [`src/blsct/pos/proof.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/pos/proof.cpp), [`src/blsct/set_mem_proof/set_mem_proof_prover.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/set_mem_proof/set_mem_proof_prover.cpp).
-   Verification: [`src/validation.cpp`](https://github.com/nav-io/navio-core/blob/master/src/validation.cpp) (`ConnectBlock`).
-   Staker daemon: [`src/navio-staker.cpp`](https://github.com/nav-io/navio-core/blob/master/src/navio-staker.cpp).

The **[BLSCT → PoPS deep-dive](../blsct/pops.md)** is the definitive math / crypto reference for this section.
