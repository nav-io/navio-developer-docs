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

## Network regimes (both mainnet and testnet use PoPS)

| Network | Block reward | Min stake                | Notes                                                 |
| ------- | ------------ | ------------------------ | ----------------------------------------------------- |
| mainnet | 8 NAV        | 10,000 NAV               | Initial supply 81,743,678 NAV migrated from Navcoin   |
| testnet | 4 NAV        | 10,000 NAV               | Includes a genesis-time bootstrap output seeding the first staker set |
| signet  | 4 NAV        | 10,000 NAV               | —                                                     |
| regtest | 4 NAV        | 100 NAV                  | Small minimum for local testing                       |

See [Concepts → Consensus & supply](../concepts/consensus.md).

## Computation

Pseudocode (see `packages/indexer/src/sync/supply.ts` in `navio-blocks` for real code):

```ts
function supplyDelta(block, network, params) {
    // PoPS on every network — single-branch.
    const subsidy = BigInt(params.nBLSCTBlockReward); // sats, 4 NAV = 4 * 1e8
    const recipientType = 'staker';

    const fees = sumFeesFromTxs(block);
    const burnedFees = sumOpReturnOutputAmounts(block);

    return { subsidy, fees, burnedFees, recipientType };
}
```

At mainnet genesis: credit 81,743,678 NAV as migrated supply and burn any legacy community-fund balance + swap-window staking rewards. Testnet genesis block may include a transparent bootstrap output seeding the initial staker set — the indexer reads the explicit coinbase outputs rather than hard-coding an amount.

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

-   **Mainnet genesis** — migrate 81,743,678 NAV, burn legacy community fund, burn swap-window rewards.
-   **Testnet genesis bootstrap** — initial PoPS staker set requires seed commitments; read the actual transparent bootstrap output(s) from the genesis block rather than hard-coding a value (testnet cuts change).
-   **OP_RETURN burn** — every block's OP_RETURN outputs reduce circulating supply.
-   **Validator reward** — credited via BLSCT coinstake outputs (amount hidden). **Transaction fees are burned** (not paid to validator), reducing circulating supply.
