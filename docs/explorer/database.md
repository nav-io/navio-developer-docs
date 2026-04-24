# Database schema

SQLite in WAL mode. File defaults to `./navio-blocks.db`.

## Tables

| Table               | Primary key        | Purpose                                               |
| ------------------- | ------------------ | ----------------------------------------------------- |
| `blocks`            | `height`           | Block headers                                         |
| `transactions`      | `txid`             | Transaction metadata                                  |
| `outputs`           | `output_hash`      | Transparent values OR BLSCT keys                      |
| `inputs`            | `(txid, vin)`      | Spent-output references — `prev_out` is a single hash |
| `peers`             | `ip` / `composite` | Connected nodes with geolocation                      |
| `price_history`     | `(ts, source)`     | NAV price over time (MEXC + others)                    |
| `block_supply`      | `height`           | Per-block reward, burned fees, cumulative supply      |
| `sync_state`        | singleton          | Indexer progress tracking                             |

## Indexes

-   `blocks(hash)` — fast lookup by hash.
-   `transactions(block_height)` — list tx per block.
-   `outputs(txid)` — list outputs per tx.
-   `outputs(is_spent)` — UTXO filtering.
-   `outputs(token_id)` — asset-scoped queries.
-   `inputs(prev_out)` — reverse lookup "who spent this output".
-   `price_history(ts)`.
-   `block_supply(height)` — already PK.

## Column definitions (high-level)

### `blocks`

`height`, `hash`, `prev_hash`, `merkle_root`, `time`, `bits`, `nonce`, `size`, `weight`, `tx_count`, `is_pos` (bool), `staker_address` (null for PoPS), `difficulty`.

### `transactions`

`txid`, `block_height`, `block_index`, `version`, `locktime`, `size`, `fee`, `vin_count`, `vout_count`, `is_blsct` (bool), `is_coinstake` (bool), `is_coinbase` (bool).

### `outputs`

`output_hash` (PK), `txid`, `vout`, `value` (nullable — null for BLSCT), `scriptPubKey` (hex), `address` (nullable), `token_id` (nullable), `blsct_blinding_key` (nullable), `blsct_view_tag` (nullable), `blsct_spending_key` (nullable), `is_spent` (bool), `spent_by_txid` (nullable), `spent_at_height` (nullable).

### `inputs`

`txid`, `vin`, `prev_out` (refers to `outputs.output_hash`), `sequence`, `script_sig`, `witness` (nullable).

### `peers`

`address`, `port`, `version`, `subver`, `services`, `last_seen`, `first_seen`, `latitude`, `longitude`, `country`, `city`, `isp`, `is_reachable` (bool).

### `price_history`

`ts`, `source` (`mexc` / others), `price_usd`, `price_btc`, `volume_24h`, `change_24h`.

### `block_supply`

`height`, `subsidy` (sats), `fees_paid` (sats), `fees_burned` (sats), `cumulative_supply` (sats, after this block), `reward_recipient_type` (`miner` / `staker` / `bootstrap` / `burned`).

### `sync_state`

`last_synced_block_height`, `last_synced_block_hash`, `last_indexed_mempool_size`, `last_peer_crawl_ts`, `last_price_fetch_ts`.

## Initialisation

The database is created automatically on first run. Schema migrations live in `packages/indexer/src/db/migrations/` and run on startup.

## Resetting

```bash
# wipe everything, resync from genesis
npm run reindex

# keep blocks below this height, resync from it
npm run reindex:from 5000
```

See the [reindex guide](reindex.md). Peer data and price history are preserved across reindexes.

## WAL mode

-   Readers (API) and writer (indexer) do not block each other.
-   Checkpoint files (`-wal`, `-shm`) sit next to the main DB file. Back up all three atomically, or use SQLite's online backup API.
-   Long-running read transactions can prevent WAL truncation — the API uses short transactions to avoid this.
