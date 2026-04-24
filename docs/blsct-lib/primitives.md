# Primitives

Curve-level primitives exposed by `navio-blsct`. See the [BLS12-381 curve page](../blsct/curve.md) for conceptual background.

## `Scalar` {#scalar}

A field element in $\mathbb{F}_r$ — 32 bytes, little-endian. Used as private keys, blinding factors, nonces.

```ts
import { Scalar } from 'navio-blsct';

const a = Scalar.random();              // CSPRNG-sourced
const b = Scalar.fromHex('ab...');      // parse, reduce mod r
const c = Scalar.fromBigInt(42n);
const d = Scalar.zero();
const e = Scalar.one();

a.toHex();            // "ab..."
a.toBigInt();         // bigint
a.toBytes();          // Uint8Array(32)

// Arithmetic — returns a new Scalar
const sum  = a.add(b);
const diff = a.sub(b);
const prod = a.mul(b);
const neg  = a.negate();
const inv  = a.invert();     // throws if zero

// Comparison
a.equals(b);          // boolean
```

## `Point` {#point}

A $G_1$ element — 48 bytes compressed. Used for public keys, commitments, Bulletproofs generators.

```ts
import { Point, Scalar } from 'navio-blsct';

const g = Point.generator();
const p = Point.random();
const q = Point.fromHex('ab...');
const r = Point.fromScalar(Scalar.random());   // r · G
const inf = Point.identity();                  // point at infinity

p.toHex();            // "ab..." (96 hex chars)
p.toBytes();          // Uint8Array(48)

// Group operations
const a = p.add(q);
const s = p.sub(q);
const d = p.double();
const n = p.negate();
const m = p.mul(Scalar.random());    // scalar multiplication

p.isIdentity();       // boolean
p.isValid();          // on-curve + in correct subgroup
p.equals(q);
```

## `Signature` {#signature}

A BLS signature — a compressed 48-byte $G_1$ element.

```ts
import { Signature } from 'navio-blsct';

const sig = Signature.fromHex('ab...');
sig.toHex();
sig.toBytes();

// Aggregation
const agg = Signature.aggregate([sig1, sig2, sig3]);

// Verification done at higher level via navio-blsct's key classes or navio-sdk
```

For complete verification signatures are paired with a `PublicKey` / `PublicKeys`; see [Keys](keys.md).

## `Script` {#script}

A Bitcoin-style script with Navio-specific opcode extensions (notably `OP_BLSCHECKSIG = 0xbb`).

```ts
import { Script } from 'navio-blsct';

const s = Script.fromHex('ab...');
s.toHex();
s.toBytes();

// Compose (higher-level helpers in navio-sdk)
s.pushData(bytes);
s.pushInt(42);
s.pushOpcode(Script.OP_BLSCHECKSIG);
```

## Determinism

All methods are deterministic except `Scalar.random()` and `Point.random()` — these use a CSPRNG (WebCrypto on browser / `crypto.randomBytes` on Node). All serialisation / deserialisation is canonical: round-trips produce identical bytes.

## Error handling

Operations on invalid inputs throw synchronously:

-   `Point.fromHex` on off-curve / wrong-subgroup bytes.
-   `Scalar.invert` on zero.
-   `Signature.aggregate` on empty array.

Wrap in try/catch; all errors are standard `Error` instances with descriptive messages.
