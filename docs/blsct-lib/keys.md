# Keys

Key-level classes above the raw curve primitives.

## `PublicKey`

Single BLS public key — a wrapper around `Point`.

```ts
import { PublicKey, Scalar } from 'navio-blsct';

const privScalar = Scalar.random();
const pub = PublicKey.fromScalar(privScalar);

pub.toHex();
pub.toBytes();
pub.toPoint();                 // underlying Point
pub.verify(message, signature); // BLS verify
```

## `PublicKeys`

A set of public keys used in aggregate verification. Holds multiple 48-byte pubkeys and supports batched operations.

```ts
import { PublicKeys } from 'navio-blsct';

const set = new PublicKeys([pubA, pubB, pubC]);

// Verify an aggregate signature across multiple signers/messages
set.verifyAggregate(messages, aggregateSignature);
```

## `DoublePublicKey`

The (view, spend) pair — 96 bytes total — defining a BLSCT address. See [the double public key deep dive](../blsct/double-public-key.md) for byte layout.

```ts
import { DoublePublicKey } from 'navio-blsct';

const dpk = DoublePublicKey.fromHex(hex192);
const dpk2 = DoublePublicKey.fromParts(viewPub, spendPub);

dpk.getViewKey();            // PublicKey
dpk.getSpendKey();           // PublicKey
dpk.toBech32m('mainnet');    // 'nav1...'
dpk.toHex();                 // 192 hex chars
dpk.toBytes();               // Uint8Array(96)

// Parse a bech32m address back
const fromAddr = DoublePublicKey.fromBech32m('tnv1...', 'testnet');
```

!!! warning "Browser bech32m limitation"
    On browser WASM, `toBech32m` may return the hex representation instead of proper bech32m — a known limitation tracked upstream.

## `SubAddress`

A derived sub-address wrapping a DPK and its `(account, index)` identifier.

```ts
import { SubAddress, SubAddrId } from 'navio-blsct';

const id = new SubAddrId(0, 0);                 // (account, index)
const sa = SubAddress.derive(masterScalar, id);

sa.getDoublePublicKey();          // DoublePublicKey
sa.getSubAddrId();                // SubAddrId
sa.toBech32m('mainnet');
```

`SubAddrId` stores account and index as signed 32-bit integers — valid negative accounts correspond to change (`-1`) and staking (`-2`) pools.

## Interaction with the SDK

The [SDK `KeyManager`](../sdk/wallet.md) wraps these classes — you normally don't instantiate them directly. Use the low-level classes when:

-   Implementing a custom sub-address scheme.
-   Building a hardware-wallet driver that produces addresses outside the SDK.
-   Verifying signatures in a minimal environment (no wallet state).
