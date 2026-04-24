# Reindexing

## Full wipe

Wipe indexed data and resync from genesis:

```bash
npm run reindex
```

Starts the indexer after clearing, so it begins syncing immediately. **Peer and price data are preserved.**

## From a specific height

Keep data below the height, drop and resync from there:

```bash
npm run reindex:from 5000
```

Use this when:

-   A recent block was misparsed and the fix is known.
-   Consensus rules changed at a specific height and the existing state below is still correct.
-   You want to validate the last N blocks against a fresh parse.

## Direct flags

```bash
# Dev mode
npm -w packages/indexer run dev -- --reindex
npm -w packages/indexer run dev -- --from 5000

# Production (compiled)
node packages/indexer/dist/index.js --reindex
node packages/indexer/dist/index.js --from=5000
```

Full option list: `npm -w packages/indexer run dev -- --help`.

## From scratch (including peers / prices)

If you want to wipe **everything**, just delete the DB file:

```bash
npm stop  # if using pm2 or similar
rm navio-blocks.db navio-blocks.db-wal navio-blocks.db-shm
npm start
```

## Why `txindex=1` is required on `naviod`

The indexer needs `getrawtransaction <txid>` for arbitrary transactions during backfill. Without `txindex`, the call fails for any tx not in mempool, breaking resync. Start `naviod` with `-txindex=1` before the first sync.

## Duration

-   Testnet full reindex: typically 20–60 minutes on modern hardware.
-   Testnet partial reindex from height 5000: a few minutes.
-   Mainnet full reindex: proportional to chain size — plan accordingly.

## Verifying correctness

After a reindex, compare the explorer's state to `naviod`:

```bash
navio-cli getblockcount               # expected height
curl localhost:3001/api/stats | jq   # explorer's view
curl localhost:3001/api/supply | jq  # cumulative supply
```

The heights should match. Supply should match the expected schedule for the network (see [supply tracking](supply.md)).

## Idempotency

Reindexing is idempotent — running it twice produces the same final state. If the indexer is killed mid-sync, the next start resumes from the last committed block (`sync_state.last_synced_block_height`).
