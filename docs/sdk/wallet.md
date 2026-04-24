# Wallet management

The `KeyManager` owns all secrets and sub-address derivation. Access it from the `NavioClient`:

```ts
const keyManager = client.getKeyManager();
```

## Seeds and mnemonics

### Generate new

```ts
// 24-word mnemonic (default)
const mnemonic = keyManager.generateNewMnemonic();

// Specific word count
const m12 = KeyManager.generateMnemonic(128); // 12 words
const m24 = KeyManager.generateMnemonic(256); // 24 words
```

### Import

```ts
keyManager.setHDSeedFromMnemonic(mnemonic);

// Or raw 32-byte hex seed
const seed = keyManager.generateNewSeed();  // Scalar
keyManager.setHDSeed(seed);
```

### Export (for backup)

```ts
const mnemonic = keyManager.getMnemonic();          // string
const masterSeed = keyManager.getMasterSeedKey();   // Scalar, .serialize() for hex
```

### Validate

```ts
KeyManager.validateMnemonic('abandon abandon abandon ...');  // boolean
```

### Static conversion

```ts
const scalar = KeyManager.mnemonicToScalar(mnemonic);
const recovered = KeyManager.seedToMnemonic(scalar);
```

## Sub-addresses {#sub-addresses}

```ts
// Fetch existing sub-address
const sub = keyManager.getSubAddress({ account: 0, address: 0 });

// Bech32m form — use this to hand out to users
const addrStr = keyManager.getSubAddressBech32m(
    { account: 0, address: 0 },
    'testnet'
);

// Mainnet
const mainAddr = keyManager.getSubAddressBech32m(
    { account: 0, address: 0 },
    'mainnet'
);

// Generate a new sub-address in an account
const { subAddress, id } = keyManager.generateNewSubAddress(0); // account 0

// Create a new sub-address pool
keyManager.newSubAddressPool(0);   // main
keyManager.newSubAddressPool(-1);  // change
keyManager.newSubAddressPool(-2);  // staking
```

Account convention:

| Account | Purpose        |
|:-------:| -------------- |
| `0`     | Main receiving |
| `-1`    | Change         |
| `-2`    | Staking        |

See [Concepts → Wallet formats](../concepts/wallet-formats.md) for background.

### bech32m in browsers

In browser environments using navio-blsct WASM, bech32m encoding may fall back to the raw hex representation of the DPK. This is a known issue tracked in `navio-blsct`. Treat the returned string as opaque — compare it with addresses produced by the same build.

## Key manager primitives {#key-manager}

Low-level operations exposed for custom integrations:

```ts
// View-tag match for an incoming output
const viewTag = keyManager.calculateViewTag(blindingKey);

// Ownership test (returns boolean)
const mine = keyManager.isMineByKeys(blindingKey, spendingKey, viewTag);

// Hash ID — identifies which sub-address the output is addressed to
const hashId = keyManager.calculateHashId(blindingKey, spendingKey);

// Nonce for amount/memo decryption
const nonce = keyManager.calculateNonce(blindingKey);
```

See [BLSCT → output detection](../blsct/detection.md) for how these fit together.

## Audit key {#audit-key}

```ts
// Export the 160-hex audit key
const auditHex = keyManager.getAuditKeyHex();

// Save somewhere; recipient can later restore a watch-only wallet with:
// new NavioClient({ restoreFromAuditKey: auditHex, ... })
```

Spend secret is **not** exposed — an audit wallet cannot sign.

## Encryption

The KeyManager supports wallet-level encryption — see [Encryption](encryption.md) for details.

```ts
// Protect
await keyManager.setPassword('my-password');
keyManager.isEncrypted();  // true
keyManager.isUnlocked();   // true

// Lock (clears cached derived key)
keyManager.lock();
keyManager.isUnlocked();   // false

// Unlock
const ok = await keyManager.unlock('my-password');

// Change password
await keyManager.changePassword('old', 'new');

// For persistent storage
const { salt, verificationHash } = keyManager.getEncryptionParams();
keyManager.setEncryptionParams(salt, verificationHash);  // on restore
```
