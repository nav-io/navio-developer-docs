# Double public key (DPK)

A **double public key** bundles a wallet's *view* and *spend* pubkeys for a single sub-address into one serialisable object. Addresses in Navio are bech32m-encoded DPKs — not script hashes, not single pubkeys.

## Definition

```
DPK = (V, S)       where  V, S ∈ G_1 (48 bytes each)
```

-   $V$ — the sub-address's view pubkey, $V_{a,i} = v \cdot S_{a,i}$. Used by the receiver to *scan* for incoming outputs.
-   $S$ — the sub-address's spend pubkey, $S_{a,i} = S_{\text{master}} + \text{tweak}(a, i) \cdot G$. Used by the chain to verify the stealth spending signature.

See [Key derivation](keys.md) for how $V$ and $S$ are produced from the master seed.

## Byte encoding

Concatenated compressed $G_1$ points:

```
dpk_bytes = V_compressed (48 bytes) || S_compressed (48 bytes)
total: 96 bytes
```

## Bech32m address encoding

Navio wraps the 96-byte DPK in [bech32m](https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki) for human-readable addresses:

```
<hrp> + "1" + <witness-version> + <data-part> + <checksum>
```

With:

-   **HRP** — `nav` (mainnet), `tnv` (testnet), `snv` (signet), `rnav` (regtest). Defined in [`src/blsct/key_io.h`](https://github.com/nav-io/navio-core/blob/master/src/blsct/key_io.h) under `blsct::bech32_hrp`.
-   **Witness version** — *not used.* Unlike Bitcoin SegWit bech32 encodings, Navio's `bech32_mod` does **not** prepend a witness-version byte. The full 96-byte DPK is expanded into 154 × 5-bit groups and placed directly in the data part.
-   **Data part** — 154 characters encoding the 96-byte DPK (5-bit groups).
-   **Checksum** — bech32m (BIP-350), with a modified polynomial generator suited to the 154-character payload (see [`bech32_mod_gen_poly.md`](https://github.com/nav-io/navio-core/blob/master/src/blsct/bech32_mod_gen_poly.md)).

A typical testnet address:

```
tnv1q9rh…<~160 chars>…q8u30w
```

Mainnet addresses start with `nav1…`, signet with `snv1…`, regtest with `rnav1…`.

### `bech32_mod`

Navio uses a modified bech32m reference implementation (`src/blsct/bech32_mod.cpp` in navio-core) to handle the larger-than-Bitcoin-witness payload size (96 bytes vs. Bitcoin's 20 or 32). The polynomial generator used to compute the checksum is documented in [`src/blsct/bech32_mod_gen_poly.md`](https://github.com/nav-io/navio-core/blob/master/src/blsct/bech32_mod_gen_poly.md).

## Validation

An address is **valid** iff:

1.  bech32m checksum verifies.
2.  HRP matches the target network.
3.  Decoded payload is exactly 96 bytes.
4.  Both 48-byte halves deserialise as valid $G_1$ points (check subgroup and curve membership).

Use [`validateaddress`](../rpc/categories/util.md) or [`KeyManager.validateAddress`](../sdk/wallet.md).

## Browser fallback note

`navio-blsct` on Node.js produces full bech32m addresses. On browser WASM, certain paths may currently return hex-encoded DPKs rather than bech32m strings. This is a known limitation tracked in the library; see the [SDK note](../sdk/wallet.md#bech32m-in-browsers).

## On-chain usage

-   **Outputs never store the DPK directly.** Instead they store the derived ephemeral key $R$ and the stealth spend pubkey $S' = S + \text{HASH}(rV) \cdot G$. The DPK is the receiver-side identifier only.
-   **Wallets store the DPK** in the `sub_addresses` table with `(account, index)` → DPK.
-   **Explorers cannot display the DPK on output pages — it is mathematically impossible to recover.** An output contains only $R$ and $S'$. Reversing $S'$ back to $(V, S)$ requires the recipient's view private key $v$ to compute $\text{HASH}(vR)$ and subtract it from $S'$. Without $v$, no observer (explorer, chain analyst, validator) can derive the DPK from chain data. The DPK is recoverable only by the wallet holder; it surfaces in the UI only when a user copies their own receive address.

## Creating DPKs programmatically

```ts
import { KeyManager, BlsctChain, setChain } from 'navio-sdk';

setChain(BlsctChain.Testnet);

const keyManager = // ... loaded or created from seed
const dpk = keyManager.getSubAddress({ account: 0, address: 0 });
console.log(dpk.toHex());  // 192 hex chars

const address = keyManager.getSubAddressBech32m(
    { account: 0, address: 0 },
    'testnet'
);
console.log(address);      // tnav1…
```

See the [navio-blsct library → keys](../blsct-lib/keys.md#doublepublickey) for the low-level API.
