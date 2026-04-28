# SDK quickstart

## Install

```bash
npm install navio-sdk
```

Node.js ≥ 20.19 required. Browser requires a bundler supporting the `browser` exports field (Vite, Webpack ≥ 5, esbuild).

## Create a wallet

```ts
import { NavioClient } from 'navio-sdk';

const client = new NavioClient({
    walletDbPath: './my-wallet.db',
    backend: 'electrum',
    electrum: { host: 'localhost', port: 50005, ssl: false },
    network: 'testnet',
    createWalletIfNotExists: true,
});

await client.initialize();

// Save the mnemonic somewhere safe
const keyManager = client.getKeyManager();
console.log('MNEMONIC:', keyManager.getMnemonic());

// Get a receive address
const address = keyManager.getSubAddressBech32m(
    { account: 0, address: 0 },
    'testnet'
);
console.log('Receive address:', address); // tnv1...
```

## Sync the wallet

```ts
await client.sync({
    onProgress: (h, tip, blocks, txKeys) => {
        console.log(`${((h / tip) * 100).toFixed(1)}% — ${blocks} blocks`);
    },
});
```

## Check balance

```ts
const balanceSats = await client.getBalance();     // bigint, in satoshis
const balanceNav = await client.getBalanceNav();   // number, with 8 decimals
console.log(`${balanceNav.toFixed(8)} NAV`);
```

## Send a transaction

```ts
const result = await client.sendTransaction({
    address: 'tnv1...destination...',
    amount:  100_000_000n,        // 1 NAV in satoshis
    memo:    'Coffee',
});
console.log('txid:', result.txId);
```

## Clean shutdown

```ts
await client.disconnect();
```

## Regtest dev loop

The fastest local iteration loop:

```bash
# One shell
naviod -regtest -txindex=1 -server=1 -rpcuser=u -rpcpassword=p

# Another shell
navio-cli -regtest generatetoaddress 101 $(navio-cli -regtest getnewaddress)
```

And in your test code:

```ts
const client = new NavioClient({
    walletDbPath: ':memory:',
    databaseAdapter: 'memory',
    backend: 'p2p',
    p2p: { host: 'localhost', port: 18444, network: 'regtest' },
    network: 'regtest',
    createWalletIfNotExists: true,
});
```

Use `generatetoaddress` from `navio-cli` to mine blocks on demand; the SDK's sync picks them up in seconds.

## Next steps

-   Full client configuration: [NavioClient](client.md)
-   Restoring from seed / mnemonic / audit key: [Wallet management](wallet.md)
-   Background sync: [Synchronization](sync.md#background-sync)
-   Tokens: [Tokens & NFTs](tokens.md)
-   End-to-end examples: [Examples](examples.md)
