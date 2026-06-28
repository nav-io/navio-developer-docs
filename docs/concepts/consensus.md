# Consensus & supply

Navio's current chainparams define **BLSCT / Proof-of-Private-Stake (PoPS)** on **mainnet** and **testnet**, each preceded by a short bootstrap PoW phase. Plain `signet` and plain `regtest` remain non-BLSCT in the shipping node; local BLSCT testing uses `-blsctregtest`. For the full mathematical + cryptographic treatment see [BLSCT → Proof-of-Private-Stake](../blsct/pops.md).

## What PoPS is (in one paragraph)

Every block is produced by a validator that holds a locked BLSCT output whose Pedersen commitment is currently in the on-chain **staked commitment set**. To mint a block the validator attaches a two-part zero-knowledge proof: (1) a **set-membership proof** showing it controls *some* commitment in the set without revealing which one, and (2) a **range proof** showing the hidden stake amount in that commitment satisfies the kernel-hash eligibility inequality for this specific block. No validator identity, stake amount, or linkage across successive blocks is ever revealed on-chain.

## Shared BLSCT / PoPS properties

| Property                           | Value (source: `kernel/chainparams.cpp`)        |
| ---------------------------------- | ----------------------------------------------- |
| BLSCT / PoPS networks              | mainnet, testnet                               |
| Local BLSCT dev chain              | `blsctregtest`                                 |
| Non-BLSCT chains in current params | signet, regtest                                |
| Minimum stake (mainnet / testnet)  | **10,000 NAV**                                 |
| Minimum stake (`blsctregtest`)     | **100 NAV**                                    |
| Max supply                         | **Uncapped**                                   |
| Transaction protocol on BLSCT chains | BLSCT mandatory                              |

### Why "private stake"

Classical PoS reveals who is staking (kernel-hash math uses the UTXO, which is public). Navio's PoPS replaces that with:

-   **Pedersen-committed stake amounts** on every staked output — amount is hidden.
-   **Modified RingCT 3.0 set-membership proof** over the committed set — staker identity hidden.
-   **Bulletproofs++ range proof** against a per-block, per-commitment minimum-value target — eligibility provable in ZK, with the kernel binding each commitment's image so stake weight is proportional to total holdings.
-   **Block-bound entropy** — $\eta_{\text{FS}}$ binds the parent block and the block's transaction list (so the proof signs the body); $\eta_\varphi$ and the ring seed derive only from fixed prior chain state (so neither the proof image nor the anonymity ring can be ground). Together: no grinding, no replay, no cross-block linkage of a single staker's blocks.

Full math, verifier equations, and implementation walk-through: [BLSCT → PoPS](../blsct/pops.md).

## Networks

### Mainnet

| Parameter             | Value                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| BLSCT enabled         | Yes                                                                           |
| Bootstrap PoW phase   | Heights `1..110` (`nLastPOWHeight = 110`); PoS (PoPS) begins at height `111`    |
| Height-1 reward       | **81,743,678 NAV** (`nBLSCTFirstBlockReward`)                                 |
| PoW reward after height 1 | **0 NAV** across the bootstrap PoW window (heights `2..110`) (`fOnlyFirstPoWBlockHasReward = true`) |
| Steady-state PoPS reward | **8 NAV** (`nBLSCTBlockReward`)                                            |
| Target block time     | **120 s**                                                                     |
| Retarget window       | **3600 s**                                                                    |
| Minimum stake         | 10,000 NAV                                                                   |
| `posLimit` (difficulty ceiling) | `0x0000ffffffffffff…`                                              |

### Mainnet genesis & launch (v0.1.0)

