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

Identical to Bitcoin at the byte level. All PoPS blocks — mainnet and testnet — use the same 80-byte header shape. Consensus-critical data that cannot fit in the header (the ZK proof itself) lives in `block.posProof`, appended outside the header.

## Block body

```
CBlock
├── Header              80 bytes
├── posProof            blsct::ProofOfStake (set-membership + range proof)
├── vtx[]               CTransaction[]
│   ├── vtx[0]          Coinbase (zero-value output)
│   ├── vtx[1]          Coinstake (zero-value marker output, then reward outputs)
│   └── vtx[2..]        Regular BLSCT transactions
└── witness commitment  embedded in coinbase if any segwit-style fields used
```

Field order per `primitives/block.h`: `READWRITE(obj.posProof, obj.vtx)` after the header.

## Coinbase

The first transaction is the coinbase. Its single output is zero-value; the real staker reward is paid in the coinstake. `vin[0].prev_out` is the null marker (32 zero bytes).

## Coinstake (PoPS)

Every block carries a `blsct::ProofOfStake posProof` field (see [`primitives/block.h`](https://github.com/nav-io/navio-core/blob/master/src/primitives/block.h)). Structural markers:

```
vtx[0] (coinbase) — null prev_out, zero-value output
vtx[1] (coinstake) — first output is zero-value nonstandard marker
block.posProof — encoded ZK proof (set-membership + range proof)
```

Key points about PoPS — applies to **both mainnet and testnet**:

-   `posProof` does **not** identify the staker's locked UTXO. It contains a set-membership proof over the current staked-commitment set plus a range proof binding a hidden stake amount to the block's kernel-hash eligibility threshold.
-   Eligibility is verifiable with zero-knowledge — no validator identity, amount, or cross-block linkage is revealed.
-   Coinstake outputs pay the 4 NAV reward + returned principal as BLSCT outputs addressed to sub-addresses in the staker's staking pool (account `-2`).

Full math, verifier equations, serialisation, source-tree map: [BLSCT → Proof-of-Private-Stake](pops.md).

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
block.type = "PoPS"  # always — every network uses PoPS
```

BLSCT-aware outputs display as `Hidden` amounts. Transparent outputs (genesis-time bootstrap outputs that seed the PoPS staker set on testnet cuts, and OP_RETURN burns) show values normally. See [supply tracking](../explorer/supply.md).

## Serialisation

-   `src/primitives/block.h` — `CBlock`, `CBlockHeader`.
-   `src/blsct/pos/` — PoS / PoPS consensus rules.
-   `src/consensus/params.h` — chain-level constants (block time, max size, activation heights).

Mainnet activation: Navcoin block **10,500,000** (est. end of June 2026). Max block size **4 MB**. Target block time **60 s** (`nPosTargetSpacing = 60`). Block reward **4 NAV** (`nBLSCTBlockReward = 2 * COIN * (60/30)`).
