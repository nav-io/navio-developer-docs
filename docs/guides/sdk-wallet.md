# Build a wallet with navio-sdk

Goal: a Node.js CLI that creates a wallet, syncs to the chain, shows balance, and sends NAV. ~100 lines of code.

## Prereqs

-   `naviod` running locally on testnet, or an Electrum server you trust.
-   Node.js ≥ 20.19.
-   A fresh project directory.

```bash
mkdir navio-wallet-cli && cd navio-wallet-cli
npm init -y
npm install navio-sdk
npm install -D typescript tsx @types/node
npx tsc --init --target ES2022 --module nodenext --moduleResolution nodenext --esModuleInterop --strict
```

## The CLI

`src/index.ts`:

```ts
import { NavioClient } from 'navio-sdk';
import { argv, exit } from 'node:process';

const DB_PATH = './wallet.db';
const ELECTRUM = { host: 'localhost', port: 50005, ssl: false };

async function open(createIfMissing = false) {
    const client = new NavioClient({
        walletDbPath: DB_PATH,
        electrum: ELECTRUM,
        network: 'testnet',
        createWalletIfNotExists: createIfMissing,
    });
    await client.initialize();
    return client;
}

async function cmdCreate() {
    const client = await open(true);
    const km = client.getKeyManager();
    console.log('MNEMONIC (write this down):');
    console.log(km.getMnemonic());
    console.log();
    const addr = km.getSubAddressBech32m({ account: 0, address: 0 }, 'testnet');
    console.log('Receive address:', addr);
    await client.disconnect();
}

async function cmdSync() {
    const client = await open();
    await client.sync({
        onProgress: (h, tip) => {
            process.stdout.write(`\rsync ${h}/${tip} (${((h / tip) * 100).toFixed(1)}%)  `);
        },
    });
    process.stdout.write('\n');
    await client.disconnect();
}

async function cmdBalance() {
    const client = await open();
    const nav = await client.getBalanceNav();
    const utxos = await client.getUnspentOutputs();
    console.log(`${nav.toFixed(8)} NAV in ${utxos.length} UTXOs`);
    await client.disconnect();
}

async function cmdSend(address: string, amountNav: string) {
    const client = await open();
    const sats = BigInt(Math.round(parseFloat(amountNav) * 1e8));
    const res = await client.sendTransaction({ address, amount: sats });
    console.log('sent:', res.txId);
    console.log('fee: ', Number(res.fee) / 1e8, 'NAV');
    await client.disconnect();
}

const [, , cmd, ...rest] = argv;

try {
    switch (cmd) {
        case 'create':  await cmdCreate(); break;
        case 'sync':    await cmdSync(); break;
        case 'balance': await cmdBalance(); break;
        case 'send':    await cmdSend(rest[0], rest[1]); break;
        default:
            console.log('usage: wallet <create|sync|balance|send <addr> <amount>>');
            exit(1);
    }
} catch (e) {
    console.error((e as Error).message);
    exit(1);
}
```

`package.json` scripts:

```json
{
    "scripts": {
        "wallet": "tsx src/index.ts"
    }
}
```

## Use it

```bash
npm run wallet create
# MNEMONIC: abandon ability ... (write down!)
# Receive address: tnv1...

# Get some testnet NAV via /faucet in Discord, then:

npm run wallet sync
# sync 123456/123500 (100.0%)

npm run wallet balance
# 10.00000000 NAV in 1 UTXOs

npm run wallet send tnv1...recipient... 1
# sent: <txid>
# fee: 0.00010000 NAV
```

## Extensions

-   Add `restore` command accepting a mnemonic — pass `restoreFromMnemonic` + `restoreFromHeight` to the config.
-   Add `watch` command that runs `startBackgroundSync` and prints new-block / new-tx events.
-   Add `encrypt` + `unlock` — call `km.setPassword(pw)` / `km.unlock(pw)`.
-   Add `tokens` listing asset balances via `client.getAssetBalances()`.
-   Replace Electrum with direct P2P — switch the config.

All APIs used here are documented in the [SDK section](../sdk/index.md).
