# Block format

A Navio block is a Bitcoin-shaped block with BLSCT-aware transaction bodies.

## Header

```
CBlockHeader (80 bytes)
├── nVersion            int32
├── hashPrevBlock       32 bytes
├── hashMerkleRoot      32 bytes
├── nTime               uint32
├── nBits               uint32    compact difficulty target
└── nNonce              uint32    Header nonce (legacy Bitcoin field; PoPS proof lives in block.posProof, not here)
```

Identical to Bitcoin at the byte level. All BLSCT / PoPS blocks use the same 80-byte header shape. Consensus-critical data that cannot fit in the header (the ZK proof itself) lives in `block.posProof`, appended outside the header.

## Block body

```
CBlock
├── Header              80 bytes
├── posProof            blsct::ProofOfStake (set-membership + range proof)
└── vtx[]               CTransaction[]
    ├── vtx[0]          Coinbase: BLSCT reward output (+ optional operator-fee output)
    └── vtx[1]          The block's user transactions, merged into one aggregate (if any)
```

Field order per `primitives/block.h`: `READWRITE(obj.posProof, obj.vtx)` after the header.

On BLSCT chains a block holds **at most two transactions**. The block assembler (`CreateNewBLSCTBlock` in `node/miner.cpp`) merges every user transaction it selects into one aggregate with `blsct::AggregateTransactions`; with a single user transaction it keeps that transaction (and its txid) as is. The aggregate concatenates the components' inputs and outputs in order, folds their fee outputs into one, and sums their signatures. It performs **no cut-through**: a chain of unconfirmed sends merged into one block keeps each intermediate change output together with the input that spends it. Nodes recognise the component transactions as **confirmed by containment** — see [P2P protocol → Aggregated blocks](../concepts/p2p-protocol.md#aggregated-blocks), which also covers the compact-block encoding (`sendcmpct` version 3, `cmpctaggblk`) that relays such blocks without re-downloading the aggregate.

The template defers a transaction that spends a staked commitment created earlier in the same template to a later block, and drops colliding staked-commitment outputs instead of failing the template.

## Coinbase

The first transaction is the coinbase (`nVersion` carries the BLSCT marker, `vin[0].prevout` is null, `scriptSig` = `<height> OP_0`). It pays the block reward as a full BLSCT output addressed to the block producer's chosen destination (`coinbasedest` in `getblocktemplate`). When the template requests an operator fee split (`coinbasefeedest` / `coinbasefeebps`, used by [cold-staking](../node/cold-staking.md) operators), a second BLSCT output carries that share. Consensus binds only the coinbase's total amount; the split is builder policy. The coinbase signature aggregates the outputs' signatures and a balance signature.

During the bootstrap PoW window (heights `2..110` on mainnet), the reward is zero but the coinbase output **still carries a full range proof and BLSCT keys** — the miner constructs it with `fAllowZeroValueRangeProof = true`.

!!! note "Why a range proof on a zero-value coinbase"
    Normally `CreateOutput()` collapses a `0` amount into an unspendable `OP_RETURN` with no range proof. But the coinbase still carries balance and output signatures that are folded into the block's aggregate signature check — an `OP_RETURN` output (no range proof, no keys) would have nothing to sign over and the aggregate verification would fail. Passing `fAllowZeroValueRangeProof = true` forces a proper BLSCT output so the signatures remain valid.

The **block-1 coinbase mints the entire initial supply**.

## Proof of stake (PoPS)

Every block carries a `blsct::ProofOfStake posProof` field (see [`primitives/block.h`](https://github.com/nav-io/navio-core/blob/master/src/primitives/block.h)). There is no coinstake transaction and no staked input in the block:

-   `posProof` does **not** identify the staker's locked output. It contains a set-membership proof over a sampled ring of the staked-commitment set plus a range proof binding the hidden stake amount to the block's kernel-hash eligibility threshold.
-   Eligibility is verifiable with zero-knowledge — no validator identity, amount, or cross-block linkage is revealed.
-   The stake stays locked; only the reward is paid, through the coinbase.

Applies to the current BLSCT networks (mainnet, testnet, and `blsctregtest`). Full math, verifier equations, serialisation, source-tree map: [BLSCT → Proof-of-Private-Stake](pops.md).

## Fee handling

| Source                                   | Fate                                                      |
| ---------------------------------------- | --------------------------------------------------------- |
| Regular BLSCT transaction fees           | **Burned**                                                 |
| OP_RETURN outputs                        | Burned — provably unspendable                              |
| Community fund (legacy Navcoin at mainnet genesis) | Burned                                          |
| Staking rewards earned on migrated supply during swap window | Burned                                |

See [Consensus](../concepts/consensus.md) for the full economic picture.

## Merkle commitment

Standard Bitcoin-style Merkle tree of transaction hashes, committed to in the header. BLSCT transactions hash via their canonical serialised form including BLSCT-specific fields.

## Block explorer view

The [navio-blocks](../explorer/index.md) indexer categorises blocks via:

```python
block.type = "PoPS"  # on BLSCT / PoPS chains
```

BLSCT-aware outputs display as `Hidden` amounts. Transparent outputs (genesis-time bootstrap outputs that seed the PoPS staker set on testnet cuts, and OP_RETURN burns) show values normally. See [supply tracking](../explorer/supply.md).

## Genesis block (mainnet)

The mainnet genesis block (height `0`) is a plain unspendable `OP_RETURN` coinbase — **not** a BLSCT output. There is no range proof or BLSCT keys, because the genesis block is never connected to the UTXO set: `ConnectBlock()` in `validation.cpp` special-cases the genesis hash and returns early, so no spendable BLSCT output is ever needed.

| Field             | Value                                                                |
| ----------------- | -------------------------------------------------------------------- |
| Block hash        | `0af3c23ae1ac4910693b7187ac61641d16d1cf49cba7acf8649d48e831d86b13`   |
| Merkle root       | `96f8dfcc3c433012bc9d4b42e85fe543936609f87fce2cc9d5484383ee2f9aaf`   |
| `nTime`           | `1782910800` (2026-07-01 13:00 UTC)                                  |
| `nNonce`          | `0`                                                                  |
| `nBits`           | `0x207fffff`                                                         |
| `nVersion`        | `0x40000000` (BLSCT version bit)                                     |

The coinbase `scriptSig` embeds a hidden message:

```
Privacy is the power to selectively reveal oneself to the world.
```

Both `nMinimumChainWork` and `defaultAssumeValid` are zero — this is a fresh chain with no checkpointed history.

## Serialisation

-   `src/primitives/block.h` — `CBlock`, `CBlockHeader`.
-   `src/blsct/pos/` — PoS / PoPS consensus rules.
-   `src/consensus/params.h` — chain-level constants (block time, max size, activation heights).

Current chainparams: mainnet uses a bootstrap PoW window through height `110` (PoPS from height `111`), then PoPS with `nPosTargetSpacing = 120` and `nBLSCTBlockReward = 8 NAV`; testnet uses a bootstrap PoW window through height `1000`, then PoPS with `nPosTargetSpacing = 120` and `nBLSCTBlockReward = 8 NAV`.
