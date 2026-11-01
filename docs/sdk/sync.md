# Synchronization

Sync brings the wallet state up to date with the current chain tip: fetches transaction keys, runs the [view-tag + stealth-key filter](../blsct/detection.md), decrypts amounts on matches, and records the results in the wallet DB.

## Backends

Two sync providers are interchangeable; pick one at client creation time.

### Electrum provider {#electrum-provider}

Uses the extended Navio Electrum protocol — fastest initial sync via `blockchain.block.get_range_txs_keys` batching.

```ts
new NavioClient({
    backend: 'electrum',
    electrum: {
        host: 'electrum.example.com',
        port: 50002,
        ssl: true,
    },
    // ...
});
```

Supports **real-time header subscriptions** — new blocks push to the client via `blockchain.headers.subscribe` without polling.

### P2P provider {#p2p-provider}

Connects directly to a `naviod` full node's P2P port — no Electrum server needed. Usable end to end since **0.1.36**: header sync, block scanning, broadcast and transaction lookup all run over the standard Navio wire protocol.

```ts
new NavioClient({
    backend: 'p2p',
    network: 'mainnet',
    p2p: {
        host: 'node.example.com',
        // port defaults by network: mainnet 48470, testnet 33670, regtest 18444
    },
    // ...
});
```

-   **Headers** via `getheaders`, chained by previous hash; a fork truncates to the fork point.
-   **Blocks** via `getdata`, parsed locally (output keys, view tags, output hashes, spent outputs). Up to 8 blocks download concurrently.
-   **Broadcast** pushes a `tx` message, then confirms the node holds the transaction in its mempool; a rejected transaction throws.
-   **New blocks** are picked up from the node's `inv` announcements, so background sync reacts without waiting for the poll interval.

The P2P network (magic bytes and default port) follows the client's `network` unless `p2p.network` / `p2p.port` override it. The node needs no special configuration beyond `-listen=1`; the SDK advertises no services (`NODE_NONE`). For local development run `naviod -chain=blsctregtest` with `network: 'regtest'`.

### When to choose which

| Use case                                         | Backend        |
| ------------------------------------------------ | -------------- |
| Lightweight browser wallet                       | Electrum (WSS) |
| Self-hosted with a nearby Electrum server        | Electrum       |
| No Electrum available, have direct node access   | P2P            |
| Low-latency mempool / block events               | Electrum       |

!!! note "Electrum paging fix (0.3.0)"
    Since 0.3.0 the Electrum provider resumes `get_range_txs_keys` paging at `start + blocks.length` and ignores a `next_height` beyond what the server returned, so a size-limited page can no longer skip blocks. Wallets synced with an older SDK against an older ElectrumX can re-scan with `resetSyncState()` to pick up any missed outputs.

## `sync()` — one-shot

```ts
await client.sync({
    startHeight: 50000,            // default: last synced + 1
    endHeight:   undefined,        // default: chain tip
    onProgress:  (height, tip, blocks, txKeys, isReorg) => {
        console.log(`${height}/${tip} — ${blocks} blocks, ${txKeys} keys, reorg=${isReorg}`);
    },
    stopOnReorg:        false,     // throw ReorgError instead of recovering; default false
    verifyHashes:       true,      // verify block hashes; default true
    saveInterval:       100,       // persist every N blocks
    keepTxKeys:         false,     // keep tx keys in DB after match
    blockHashRetention: 10000,     // ring buffer depth for reorg detection
});
```

Returns the number of transaction keys processed.

## Background sync {#background-sync}

Continuously track the tip:

```ts
await client.startBackgroundSync({
    pollInterval: 10000,   // 10 s
    onNewBlock: (height, hash) => {
        console.log('block', height, hash);
    },
    onNewTransaction: (txHash, outputHash, amount) => {
        console.log('received', amount, 'sats via', outputHash);
    },
    onBalanceChange: (newBal, oldBal) => {
        console.log('balance', oldBal, '→', newBal);
    },
    onError: (err) => console.error(err),
});

// Later:
client.stopBackgroundSync();
```

