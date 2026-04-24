# Privacy primitives

Bulletproofs-backed primitives and token metadata.

## `RangeProof` {#rangeproof}

Bulletproofs (or Bulletproofs++) range proof showing a committed amount is in $[0, 2^{64})$. See the [range proofs deep dive](../blsct/range-proofs.md).

```ts
import { RangeProof, Scalar } from 'navio-blsct';

// Build — typically done by higher-level tx construction, not manually
const rp = RangeProof.prove({
    amount: 100_000_000n,
    blindingFactor: Scalar.random(),
    // ... commitment, generators
});

// Serialise
rp.toHex();
rp.toBytes();

// Parse + verify (standalone)
const parsed = RangeProof.fromHex(hex);
const ok = parsed.verify(commitment);
```

Aggregated proofs over multiple outputs share most of the structure; use `RangeProof.proveAggregate([...])`.

## `AmountRecoveryReq` / `AmountRecoveryRes` {#amount-recovery}

Shared-secret-based amount decryption for incoming outputs. Usually wrapped by the SDK, but exposed for custom flows.

```ts
import { AmountRecoveryReq, AmountRecoveryRes } from 'navio-blsct';

const req = new AmountRecoveryReq({
    blindingKey:    R,                 // Point — from output
    spendingKey:    SPrime,            // Point — from output
    viewSecret:     vScalar,           // Scalar — wallet's view secret
});

const res = AmountRecoveryRes.compute(req);
// res.isMine (boolean), res.amount (bigint), res.memo (string), res.gamma (Scalar)
```

Used internally during [output detection](../blsct/detection.md).

## `TokenId`

On-wire identifier for a token or NFT. Wraps the 32-byte collection hash, optionally with an 8-byte NFT subid.

```ts
import { TokenId } from 'navio-blsct';

const collection = TokenId.fromCollectionHash(hashHex64);
const nft = TokenId.fromCollectionAndSubid(hashHex64, 42n);

collection.toHex();     // 64 hex
nft.toHex();            // 80 hex
nft.getCollection();    // 64 hex prefix
nft.getSubid();         // bigint
nft.isNft();            // true
```

## `TokenInfo`

Collection metadata as broadcast via `createtoken` / `createnft`.

```ts
import { TokenInfo } from 'navio-blsct';

const info = new TokenInfo({
    metadata: { name: 'My Token', symbol: 'MT' },
    totalSupply: 5_000_000n,
    publicKey: tokenPub,   // Point — collection owner's token-signing pubkey
});

info.getId();             // 64-hex collection id (H(metadata || totalSupply))
info.toBytes();
info.toJSON();
```

## `HashId`

Lookup key mapping an on-chain output back to a sub-address. Computed as a hash over the output's blinding key and stealth spending key.

```ts
import { HashId } from 'navio-blsct';

const h = HashId.compute({ blindingKey: R, spendingKey: SPrime });
h.toHex();
```

Wallets maintain a `hashId → (account, index)` lookup to accelerate repeat scans.

## `stringMapUtil`

Utility for the `{string → string}` metadata format used by tokens and NFTs. Canonicalises serialisation order so the chain's `H(metadata)` is stable.

```ts
import { encodeStringMap, decodeStringMap } from 'navio-blsct';

const bytes = encodeStringMap({ name: 'X', rarity: 'rare' });
const map = decodeStringMap(bytes);
```
