# Examples

Runnable TypeScript snippets for common flows. Assumes Node.js ≥ 20.

## Create a new wallet + print mnemonic

```ts
import { NavioClient } from 'navio-sdk';

const client = new NavioClient({
    walletDbPath: './new-wallet.db',
    electrum: { host: 'localhost', port: 50005 },
    network: 'testnet',
    createWalletIfNotExists: true,
});

await client.initialize();

const km = client.getKeyManager();
console.log('MNEMONIC (save offline):', km.getMnemonic());

const address = km.getSubAddressBech32m({ account: 0, address: 0 }, 'testnet');
console.log('Receive at:', address);

await client.disconnect();
```

## Restore from mnemonic

```ts
const client = new NavioClient({
    walletDbPath: './restored.db',
    electrum: { host: 'localhost', port: 50005 },
    restoreFromMnemonic: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art ...',
    restoreFromHeight: 50000,
    network: 'testnet',
});

await client.initialize();

await client.sync({
    onProgress: (h, tip) => console.log(`${((h / tip) * 100).toFixed(1)}%`),
});
```

## Restore watch-only from audit key

```ts
const client = new NavioClient({
    walletDbPath: './audit.db',
    electrum: { host: 'localhost', port: 50005 },
    restoreFromAuditKey: '<160-hex audit key>',
    restoreFromHeight: 50000,
    network: 'testnet',
});
await client.initialize();
await client.sync();

console.log('balance:', await client.getBalanceNav(), 'NAV');
// client cannot send — it has no spend key
```

## Use P2P backend

```ts
const client = new NavioClient({
    walletDbPath: './wallet.db',
    backend: 'p2p',
    p2p: { host: 'localhost', port: 33670, network: 'testnet' },
    network: 'testnet',
    createWalletIfNotExists: true,
});
await client.initialize();
await client.sync();
```

## Background sync with notifications

```ts
await client.startBackgroundSync({
    pollInterval: 10000,
    onNewBlock: (h, hash) => console.log('block', h),
    onNewTransaction: (tx, out, amount) => console.log('+', amount),
    onBalanceChange: (newB, oldB) => console.log('balance', oldB, '→', newB),
    onError: (err) => console.error(err),
});

process.on('SIGINT', async () => {
    client.stopBackgroundSync();
    await client.disconnect();
    process.exit(0);
});
```

## Send NAV

```ts
const r = await client.sendTransaction({
    address: 'tnv1...recipient...',
    amount:  100_000_000n,
    memo:    'Coffee',
});
console.log('txid', r.txId, 'fee', Number(r.fee) / 1e8, 'NAV');
```

## Create a token, mint, send

```ts
// 1. Create
const coll = await client.createTokenCollection({
    metadata: { name: 'MyToken', symbol: 'MT' },
    totalSupply: 1_000_000,
});

// 2. Mint to self
const mint = await client.mintToken({
    address: client.getKeyManager().getSubAddressBech32m({ account: 0, address: 0 }, 'testnet'),
    collectionTokenId: coll.collectionTokenId,
    amount: 10_000,
});

// 3. Wait for confirmation (poll, or use background sync)
await new Promise(r => setTimeout(r, 15_000));
await client.sync();

// 4. Send some to a friend
await client.sendToken({
    address: 'tnv1...friend...',
    amount:  100n,
    tokenId: coll.collectionTokenId,
    memo:    'Thanks',
});
```

## Create and transfer an NFT

```ts
const nftColl = await client.createNftCollection({
    metadata: { collection: 'Artifacts' },
    totalSupply: 100,
});

const mint = await client.mintNft({
    address: 'tnv1...self...',
    collectionTokenId: nftColl.collectionTokenId,
    nftId: 1n,
    metadata: { name: 'Artifact #1', rarity: 'common' },
});

await client.sync();

await client.sendNft({
    address: 'tnv1...recipient...',
    collectionTokenId: nftColl.collectionTokenId,
    nftId: 1n,
    memo: 'Gift',
});
```

## Encrypt and back up

```ts
// Encrypt in place
await client.getKeyManager().setPassword('my-secure-password');

// Export encrypted DB
const blob = await client.getWalletDB().exportEncrypted('backup-password');
await (await import('node:fs/promises')).writeFile('wallet-backup.enc', blob);
```

## Aggregated intra-chain swap

Alice wants to swap 100 TokenA for 10 NAV. Bob accepts.

```ts
// Alice side — produce an unbalanced, partially-signed transaction
const aliceOrderHex = /* use createblsctrawtransaction + signblsctrawtransaction
                         via RPC or low-level SDK to build:
                         - spends 100 TokenA
                         - creates 10 NAV output to Alice herself */;

// Publish aliceOrderHex to an off-chain order book or share directly with Bob.

// Bob side — take aliceOrderHex, add own inputs/outputs:
const bobCompletionHex = /* build a transaction that:
                             - spends 10 NAV (Bob's)
                             - creates 100 TokenA output to Bob */;
// Sign bobCompletionHex.

// Aggregate
const combined = client.aggregateTransactions([aliceOrderHex, bobCompletionHex]);
await client.broadcastRawTransaction(combined.rawTx);
console.log('swap tx', combined.txId);
```

See [Concepts → Atomic swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps) for the protocol.

## Web wallet starter (browser)

```ts
// src/wallet.ts (in a Vite app)
import { NavioClient } from 'navio-sdk';

export async function openWallet() {
    const client = new NavioClient({
        walletDbPath: 'web-wallet',       // IndexedDB DB name
        databaseAdapter: 'indexeddb',
        electrum: {
            host: 'electrum.example.com',
            port: 50004,                  // WSS
            ssl:  true,
        },
        network: 'testnet',
        createWalletIfNotExists: true,
    });
    await client.initialize();
    return client;
}
```

See [the navio-sdk `examples/web-wallet/` folder](https://github.com/nav-io/navio-sdk/tree/master/examples/web-wallet) for a complete React-less reference wallet.
