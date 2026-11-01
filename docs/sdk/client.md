# NavioClient

The main entry point to the SDK. Wraps wallet, sync, and transaction construction behind a single object.

## Construction

```ts
import { NavioClient, type NavioClientConfig } from 'navio-sdk';

const client = new NavioClient(config);
```

## `NavioClientConfig`

```ts
interface NavioClientConfig {
    // Required
    walletDbPath: string;

    // Database adapter (auto-detected if omitted:
    // IndexedDB in browsers, better-sqlite3 in Node.js)
    databaseAdapter?: 'indexeddb' | 'browser' | 'better-sqlite3' | 'capacitor' | 'expo';

    // Backend
    backend?: 'electrum' | 'p2p';          // default 'electrum'
    electrum?: {
        host?: string;           // default 'localhost'
        port?: number;           // default 50001
        ssl?: boolean;           // default false
        timeout?: number;        // default 30000
        p2pmsgTimeout?: number;  // RFQ / quote / order broadcasts, default 180000
        clientName?: string;     // default 'navio-sdk'
        clientVersion?: string;  // default '1.4'
    };
    p2p?: {
        host: string;
        port?: number;           // default by network: mainnet 48470, testnet 33670, regtest 18444
        network?: 'mainnet' | 'testnet' | 'regtest';  // default: follows `network`
        timeout?: number;        // request + connect/handshake timeout
        userAgent?: string;
        services?: bigint;       // default NODE_NONE
        debug?: boolean;
        maxHeadersPerRequest?: number;
    };

    // Network
    network?: 'mainnet' | 'testnet' | 'signet' | 'regtest';   // default 'mainnet'

    // Wallet creation / restore
    createWalletIfNotExists?: boolean;
    restoreFromSeed?: string;              // 64-hex master seed
    restoreFromMnemonic?: string;          // 24 BIP-39 words, or a 26-word birthday mnemonic
    restoreFromAuditKey?: string;          // 160-hex audit key
    restoreFromHeight?: number;            // default 0; derived from a birthday mnemonic
    creationHeight?: number;               // default chainTip - 100

    // Outputs and staking
    deterministicBlindingKeys?: boolean;   // default true — see Sending → Output authorship
    minStakeAmount?: bigint;               // override the network's minimum stake
}
```

`minStakeAmount` is only needed on a chain whose minimum stake differs from the network default, such as navio-core's `blsctregtest`. See [Staking](staking.md).

## Lifecycle

```ts
await client.initialize();    // open DB, connect backend, load/create wallet
// ... use the client ...
await client.disconnect();    // close DB, drop connection
```

`initialize` is idempotent but should be called exactly once before any other method.

## Audit key restore {#audit-key-restore}

```ts
const client = new NavioClient({
    walletDbPath: './audit.db',
    electrum: { host: 'localhost', port: 50005 },
    restoreFromAuditKey: '<160-hex>',
    restoreFromHeight: 50000,
    network: 'testnet',
});
await client.initialize();
await client.sync();
// client can see all outputs; cannot sign/send
```

Attempting `sendTransaction` on an audit-only client throws.

## Accessors

```ts
client.getKeyManager();       // KeyManager — sub-addresses, seeds, encryption
client.getWalletDB();         // WalletDB — low-level DB ops
client.getSyncProvider();     // ElectrumSyncProvider | P2PSyncProvider
client.getSyncManager();      // TransactionKeysSync
client.getBackendType();      // 'electrum' | 'p2p'
client.getNetwork();          // 'mainnet' | 'testnet' | ...
client.getConfig();           // the passed-in config
client.isConnected();         // backend status
client.isUsingSubscriptions();// header subscriptions vs polling
```

## Sync

See [Synchronization](sync.md):

```ts
await client.sync(opts);
await client.startBackgroundSync(opts);
client.stopBackgroundSync();
client.isBackgroundSyncActive();
await client.isSyncNeeded();
client.getLastSyncedHeight();
client.getSyncState();
```

## Balances and outputs

See [Balances](balances.md):

```ts
await client.getBalance();
await client.getBalanceNav();
await client.getUnspentOutputs();
await client.getAllOutputs();
await client.getTokenBalance(tokenId);
await client.getTokenOutputs(tokenId);
await client.getAssetBalances();
await client.getTokenBalances();
await client.getNftBalances();
await client.getStakedOutputs();
await client.getStakedBalance();
```

## Sending

See [Sending](sending.md):

```ts
await client.sendTransaction(opts);
await client.sendToMany(opts);
await client.sendToken(opts);
await client.sendNft(opts);
await client.broadcastRawTransaction(rawHex);
const combined = client.aggregateTransactions([hexA, hexB]);

// Output authorship (0.2.0+)
await client.recoverBlindingKey({ txid, vout });
await client.signOutput({ txid, vout, message });
```

## Staking

See [Staking](staking.md) (0.4.0+):

```ts
await client.delegateStake(opts);
await client.unstake(opts);
await client.getStakeDelegations();
client.getMinStakeAmount();
```

## Tokens and NFTs

See [Tokens](tokens.md):

```ts
await client.createTokenCollection(opts);
await client.createNftCollection(opts);
await client.mintToken(opts);
await client.mintNft(opts);
await client.mintNfts(opts);
await client.listCreatedCollections();
```

## Trading

See [Token trading](trading.md): `requestQuote`, `listQuotes`, `acceptQuote`, `cancelQuoteRequest`, `setSwapIntent`, `clearSwapIntent`, `listSwapIntents`, `subscribePendingQuoteRequests`, `replyQuote`, `broadcastOrder`, `listStandingOrders`, `forgetStandingOrder`.

## Chain metadata

```ts
await client.getChainTip();                  // { height, hash }
await client.getCreationHeight();
await client.setCreationHeight(h);
await client.getWalletMetadata();
```

## Error handling

Methods throw on non-recoverable errors. Wrap in try/catch. Typical errors:

-   Invalid config (e.g., unreachable Electrum host) — thrown from `initialize`.
-   Insufficient balance — from `sendTransaction`.
-   Wallet locked — from any send; call `keyManager.unlock(pw)` first.
-   Reorg mid-operation — the SDK handles reorgs during sync, but if one happens while a transaction is being constructed the send can fail and must be retried after next sync.
-   `ReorgError` / `DeepReorgError` — from `sync()`; see [Reorgs](sync.md#reorgs).
