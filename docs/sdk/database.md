# Database & storage

The SDK persists wallet state in SQLite on Node.js and in native IndexedDB in browsers. The adapter is auto-selected based on environment; you can override it.

## Adapters

| Environment | `databaseAdapter`          | Backing store                               | Typical use          |
| ----------- | -------------------------- | ------------------------------------------- | -------------------- |
| Browser     | `indexeddb` (alias `browser`) | Native IndexedDB (`IndexedDBWalletDB`, no WASM) | Web wallets      |
| Node.js     | `better-sqlite3`           | SQLite file on disk, or `:memory:`          | Servers, CLI tools, tests |

`capacitor` and `expo` are reserved in the type for mobile SQLite and are not implemented yet. To force an adapter:

```ts
new NavioClient({
    databaseAdapter: 'better-sqlite3',
    walletDbPath: './wallet.db',    // or ':memory:' for tests
});
```

## Paths

| Adapter                 | `walletDbPath` meaning                                 |
| ----------------------- | ------------------------------------------------------ |
| `better-sqlite3`        | Filesystem path (directory must exist), or `:memory:`. |
| `indexeddb` / `browser` | Logical name — becomes the IndexedDB database name.    |

## Using WalletDB directly

For advanced cases:

```ts
import { WalletDB } from 'navio-sdk';

const db = new WalletDB({ type: 'better-sqlite3' });
await db.open('./wallet.db');

await db.createWallet(50000); // creationHeight
const keyManager = await db.loadWallet();

await db.close();
```

### Memory → file migration

```ts
const memDb = new WalletDB({ type: 'memory' });
await memDb.open(':memory:');
await memDb.createWallet();

// Later:
const persistent = await memDb.migrate('./wallet.db');
```

### Encrypted export / import

```ts
const blob = await db.exportEncrypted('backup-pw');
// ... save to disk / upload to S3 ...

const restored = await WalletDB.loadEncrypted(blob, 'backup-pw');
```

Plaintext export:

```ts
const raw = db.export();  // Uint8Array
const db2 = await WalletDB.loadFromBytes(raw);
```

Check whether a blob is encrypted:

```ts
import { isEncryptedDatabase } from 'navio-sdk';
isEncryptedDatabase(buffer); // boolean
```

## Schema {#schema}

Simplified — see [navio-sdk source](https://github.com/nav-io/navio-sdk/tree/master/src) for the authoritative SQL.

### Key management

| Table              | Columns                                                            |
| ------------------ | ------------------------------------------------------------------ |
| `keys`             | `key_id`, `pub_key`, `priv_key`                                    |
| `crypted_keys`     | `key_id`, `pub_key`, `encrypted_secret`                            |
| `out_keys`         | `out_key_id`, `pub_key`, `priv_key`                                |
| `crypted_out_keys` | `out_key_id`, `pub_key`, `encrypted_secret`                        |
| `view_key`         | `view_key` (blob)                                                  |
| `spend_key`        | `spend_key` (blob)                                                 |
| `master_seed`      | `mnemonic` / `seed` (plaintext or encrypted)                       |
| `hd_chain`         | `chain_index`, `sub_addr_index`, per-account counters              |
| `sub_addresses`    | `(account, index)` → DPK                                           |

### Outputs & sync

| Table               | Columns                                                                              |
| ------------------- | ------------------------------------------------------------------------------------ |
| `wallet_outputs`    | See below                                                                            |
| `tx_keys`           | `(block_height, output_hash)` → tx-key payload (optional, retained if `keepTxKeys`)  |
| `block_hashes`      | Ring buffer of recent block hashes for reorg detection                               |
| `sync_state`        | `last_synced_height`, `last_synced_hash`, `chain_tip_at_last_sync`, `last_sync_time` |
| `wallet_metadata`   | `creation_height`, `creation_time`, `version`                                        |
| `encryption_metadata` | `salt`, `verification_hash`                                                        |
| `output_blinding_keys` | `output_hash` → private blinding scalar of outputs this wallet created (0.2.0+); never exposed through `WalletOutput` |
| `standing_orders`   | Standing orders this wallet published and the inputs they reserve (0.1.35+)          |
| `created_collections` | Token / NFT collections this wallet created                                        |

#### `wallet_outputs`

```sql
CREATE TABLE wallet_outputs (
    output_hash          TEXT PRIMARY KEY,
    tx_hash              TEXT NOT NULL,
    output_index         INTEGER NOT NULL,
    block_height         INTEGER NOT NULL,
    output_data          TEXT NOT NULL,
    amount               INTEGER NOT NULL DEFAULT 0,
    gamma                TEXT NOT NULL DEFAULT '0',
    memo                 TEXT,
    token_id             TEXT,
    blinding_key         TEXT,
    ephemeral_key        TEXT,                        -- 0.2.0+
    spending_key         TEXT,
    is_spent             INTEGER NOT NULL DEFAULT 0,
    spent_tx_hash        TEXT,
    spent_block_height   INTEGER,
    created_at           INTEGER NOT NULL,
    tx_type              TEXT NOT NULL DEFAULT 'received',
    timestamp            INTEGER NOT NULL DEFAULT 0,
    is_staked_commitment INTEGER NOT NULL DEFAULT 0   -- 0.4.0+
);
```

### Migrations

Existing databases are upgraded when opened; no data is rewritten except where noted.

| Version | SQLite (`WalletDB`)                                                                 | IndexedDB (`IndexedDBWalletDB`) |
| ------- | ----------------------------------------------------------------------------------- | ------------------------------- |
| 0.1.35  | `standing_orders` table                                                             | `standingOrders` store, DB v3   |
| 0.2.0   | `ephemeral_key` column (null until re-synced), `output_blinding_keys` table         | —                               |
| 0.4.0   | `is_staked_commitment` column, added and backfilled from `output_data` in one transaction | DB v5                     |

!!! note "Custom `IWalletDB` implementations"
    0.3.0 adds `revertBlocksFrom(height, state)`; 0.4.0 adds `getOutputData(outputHash)` and requires `getBalance()` / `getUnspentOutputs()` to exclude staked commitments. 0.1.33 added `saveSubAddresses`, 0.1.35 the standing-order methods.

Since 0.4.0, `WalletDB` binds the `tokenId` argument of `getBalance`, `getUnspentOutputs` and `getPendingSpentAmount` as a query parameter; upgrade if you pass token ids from untrusted input.

## Browser storage specifics

In browsers the SDK uses `IndexedDBWalletDB`, which stores records natively in IndexedDB (no SQL engine, no WASM). For very large browser wallets, consider:

-   Offloading cold storage to a backend (encrypted export + server-side store).
-   Splitting the wallet — maintain separate NavioClient instances per account.

## Optimisation knobs

| Option                  | Default   | Effect                                                         |
| ----------------------- | --------- | -------------------------------------------------------------- |
| `keepTxKeys`            | `false`   | Keep `tx_keys` rows after processing — larger DB, faster resync |
| `blockHashRetention`    | `10000`   | Cap on `block_hashes` ring buffer                              |
| `saveInterval`          | `100`     | Persist every N blocks during sync                             |
| `creationHeight`        | tip − 100 | Skip history before this block                                 |
