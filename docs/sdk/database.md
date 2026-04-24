# Database & storage

The SDK persists wallet state in SQLite. Three adapters auto-select based on environment; you can override.

## Adapters

| Environment | Adapter            | Backing store          | Typical use          |
| ----------- | ------------------ | ---------------------- | -------------------- |
| Browser     | `sql.js` (WASM)    | IndexedDB              | Web wallets          |
| Node.js     | `better-sqlite3`   | File on disk           | Servers, CLI tools   |
| Tests       | In-memory          | RAM                    | Unit tests, CI       |

The SDK picks the right adapter automatically. To force one:

```ts
new NavioClient({
    databaseAdapter: 'better-sqlite3',  // or 'browser' / 'indexeddb' / 'memory'
    walletDbPath: './wallet.db',
});
```

## Paths

| Adapter          | `walletDbPath` meaning                                               |
| ---------------- | -------------------------------------------------------------------- |
| `better-sqlite3` | Filesystem path. Directory must exist.                               |
| `browser` / `indexeddb` | Logical name — becomes an IndexedDB database name.            |
| `memory`         | Ignored (or pass `:memory:` for clarity).                            |

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

#### `wallet_outputs`

```sql
CREATE TABLE wallet_outputs (
    output_hash        TEXT PRIMARY KEY,
    tx_hash            TEXT NOT NULL,
    output_index       INTEGER NOT NULL,
    block_height       INTEGER NOT NULL,
    output_data        TEXT NOT NULL,
    amount             INTEGER NOT NULL DEFAULT 0,
    memo               TEXT,
    token_id           TEXT,
    blinding_key       TEXT,
    spending_key       TEXT,
    is_spent           INTEGER NOT NULL DEFAULT 0,
    spent_tx_hash      TEXT,
    spent_block_height INTEGER,
    created_at         INTEGER NOT NULL
);
```

## Browser storage specifics

`sql.js` keeps the DB fully in memory during the session. Changes are debounced and persisted to IndexedDB, so reloads do not lose state. The entire DB blob is stored as a single IndexedDB record — large wallets (many tens of thousands of outputs) can take noticeable time to load.

For very large browser wallets, consider:

-   Offloading cold storage to a backend (encrypted export + server-side store).
-   Splitting the wallet — maintain separate NavioClient instances per account.

## Optimisation knobs

| Option                  | Default   | Effect                                                         |
| ----------------------- | --------- | -------------------------------------------------------------- |
| `keepTxKeys`            | `false`   | Keep `tx_keys` rows after processing — larger DB, faster resync |
| `blockHashRetention`    | `10000`   | Cap on `block_hashes` ring buffer                              |
| `saveInterval`          | `100`     | Persist every N blocks during sync                             |
| `creationHeight`        | tip − 100 | Skip history before this block                                 |
