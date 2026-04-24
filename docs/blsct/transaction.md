# Transaction format

On-wire BLSCT transaction layout. Annotations are simplified — the canonical serialisation is defined in `src/primitives/transaction.h`, `src/blsct/wallet/txfactory*.h`, and `src/blsct/range_proof/` in [navio-core](https://github.com/nav-io/navio-core).

## CTransaction

```
CTransaction (BLSCT)
├── nVersion           int32      BLSCT version marker
├── vin[]              CTxIn[]    (see below)
├── vout[]             CTxOut[]   BLSCT outputs — see "Output construction"
├── nLockTime          uint32     standard locktime
├── txSignature        48 bytes   aggregated BLS signature
├── balanceProof       bytes      aggregated Bulletproofs(+)+ range proofs
└── tokenData          optional   token-creation / mint metadata + signature
```

## CTxIn

```
CTxIn
├── prev_out           32 bytes   output_hash being spent (NOT txid:vout)
├── scriptSig          varbytes   input-level script data (standard scripts, HTLC unlock)
└── nSequence          uint32     sequence number (BIP-68 relative locktime)
```

Note: signatures are **not** in `scriptSig` — they are aggregated into `txSignature`.

## CTxOut

Defined in [`src/primitives/transaction.h`](https://github.com/nav-io/navio-core/blob/master/src/primitives/transaction.h) at line 228 (class) and line 156 (`CTxOutBLSCTData`). Members (in-memory):

```
CTxOut
├── nValue             CAmount (int64)   0 for BLSCT outputs (amount hidden in commitment)
├── scriptPubKey       CScript           output-level script (contains stealth spend script)
├── blsctData          CTxOutBLSCTData
├── tokenId            TokenId           null / 32 bytes (fungible) / 40 bytes (NFT)
└── predicate          VectorPredicate   empty unless PREDICATE_MARKER set

CTxOutBLSCTData
├── spendingKey        MclG1Point (48 bytes)   S' — stealth spend pubkey
├── ephemeralKey       MclG1Point (48 bytes)
├── blindingKey        MclG1Point (48 bytes)   R
├── rangeProof         bulletproofs_plus::RangeProof<Mcl>   Bulletproofs++
└── viewTag            uint16_t (2 bytes)      τ
```

Wire-level serialisation order differs from struct-member order and uses a sentinel+flags prefix — see [output on-chain layout](outputs.md#wire-serialisation-order).

### outputHash

Computed as:

```
output_hash = SHA256(SHA256(
    serialize(nValue, scriptPubKey, tokenId, blsctData)
))
```

The output hash is the canonical identifier — see [outpoint model](../concepts/outpoint.md). It is stored in the block's tx-keys index for efficient sync.

## Aggregated signature

Covers:

-   Every per-input authorisation.
-   Balance proof (inputs − outputs − fee balance).
-   Token / NFT authorisation where applicable.

Verification batches these into one pairing-product equation per transaction. At block validation, transactions can be batched together for even cheaper amortised cost.

## Token-creation extras

When `tokenData` is present:

```
tokenData
├── token_pubkey       48 bytes    Collection owner's BLS token-signing pubkey
├── metadata           map<str,str>
├── totalSupply        int64
├── mintedNft          (optional) uint64  — for mintnft, the nft_id being minted
├── mintedMetadata     (optional) map<str,str>
└── tokenSig           48 bytes    BLS signature under token_scalar committing to above
```

Consensus verifies `tokenSig` against `token_pubkey`. The computed `token_id` is `H(metadata || totalSupply)`.

## Non-BLSCT fallback outputs

Some outputs remain transparent:

-   Genesis-time bootstrap outputs (transparent), used to seed the initial PoPS staker set on testnet cuts.
-   Height-1 bootstrap output (75M NAV on testnet).
-   OP_RETURN burn outputs.

These use the inherited Bitcoin `CTxOut` without `blsctData`. They appear alongside BLSCT outputs in the same transaction only in special consensus-level cases (coinbase, coinstake).

## Aggregated transactions

Navio supports combining multiple independently-authored signed transactions into one: concatenate inputs, concatenate outputs, sum signatures, re-aggregate balance proofs. See [`navio-blsct` → `CTx.aggregateTransactions`](../blsct-lib/transactions.md#ctx-aggregation) and [`NavioClient.aggregateTransactions`](../sdk/sending.md#aggregate-transactions).

## Size budget (typical)

| Component                        | Bytes (approx) |
| -------------------------------- | -------------- |
| Transaction header               | ~12            |
| Per input                        | ~50            |
| Per output (BLSCT, NAV)          | ~850 (incl. range proof share) |
| Per output (token, +token_id)    | ~885           |
| Aggregated tx signature          | 48             |
| Balance proof (shared)           | ~100–200       |

A typical 2-in / 2-out BLSCT NAV transaction is around 2–3 KB — competitive with Bitcoin P2WSH txs but with full amount privacy.

## Serialisation reference

-   `src/primitives/transaction.h` — `CTransaction`, `CTxIn`, `CTxOut` base types.
-   `src/blsct/wallet/verification.cpp` — the verification pipeline.
-   `src/blsct/tokens/*` — token-specific fields.
-   [`navio-blsct` `CTx` class](../blsct-lib/transactions.md#ctx) — TypeScript bindings.

For decoding a tx via RPC, use [`decodeblsctrawtransaction`](../rpc/blsct.md#decodeblsctrawtransaction) — returns the JSON view of every field.
