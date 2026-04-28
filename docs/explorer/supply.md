# Supply tracking

The indexer computes per-block supply data and serves it via `/api/supply/*`.

## Inputs per block

For each block the indexer records:

1.  **Subsidy** — the base block reward from the coinbase/coinstake.
2.  **Fees paid** — total fees paid in this block.
3.  **Fees burned** — fees that went to OP_RETURN outputs (unspendable).
4.  **Reward recipient type** — `staker` (regular PoPS block), `bootstrap` (genesis transparent outputs), or `burned` (edge cases).
5.  **Cumulative supply** — running total of spendable NAV up to and including this block.

See [`navio-blocks` README](https://github.com/nav-io/navio-blocks/blob/master/README.md) for the reference implementation of these rules.

## Network regimes

| Network | Block reward | Min stake                | Notes                                                 |
| ------- | ------------ | ------------------------ | ----------------------------------------------------- |
| mainnet | 8 NAV        | 10,000 NAV               | Height 1 mints `nBLSCTFirstBlockReward`; bootstrap PoW then PoPS |
| testnet | 4 NAV        | 10,000 NAV               | Height 1 mints `nBLSCTFirstBlockReward`; bootstrap PoW then PoPS |
| `blsctregtest` | 4 NAV | 100 NAV                  | Local BLSCT / PoPS development chain                  |

See [Concepts → Consensus & supply](../concepts/consensus.md).

## Computation

Pseudocode (see `packages/indexer/src/sync/supply.ts` in `navio-blocks` for real code):

```ts
function supplyDelta(block, network, params) {
    // BLSCT / PoPS networks only.
    const subsidy = BigInt(params.nBLSCTBlockReward); // sats, 4 NAV = 4 * 1e8
    const recipientType = 'staker';

    const fees = sumFeesFromTxs(block);
    const burnedFees = sumOpReturnOutputAmounts(block);

    return { subsidy, fees, burnedFees, recipientType };
}
```

Height 1 on BLSCT chains mints `nBLSCTFirstBlockReward`. On mainnet, subsequent PoW bootstrap blocks through `nLastPOWHeight` carry zero subsidy when `fOnlyFirstPoWBlockHasReward = true`; PoPS blocks after the bootstrap window pay `nBLSCTBlockReward`.

## Endpoints

Served from the precomputed `block_supply` table:

-   `GET /api/supply` — `{ total, max, burned, currentReward }`
-   `GET /api/supply/chart?period=24h|7d|30d|1y|all` — time-series
-   `GET /api/supply/block/:height` — single block supply entry
-   `GET /api/supply/burned` — `{ total, last_24h, last_7d, last_30d }`

## Invariants

-   **Cumulative supply is monotonic** (it never decreases). OP_RETURN burns reduce the *next* block's subsidy portion going into circulation, not the historical total.
-   **No supply cap.** Navio does not enforce a fixed-money ceiling. Cumulative supply grows by `nBLSCTBlockReward` per block indefinitely.
-   **Fees reconcile.** The sum of paid fees in a block matches the difference between input commitments and output commitments for transparent txs; for BLSCT txs, the fee is a transparent field on the transaction and is directly readable.

## Edge cases

-   **Height 1 initial mint** — use `nBLSCTFirstBlockReward` from chainparams.
-   **Bootstrap PoW window** — on mainnet, heights `2..nLastPOWHeight` have zero subsidy when `fOnlyFirstPoWBlockHasReward = true`.
-   **Testnet genesis bootstrap** — initial PoPS staker set may require seed commitments; read the explicit chain data rather than hard-coding explorer assumptions.
-   **OP_RETURN burn** — every block's OP_RETURN outputs reduce circulating supply.
-   **Validator reward** — credited via BLSCT coinstake outputs (amount hidden). **Transaction fees are burned** (not paid to validator), reducing circulating supply.
