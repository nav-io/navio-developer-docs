# Backup & restore

A Navio wallet has three independently-useful secrets:

1.  **Mnemonic** (BIP-39) — 12 or 24 words. Regenerates the entire wallet. **Highest priority** for backup.
2.  **Raw master seed** — 32 bytes hex. Lower-level equivalent of the mnemonic.
3.  **Audit key** — 80 bytes. Enables watch-only recovery of balances but **cannot spend**.

Additionally, the full wallet database can be backed up for speed (replay transactions instantly) or for encrypted off-site storage.

## What to back up

| Artifact                           | Reconstructs spending? | Reconstructs balances without spending? | Replay history? |
| ---------------------------------- | :---: | :---: | :---: |
| Mnemonic                           |   ✔   |   ✔   |   —*  |
| Master seed hex                    |   ✔   |   ✔   |   —*  |
| Wallet database (`wallet.dat`)     |   ✔   |   ✔   |   ✔   |
| Encrypted wallet export            |   ✔   |   ✔   |   ✔   |
| Audit key                          |   —   |   ✔   |   —*  |

*The wallet will *discover* history on sync from `restoreFromHeight`, just not instantly.

## Backing up the mnemonic

Via RPC on a running wallet:

```bash
navio-cli dumpmnemonic
```

Via SDK:

```ts
const keyManager = client.getKeyManager();
const mnemonic = keyManager.getMnemonic();
// "abandon ability able about ..."
```

**Store this offline.** Paper, metal backup, air-gapped device. Never on a cloud drive unencrypted.

## Backing up the raw seed

Via SDK:

```ts
const seed = client.getKeyManager().getMasterSeedKey();
console.log(seed.serialize()); // hex string
```

## Backing up the audit key

For watch-only recovery / audit wallets:

```bash
navio-cli getblsctauditkey
```

Or via SDK:

```ts
const auditHex = client.getKeyManager().getAuditKeyHex();
```

The audit key is 160 hex characters (80 bytes). Unlike the mnemonic, it is **safe to give to a trusted auditor**: they can reconcile balances but cannot spend.

## Backing up the wallet database

The fastest restore path. Includes keys, sub-address pools, recovered UTXOs, sync state, and (optionally) transaction keys.

### Via naviod

Stop the daemon (or take a snapshot while it is briefly stopped):

```bash
# stop via your supervisor first (sv stop naviod / rc-service naviod stop / …)
sudo tar -czf wallet-$(date +%Y%m%d).tar.gz \
    /home/navio/.navio/wallets/wallet/wallet.dat
# start again
```

Alternatively, `backupwallet` RPC dumps a consistent copy while the daemon is running:

```bash
navio-cli backupwallet /home/navio/backups/wallet-$(date +%Y%m%d).dat
```

### Via SDK

```ts
// Unencrypted raw dump (Uint8Array)
const raw = client.getWalletDB().export();

// Encrypted dump — AES-256-GCM, password-derived key
const encrypted = await client.getWalletDB().exportEncrypted('backup-password');

// Save to file (Node.js)
import fs from 'node:fs/promises';
await fs.writeFile('wallet-backup.enc', encrypted);
```

See [SDK encryption](../sdk/encryption.md#exportimport-encrypted-snapshots) for the cryptographic details.

## Restoring a wallet

### From mnemonic

```ts
const client = new NavioClient({
    walletDbPath: './restored.db',
    electrum: { host: 'localhost', port: 50005 },
    restoreFromMnemonic: 'abandon abandon abandon …',
    restoreFromHeight: 50000,
    network: 'mainnet',
});
await client.initialize();
await client.sync();
```

### From raw seed

```ts
restoreFromSeed: '<64-hex-chars>',
restoreFromHeight: 50000,
```

### From audit key (watch-only)

```ts
restoreFromAuditKey: '<160-hex-chars>',
restoreFromHeight: 50000,
```

### From encrypted database backup

```ts
import { WalletDB } from 'navio-sdk';
import fs from 'node:fs/promises';

const enc = await fs.readFile('wallet-backup.enc');
const db = await WalletDB.loadEncrypted(new Uint8Array(enc), 'backup-password');
const keyManager = await db.loadWallet();
```

### From plaintext database backup

```ts
const raw = await fs.readFile('wallet-backup.db');
const db = await WalletDB.loadFromBytes(new Uint8Array(raw));
```

## `restoreFromHeight`

Sync always scans forward from a given height. Set `restoreFromHeight` to the earliest block the wallet could have received funds in. Setting it too low wastes time; too high misses early transactions.

For a new wallet, `creationHeight` defaults to `chainTip - 100`.

For a restore:

-   Human memory: "I created this wallet around <date>" → look up that date on a block explorer → use that block height.
-   No memory: use `0` or the known launch height. Will take longer.
-   Exchange audit: the block height of the wallet's first known deposit.

## Disaster recovery matrix

| What you have                                   | What you can recover                                           |
| ----------------------------------------------- | -------------------------------------------------------------- |
| Only mnemonic                                   | Spending wallet. Resync from `restoreFromHeight`.              |
| Only audit key                                  | Watch-only wallet. Balances and history, no spending.          |
| Encrypted DB backup + password                  | Full wallet instantly. No resync.                              |
| Unencrypted DB backup                           | Full wallet instantly.                                         |
| Mnemonic + password of currently-encrypted DB   | Either path works. Mnemonic is longer; DB is instant.          |
| Nothing                                         | Nothing. **Mnemonic backups are mandatory.**                   |
