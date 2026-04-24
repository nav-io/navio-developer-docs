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

Connects directly to a `naviod` full node's P2P port using a custom protocol extension that streams transaction keys.

```ts
new NavioClient({
    backend: 'p2p',
    p2p: {
        host: 'node.example.com',
        port: 48470,    // mainnet (testnet uses 43670 in SDK defaults)
        network: 'mainnet',
    },
    // ...
});
```

P2P does not support real-time subscriptions — background sync falls back to polling.

### When to choose which

| Use case                                         | Backend        |
| ------------------------------------------------ | -------------- |
| Lightweight browser wallet                       | Electrum (WSS) |
| Self-hosted with a nearby Electrum server        | Electrum       |
| No Electrum available, have direct node access   | P2P            |
| Low-latency mempool / block events               | Electrum       |

## `sync()` — one-shot

```ts
await client.sync({
    startHeight: 50000,            // default: last synced + 1
    endHeight:   undefined,        // default: chain tip
    onProgress:  (height, tip, blocks, txKeys, isReorg) => {
        console.log(`${height}/${tip} — ${blocks} blocks, ${txKeys} keys, reorg=${isReorg}`);
    },
    stopOnReorg:        true,      // halt on reorg; default true
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

Under Electrum, `pollInterval` is ignored — new headers push via subscription. Under P2P it controls poll frequency.

## Reorgs {#reorgs}

Whenever the backend reports a block hash at a previously-synced height that differs from what the wallet has, the sync manager:

1.  Walks back until it finds a common ancestor.
2.  Rolls wallet DB state back to that ancestor — marks rolled-back outputs as unconfirmed, releases spent markers.
3.  Re-syncs forward on the new chain.

`onProgress(isReorg=true)` fires during the rollback + replay. `onError` fires only on backend-level failures, not on normal reorgs.

Set `stopOnReorg: false` if you want the call to handle reorgs silently; otherwise `sync()` returns control after rollback so you can inspect state.

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
