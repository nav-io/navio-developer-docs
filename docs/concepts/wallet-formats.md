# Wallet formats

Navio wallets inherit BIP-32 hierarchical deterministic (HD) derivation from Bitcoin and extend it with BLSCT-specific paths, sub-addresses, and a BLSCT-unique **audit key** that enables watch-only wallets.

## Seed types

| Seed type                    | Bytes / words | Where used                                   |
| ---------------------------- | ------------- | -------------------------------------------- |
| Raw master seed              | 32 bytes hex  | Lowest-level restore (`restoreFromSeed`)     |
| BIP-39 mnemonic (12 words)   | 128-bit entropy | Backup, human-transcribable              |
| BIP-39 mnemonic (24 words)   | 256-bit entropy | Default for new wallets in SDK              |
| Audit key                    | 160 hex chars (80 bytes) | Watch-only restore — see below   |
| Birthday mnemonic (26 words) | 24 BIP-39 words + 2 birthday words | Default for new wallets — see below |

All seed formats ultimately produce the same BLS master scalar; the difference is the backup material the user writes down.

### Birthday mnemonic (26 words)

New wallets get a **Navio birthday mnemonic**: the standard BIP-39 24 words followed by two extra words encoding the wallet's creation time, so a restore knows where to start scanning the chain without asking the user for a date:

-   **word 25** — weeks elapsed since the fixed epoch 2026-01-01 00:00 UTC (11 bits ≈ 39 years of range);
-   **word 26** — the first 11 bits of `HMAC-SHA256(key = entropy, msg = "navio-birthday" || week as uint16 BE)`. This binds the birthday to *this* seed and detects a typo in either extra word.

Key derivation uses **only the first 24 words**, so the derived wallet is byte-identical to a plain BIP-39 restore:

-   dropping the two extra words restores the same wallet with a full scan;
-   any BIP-39-compatible wallet can import the 24-word base;
-   the [mnemonic passphrase](#mnemonic-passphrase-the-25th-word) composes normally with the base words.

Restoring from 26 words starts the scan one safety margin before the encoded week — in Navio Electrum and the SDK this maps to a block height via the network's genesis time; in navio-core it sets the wallet birth time so rescans skip older blocks.

Implemented in Navio Electrum v4.9.5+, navio-sdk v0.1.29+, and navio-core ([PR #340](https://github.com/nav-io/navio-core/pull/340)). Shared test vector: entropy `000102…1f` at `t=1783000000` appends `addict render` and decodes to birthday `1782950400`.

### Mnemonic passphrase (the "25th word")

navio-core can optionally extend a BIP-39 mnemonic with a passphrase when deriving the wallet keys — `createwallet`'s `mnemonic_passphrase` argument, or `navio-wallet create -mnemonicpassphrase`. The seed is stretched with the standard BIP-39 KDF (PBKDF2-HMAC-SHA512, 2048 iterations, salt `"mnemonic" + passphrase`).

-   The passphrase is **never stored** — `dumpmnemonic` returns only the mnemonic. The same passphrase must be re-supplied to restore the wallet, so it acts as a second factor: the mnemonic alone is not enough.
-   An **empty** passphrase reproduces the legacy derive-from-entropy path, so mnemonics created without one restore unchanged.
-   Different passphrases over the same mnemonic yield entirely different wallets (plausible-deniability decoys).

!!! warning "Unreleased — post-0.1.3"
    Mnemonic-passphrase support is on the `feat/mnemonic-bip39-passphrase` branch and is not yet in a tagged navio-core release. The `navio-sdk` KeyManager does not expose a passphrase parameter yet. See the [createwallet RPC notes](../rpc/categories/wallet.md#mnemonic-passphrase).

## HD chain structure

Navio's HD chain has three logical roles, represented as three **sub-address pools** distinguished by account index:

-   `account = 0` — **Main** receiving pool. All user-facing addresses come from here.
-   `account = -1` — **Change** pool. Change outputs from sends derive new sub-addresses here.
-   `account = -2` — **Staking** pool. Sub-addresses used by `stakelock` to receive coinstake rewards.

Each pool is further indexed by an *address index*, and each `(account, index)` pair produces a **sub-address** — a double public key derived from the wallet's master view and spend keys via BLSCT-specific key derivation. See [Key derivation](../blsct/keys.md) for the exact formulas.

```
master scalar
├── view secret v (master)
└── spend secret s (master)
    ├── pool 0  (main)
    │   ├── sub 0 → DPK₀,₀ → bech32m "nav1..." address
    │   ├── sub 1 → DPK₀,₁ → new address
    │   └── ...
    ├── pool -1 (change)
    │   ├── sub 0 → change DPK
    │   └── ...
    └── pool -2 (staking)
        └── sub 0 → staking DPK
```

The [SDK `KeyManager`](../sdk/wallet.md) exposes this directly:

```ts
keyManager.newSubAddressPool(0);   // main
keyManager.newSubAddressPool(-1);  // change
keyManager.newSubAddressPool(-2);  // staking

const addr = keyManager.getSubAddressBech32m({ account: 0, address: 0 }, 'mainnet');
```

## Audit keys — watch-only wallets {#audit-keys}

BLSCT separates *viewing* from *spending* at the cryptographic level. The **audit key** is the 80-byte concatenation:

```
audit_key = view_secret_v (32 bytes) || master_spending_pubkey_S (48 bytes)
```

Holding the audit key lets you:

-   Scan every block and identify outputs addressed to any sub-address derived from this wallet (using view tag + the receiver's stealth key derivation).
-   Recover every amount on those outputs (via the shared secret and the nonce).
-   Iterate through sub-address indices deterministically (since `S` is public, sub-address DPKs are computable).

Holding the audit key does **not** let you:

-   Spend anything. Spending requires the master spending *secret*, which is never exposed by the audit key.
-   Derive new sub-addresses outside the published index range (if the sub-address pool has not been advanced).

### Exporting an audit key

Via RPC on a running wallet:

```bash
navio-cli getblsctauditkey
```

Via SDK:

```ts
const auditHex = keyManager.getAuditKeyHex();
// 160-hex-char string: 32 bytes view secret || 48 bytes spending pubkey
```

### Importing an audit key

Via RPC:

```bash
navio-cli importblsctauditkey <hex>
```

Via SDK, creating a watch-only wallet:

```ts
const client = new NavioClient({
    walletDbPath: './audit-wallet.db',
    electrum: { host: 'localhost', port: 50005 },
    restoreFromAuditKey: '<160-hex>',
    restoreFromHeight: 50000,     // block height when the wallet was first active
    network: 'testnet',
});
await client.initialize();
await client.sync();
```

Audit wallets are the standard building block for exchange deposit monitoring, compliance auditing, and multi-wallet dashboards. See [Build a watch-only audit wallet](../guides/audit-wallet.md).

## Encryption

Wallet databases can be encrypted at rest:

-   **Key derivation**: Argon2id — 64 MB memory, 3 iterations, 4-lane parallelism.
-   **Encryption**: AES-256-GCM with 12-byte random IV per encryption.
-   **Salt**: 16 bytes, stored alongside the verification hash.

Encryption is transparent to the application — `NavioClient` exposes [`setPassword`](../sdk/encryption.md#set-password), [`lock`](../sdk/encryption.md#lock), [`unlock`](../sdk/encryption.md#unlock), and [`changePassword`](../sdk/encryption.md#change-password) on the `KeyManager`, plus [`exportEncrypted`](../sdk/encryption.md#export) and [`loadEncrypted`](../sdk/encryption.md#load) on the `WalletDB` for full-database backup/restore. See the [encryption guide](../sdk/encryption.md) for details.

## Wallet creation heights

BLSCT requires scanning every block for outputs addressable by the wallet. To skip irrelevant history, every wallet records a **creation height**:

-   On a new wallet, sync starts from `chainTip - 100` by default.
-   On a restore (seed/mnemonic/audit key), you pass `restoreFromHeight` as the earliest block the wallet might have been funded in.

Setting `creationHeight` too low wastes sync time; too high misses deposits. On an exchange audit wallet, set it to the block where the first deposit occurred (or earlier to be safe).

## Storage backends

The SDK stores wallet state in SQLite. Three adapters are auto-selected by environment:

| Platform | Adapter             | Backing store     |
| -------- | ------------------- | ----------------- |
| Browser  | sql.js (WASM)       | IndexedDB         |
| Node.js  | better-sqlite3      | File on disk      |
| Tests    | sql.js              | Pure in-memory    |

See [SDK database guide](../sdk/database.md) for schema and migration between adapters.

## What's inside the wallet database

Tables (simplified):

| Table                  | Purpose                                           |
| ---------------------- | ------------------------------------------------- |
| `keys`, `out_keys`     | Plaintext key material (when not encrypted)       |
| `crypted_keys`, `crypted_out_keys` | Encrypted key material (when encrypted) |
| `view_key`, `spend_key` | Master view/spend keys                           |
| `hd_chain`             | HD chain counters per pool                        |
| `master_seed`          | BIP-39 mnemonic (or raw seed) for recovery        |
| `sub_addresses`        | `(account, index) → DPK` map                      |
| `wallet_outputs`       | Detected UTXOs with recovered amounts             |
| `wallet_metadata`      | Creation height, creation time, version           |
| `encryption_metadata`  | Argon2id salt + password verification hash        |
| `tx_keys`              | Per-block transaction keys (optional, for resync) |
| `block_hashes`         | Ring buffer of block hashes for reorg detection   |
| `sync_state`           | Last synced height + chain tip                    |

See the [SDK database page](../sdk/database.md#schema) for full column definitions.