Both backends subscribe to new block headers (Electrum via `blockchain.headers.subscribe`, P2P via the node's `inv` announcements). While subscribed, a backup poll still runs every `max(3 × pollInterval, 30 s)`; if the subscription fails, background sync falls back to polling at `pollInterval`.

## Reorgs {#reorgs}

Since **0.3.0**, `sync()` recovers from reorgs by default (`stopOnReorg: false`). Before each sync it compares the stored block hashes with the backend's, including when the tip height has not moved, so a reorg that only replaces the tip is caught. On a mismatch the sync manager:

1.  Fetches the headers below the mismatch in one batch and finds the fork point, searching back at most `MAX_REORG_DEPTH` (exported, `100`) blocks or `blockHashRetention - 1`, whichever is smaller.
2.  Reverts every tx-keys row, output, spend and block hash at or above the fork, and saves the new sync state, in **one transaction** (`IWalletDB.revertBlocksFrom`). Mempool rows are left alone.
3.  Re-scans forward from the fork on the new chain.

`onProgress` receives `isReorg = true` once after a revert. `isSyncNeeded()` also reports a replaced tip.

Two error classes are exported:

| Error            | When                                                                                                    | Fields                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `ReorgError`     | A reorg was detected with `stopOnReorg: true`. Nothing has been reverted.                                | `info: ReorganizationInfo` (`height`, `oldHash`, `newHash`, `blocksToRevert`) |
| `DeepReorgError` | The fork point could not be found, with either setting. The wallet is left as it was.                    | `lastSyncedHeight`, `searchedDownTo`, `reason`            |

`DeepReorgError.reason` is `'too-deep'` when no common block was found within the depth limit, and `'missing-history'` when the search reached a height with no stored hash. No hashes exist below the wallet's first synced height (its creation or restore height), so a reorg reaching below it is `'missing-history'` however shallow it is. Recover with `resetSyncState()` on the sync manager and a fresh sync:

```ts
import { DeepReorgError } from 'navio-sdk';

try {
    await client.sync();
} catch (e) {
    if (e instanceof DeepReorgError) {
        await client.getSyncManager().resetSyncState();
        await client.sync();
    } else {
        throw e;
    }
}
```

!!! warning "Behaviour change in 0.3.0"
    Before 0.3.0 `stopOnReorg` defaulted to `true` and a plain `sync()` threw a bare `Error` on every reorg, including routine one-block PoS reorgs. `ReorganizationInfo.oldHash` / `newHash` now describe the fork block (at `height`), not the last synced block. Custom `IWalletDB` implementations must add `revertBlocksFrom(height, state)`.

## Sync state

```ts
interface SyncState {
    lastSyncedHeight:  number;
    lastSyncedHash:    string;
    totalTxKeysSynced: number;
    lastSyncTime:      number;  // ms since epoch
    chainTipAtLastSync: number;
}

client.getSyncState();
client.getLastSyncedHeight();
await client.isSyncNeeded();
```

## Tuning

| Option                 | Effect                                                                    |
| ---------------------- | ------------------------------------------------------------------------- |
| `keepTxKeys: false`    | Discard per-block tx keys after processing — saves disk                    |
| `blockHashRetention`   | Ring buffer depth for reorg detection; 10k = ~14 days on 2-min blocks      |
| `saveInterval: 100`    | Commit DB every 100 blocks — lower = more durable, higher = faster         |
| `creationHeight`       | Skip blocks before wallet creation                                         |

## Transparency of sync

The SDK sync manager is `TransactionKeysSync`, exposed via `client.getSyncManager()`. It is swappable — custom backends implement `SyncProvider` and the rest of the pipeline is reusable. See the auto-generated [API reference](api/README.md) for the exact interfaces.
