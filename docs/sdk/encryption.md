# Encryption

Two layers of encryption:

1.  **KeyManager encryption** — encrypts private keys in memory / in the DB with a password. Wallet can be locked/unlocked without re-syncing.
2.  **WalletDB encryption** — encrypts the entire DB blob for portable backups.

## Key derivation

Both layers use:

-   **Argon2id** — 64 MiB memory, 3 iterations, 4-lane parallelism. Resists GPU / ASIC password cracking.
-   **AES-256-GCM** — authenticated encryption with a 12-byte random IV per encryption.
-   **Salt** — 16 random bytes stored alongside the verification hash.
-   **Verification hash** — derived from the password, used to reject wrong passwords without a decryption attempt.

## KeyManager encryption

### `setPassword` {#set-password}

### `lock` {#lock}

### `unlock` {#unlock}

### `changePassword` {#change-password}

```ts
const km = client.getKeyManager();

// Protect a fresh wallet
await km.setPassword('my-secure-password');
km.isEncrypted();  // true
km.isUnlocked();   // true — just-set password leaves wallet unlocked

// Lock — clears cached key from memory
km.lock();
km.isUnlocked();   // false

// Unlock
const ok = await km.unlock('my-secure-password');
if (!ok) { /* wrong password */ }

// Change
await km.changePassword('old-password', 'new-password');
```

A locked wallet can still read public-key state (sub-addresses, audit key) but cannot sign transactions. Attempting `sendTransaction` on a locked wallet throws.

### Encryption parameters for persistence

```ts
const { salt, verificationHash } = km.getEncryptionParams();
// persist alongside the wallet DB

// On restore:
km.setEncryptionParams(savedSalt, savedVerificationHash);
await km.unlock(password);
```

The [WalletDB table](database.md#schema) `encryption_metadata` stores these automatically — you only need the above calls when bypassing the WalletDB wrapper.

## WalletDB encryption {#exportimport-encrypted-snapshots}

For off-host backup or transfer:

### Export {#export}

```ts
const blob = await client.getWalletDB().exportEncrypted('backup-pw');
// Uint8Array — safe to save to disk, upload, email

import fs from 'node:fs/promises';
await fs.writeFile('wallet-backup.enc', blob);
```

Or download in the browser:

```ts
const url = URL.createObjectURL(new Blob([blob]));
const a = document.createElement('a');
a.href = url; a.download = 'wallet-backup.enc';
a.click();
URL.revokeObjectURL(url);
```

### Load {#load}

```ts
import { WalletDB, isEncryptedDatabase } from 'navio-sdk';

const raw = await fs.readFile('wallet-backup.enc');
const buf = new Uint8Array(raw);

if (!isEncryptedDatabase(buf)) throw new Error('not encrypted');

const db = await WalletDB.loadEncrypted(buf, 'backup-pw');
const keyManager = await db.loadWallet();
```

## Stand-alone encryption primitives

The SDK exports the underlying primitives for application-layer use:

```ts
import {
    encrypt, decrypt,
    deriveKey,
    serializeEncryptedData, deserializeEncryptedData,
    createPasswordVerification, verifyPassword,
    randomBytes,
} from 'navio-sdk';

// Encrypt arbitrary bytes
const plaintext = new TextEncoder().encode('secret');
const encrypted = await encrypt(plaintext, 'password');

// Decrypt
const decrypted = await decrypt(encrypted, 'password');
console.log(new TextDecoder().decode(decrypted));  // 'secret'

// Serialise to base64 JSON for storage
const json = JSON.stringify(serializeEncryptedData(encrypted));

// Password verification helper (no data to decrypt)
const salt = randomBytes(16);
const hash = await createPasswordVerification('password', salt);
const isValid = await verifyPassword('password', salt, hash);
```

`encrypt` / `decrypt` accept a password *or* a pre-derived key (from `deriveKey`) — reuse the derived key across multiple encrypt/decrypt calls to avoid recomputing Argon2id.

## Security notes

-   **Password strength matters.** Argon2id is slow, but a weak password (`password123`) is still brute-forceable. Use a password manager; prefer ≥ 20 chars or a high-entropy passphrase.
-   **Salt is not secret.** Store it alongside the ciphertext in the clear.
-   **Verification hash is not the key.** Knowing the verification hash does not allow decrypting the wallet — it only lets attackers accelerate offline password cracking against the same wallet. Store encrypted wallet backups as securely as the mnemonic.
-   **IV reuse is catastrophic** for GCM. The SDK uses a fresh 12-byte random IV per encryption — never re-use one manually.
-   **Memory hygiene.** `km.lock()` clears the cached derived key. In JS you cannot fully zero memory, so best-effort is all we can do; for the strictest environments, destroy the client and re-initialise.