Navio Core **0.1.0** is the first stable release and the one that activates mainnet ([navio-core PR #291](https://github.com/nav-io/navio-core/pull/291)).

| Genesis field        | Value                                                                |
| -------------------- | ------------------------------------------------------------------- |
| Block hash           | `0af3c23ae1ac4910693b7187ac61641d16d1cf49cba7acf8649d48e831d86b13`  |
| Merkle root          | `96f8dfcc3c433012bc9d4b42e85fe543936609f87fce2cc9d5484383ee2f9aaf`  |
| Timestamp            | `1782910800` — 2026-07-01 13:00 UTC                                 |
| `nMinimumChainWork`  | `0` (fresh chain)                                                   |
| `defaultAssumeValid` | `0` (fresh chain)                                                   |

The genesis coinbase is a **plain unspendable `OP_RETURN`**, *not* a BLSCT output. The genesis block is never connected — `ConnectBlock` special-cases the genesis hash — so it never enters the UTXO/staked-commitment view. Its `scriptSig` hides the message *"Privacy is the power to selectively reveal oneself to the world."*

!!! info "PoW → PoS bootstrap"
    - **Block 1** mints the entire initial supply (**81,743,678 NAV**) in its coinbase.
    - **Heights 2..110** are zero-reward PoW blocks, but each still produces a full BLSCT coinbase output complete with range proofs.
    - `COINBASE_MATURITY = 100`, so the block-1 coinbase matures at tip height **101**.
    - **PoS begins at height 111.** The headroom exists because the PoPS ring needs **≥ 2 commitments**, and each wallet's stakelocks collapse to a single commitment — so the founder must fund and lock stakes from **at least two wallets** before height 111.

**Mainnet seeds:** DNS seed `seed.nav.io`; hardcoded fixed bootstrap seed `blocks.nav.io` (`168.119.249.67:48470`).

### Testnet

| Parameter             | Value                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| BLSCT enabled         | Yes                                                                           |
| Bootstrap PoW phase   | Heights `1..1000` (`nLastPOWHeight = 1000`)                                   |
| Height-1 reward       | **75,000,000 NAV** (`nBLSCTFirstBlockReward`)                                 |
| Steady-state PoPS reward | **4 NAV** (`nBLSCTBlockReward`)                                            |
| Target block time     | **60 s**                                                                      |
| Retarget window       | **1800 s**                                                                    |
| Minimum stake         | 10,000 NAV                                                                   |
| `posLimit`            | `0x0000ffffffffffff…` (easier — faster retarget, smaller set of active stakers) |
| PoPS hardening        | Disabled (`fPoPSHardened = false`) to preserve historical testnet validity    |

### Signet / Regtest / BLSCT Regtest

Plain `signet` and plain `regtest` are **not** BLSCT / PoPS chains in the current implementation (`fBLSCT = false`). For local BLSCT / PoPS development use `-blsctregtest`, which uses:

- `nPePoSMinStakeAmount = 100 * COIN`
- `nPosTargetSpacing = 60`
- `nPosTargetTimespan = 1800`
- `nBLSCTBlockReward = 4 NAV`

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

The wallet computes the fee directly from transaction size — no fee-market estimation, no validator tip. The per-byte rate is a chainparam (`Consensus::Params::nBLSCTDefaultFee`) so each network can tune its own minimum. Source: [`src/blsct/wallet/txfactory_global.h`](https://github.com/nav-io/navio-core/blob/master/src/blsct/wallet/txfactory_global.h) / [`txfactory_base.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/wallet/txfactory_base.cpp).

```
fee_satoshis = GetTransactionWeight(tx) * nBLSCTDefaultFee
             = serialized_size_bytes * 125  (mainnet/testnet/blsctregtest)
```

`nBLSCTDefaultFee` is seeded from the canonical literal `BLSCT_DEFAULT_FEE = 125` defined in [`txfactory_global.h`](https://github.com/nav-io/navio-core/blob/master/src/blsct/wallet/txfactory_global.h) and assigned per-network in [`kernel/chainparams.cpp`](https://github.com/nav-io/navio-core/blob/master/src/kernel/chainparams.cpp). `GetTransactionWeight` here is the BLSCT-specific helper that returns the serialized size of the tx with witness data (`::GetSerializeSize(TX_WITH_WITNESS(tx))`). When `fSubtractFeeFromAmount` is set, the same formula is applied per-output via `GetTransactioOutputWeight`.

### Consensus minimum-fee rule

The same per-byte rate is enforced at consensus time, not just by the wallet. For every BLSCT user transaction (i.e. anything other than the coinbase / reward transaction at `block.vtx[0]`), `blsct::VerifyTx` requires:

```
nFee >= GetTransactionWeight(tx) * Consensus::Params::nBLSCTDefaultFee
```

where `nFee` is the explicit `nValue` of the unique `PayFeePredicate` output. A transaction failing this check is rejected with `blsct-fee-below-min` — both at mempool admission and at block validation. The fee rate is plumbed end-to-end: `validation.cpp` reads it from `Params().GetConsensus()` and passes it into `blsct::VerifyTx` / `blsct::PrepareTxForDeferredVerification`; the wallet's `SendTransaction` overrides the default sentinel in `CreateTransactionData::nBLSCTDefaultFee` with the same chainparam before calling `TxFactory::CreateTransaction`, so wallet-built transactions price exactly at the consensus minimum. Source: [`src/blsct/wallet/verification.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/wallet/verification.cpp) (`VerifyTxCore`).

#### Why this is a consensus rule, not just policy

The fee output of a BLSCT transaction is the only **clear-value** output: an `OP_RETURN` with `nValue = fee` and a `PayFeePredicate` carrying a public key. The fee value isn't hidden in a Pedersen commitment — anyone seeing the wire bytes sees the fee.

Without a consensus floor, a wire-level attacker could (in principle) lower the fee output's `nValue` by some amount $\delta$, add a fresh BLSCT output of value $\delta$ to themselves, and patch the aggregate signature to keep the balance equation consistent. The basic-scheme balance signature signs the constant tag `BLSCTBALANCE` non-augmented, so any attacker who knows their own blinding scalar $\gamma_X$ can compute $-\gamma_X \cdot H_{BLS}(\text{BLSCTBALANCE})$ and fold it into the tx's aggregate `txSig` to compensate the balance-pair shift introduced by the new output.

The minimum-fee rule defeats this: adding any consensus-valid output strictly grows `GetTransactionWeight(tx)` (a BLSCT output costs hundreds of bytes for its range proof, ephemeral / spending / blinding keys, and script), so the new minimum

$$
(W + W_{\text{phantom}}) \cdot \text{BLSCT\_DEFAULT\_FEE}
$$

exceeds the original fee $F = W \cdot \text{BLSCT\_DEFAULT\_FEE}$ by $W_{\text{phantom}} \cdot \text{BLSCT\_DEFAULT\_FEE}$. The attacker is forced to over-fund the fee instead of extracting from it — and they have no way to add value to the tx without controlling additional inputs.

This is the local check that makes BLSCT's basic-scheme balance signature safe against output-malleability attacks, despite the signature itself not committing to the output set.

#### Aggregated transactions

`AggregateTransactions` (in [`src/blsct/wallet/txfactory_global.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/wallet/txfactory_global.cpp)) collapses several signed BLSCT transactions into one. The merged fee is $\sum_i F_i$ and the merged weight is $\sum_i W_i - \text{header overlap}$, so the merged transaction satisfies the minimum with strictly more margin than any constituent. No special handling needed.

#### Coinbase / reward exemption

Coinbase / coinstake reward transactions (`tx.IsCoinBase()` or `blockReward > 0` in the verification path) carry no `PayFeePredicate` output and are funded by the block subsidy plus the burned fees of the block. They use a separate consensus path (the coinbase value check in `ConnectBlock`) and are exempt from the BLSCT minimum-fee rule.

### Deflationary pressure when blocks fill

Fees are burned, not paid to the validator. That interacts with each network's steady-state reward differently:

-   **Block reward (minted):** `8 NAV` on mainnet PoPS blocks, `4 NAV` on testnet / `blsctregtest`.
-   **Full-block fees (burned):** `4_194_304 bytes * 125 sat/byte ≈ 5.24 NAV` at max block size (4 MB).

At sustained full blocks:

-   **Mainnet** remains net inflationary by about `8.00 − 5.24 = 2.76 NAV` per full PoPS block.
-   **Testnet / blsctregtest** become net deflationary by about `4.00 − 5.24 = −1.24 NAV` per full block.

## Supply invariants

-   **Supply evolves monotonically as: prev + coinstake subsidy − transaction fee burns − OP_RETURN burns − swap-window burns at mainnet genesis.** Cumulative total per block is published by the explorer at `/api/supply/block/:height`.
-   **No supply cap.** Navio does not enforce a fixed-money-supply ceiling. Under light load, per-block inflation runs at `nBLSCTBlockReward`; under heavy load, fee burns exceed the subsidy and net supply shrinks.
-   **Fee invariants under BLSCT.** Fees are committed in a cleartext field of the transaction (BLSCT commits amounts, not fees) so the chain can sum and enforce them even when per-output values are hidden.

## Staking mechanics

Locking: [`stakelock`](../rpc/blsct.md#stakelock). Unlocking: [`stakeunlock`](../rpc/blsct.md#stakeunlock). Minimum stake: 10,000 NAV on mainnet / testnet, 100 NAV on `blsctregtest`. The standalone [`navio-staker`](../node/staking.md) daemon polls for eligible commitments and assembles PoPS proofs on BLSCT-enabled chains.

## Reorgs and finality

Navio uses probabilistic finality. Chain selection is analogous to Bitcoin's "most chain work" rule but accumulates **PoS target** rather than PoW work — the paper's §7.2.3 and the shipping `CompareProofOfStake*` logic select the leaf with lower accumulated target (= higher effective stake weight). Confirmation guidance:

-   1–2 confirmations for low-value transfers.
-   6 confirmations for typical exchange deposits.
-   10+ confirmations for mainnet-level high-value flows or cross-chain atomic swaps.

See [Exchange integration](../guides/exchange-integration.md#reorg-handling) for production reorg handling.

## Source tree references

-   Consensus params: [`src/kernel/chainparams.cpp`](https://github.com/nav-io/navio-core/blob/master/src/kernel/chainparams.cpp), [`src/consensus/params.h`](https://github.com/nav-io/navio-core/blob/master/src/consensus/params.h).
-   Proof construction: [`src/blsct/pos/proof.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/pos/proof.cpp), [`src/blsct/set_mem_proof/set_mem_proof_prover.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/set_mem_proof/set_mem_proof_prover.cpp).
-   Verification: [`src/validation.cpp`](https://github.com/nav-io/navio-core/blob/master/src/validation.cpp) (`ConnectBlock`).
-   Staker daemon: [`src/navio-staker.cpp`](https://github.com/nav-io/navio-core/blob/master/src/navio-staker.cpp).

The **[BLSCT → PoPS deep-dive](../blsct/pops.md)** is the definitive math / crypto reference for this section.
