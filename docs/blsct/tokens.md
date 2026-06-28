# Token format

Tokens and NFTs in Navio are **BLSCT outputs with a non-null `token_id`**. They reuse every privacy primitive of a NAV BLSCT output (stealth address, Pedersen commitment, range proof) and add a small identifier in cleartext that tells the chain "this output is of this asset".

## Why token_id is in cleartext

If `token_id` were hidden, the chain could not enforce per-asset balance (inputs of TokenA ≠ outputs of TokenA + fee). Pedersen commitments add amounts; they do not distinguish assets. Consensus requires partitioning by asset.

The cleartext `token_id` reveals **which asset is moving** but not:

-   Who sent it.
-   Who received it.
-   How much.
-   Whether this is the same asset as the one in another transaction (only the token_id bytes are the same; the output is unlinkable to the recipient).

## Collection token id vs. NFT token id

Navio encodes two things in one format:

The on-chain `TokenId` (`src/ctokens/tokenid.h`) is a struct of two fields:

```cpp
class TokenId {
    uint256  token;   // 32-byte collection id
    uint64_t subid;   // NFT item id; UINT64_MAX sentinel == "not an NFT"
};
```

| Kind      | Fields set                                  | Hex form                                |
| --------- | ------------------------------------------- | --------------------------------------- |
| Collection (fungible) | `token` set, `subid = UINT64_MAX` | 64 hex (the `token` field alone)  |
| NFT item              | `token` set, `subid` = item index | 80 hex (`token` 32 B ‖ `subid` 8 B) |

The collection id is **the hash of the collection's token public key**, not a hash of the metadata. At `createtoken` / `createnft` execution the chain computes `hash = predicate.GetPublicKey().GetHash()` and keys the token entry under it (`ExecutePredicate` in `src/blsct/tokens/predicate_exec.cpp`). Because the id is bound to the issuer's token-signing key — not to the metadata — two issuers with identical metadata and supply get **distinct** collection ids, and there is no metadata-collision surface.

For a fungible send, the SDK accepts either:

-   **64-hex token_id** → understood as the collection id, treated as fungible
-   **80-hex token_id** → normalised to its 64-hex prefix (since fungible doesn't use nft_id)

For an NFT send, pass either:

-   **80-hex token_id** (full), or
-   **collectionTokenId (64) + nftId (bigint)** pair (the SDK combines them).

See [SDK tokens guide](../sdk/tokens.md#token-ids).

## Token creation

A `createtoken` / `createnft` transaction:

1.  The creator wallet derives a **token-signing key** from its master spending secret under a domain-separation tag specific to the token id.
2.  Publishes a transaction with:
    -   Sufficient NAV input to cover the fee.
    -   A `CreateToken` predicate carrying the collection metadata, `totalSupply`, and the token pubkey `token_scalar · G`.
    -   A BLS signature under `token_scalar` committing to the metadata + totalSupply.
3.  At block validation the chain keys the collection under `hash = tokenPubKey.GetHash()` — the 32-byte `token` field of `TokenId`. The returned `tokenId` is therefore the hash of the token public key, and minting authority is whoever holds `token_scalar`.

Only transactions signed under the collection's token-signing key can mint into it later. Lose the wallet, lose the ability to mint.

## Mint transaction

`minttoken` / `mintnft`:

1.  Takes `tokenId`, destination address, and amount or nft_id.
2.  Builds a BLSCT output addressed to the destination's sub-address, with `token_id` set.
3.  Signs with the collection's token-signing key (proves authorisation) + the usual per-input and balance signatures.
4.  Broadcasts. The new output is now spendable by the recipient.

## Transfer

Transferring tokens uses exactly the same mechanism as NAV — stealth address, commitment, range proof — except:

-   The output's `token_id` is the collection id (for fungible) or full 80-hex NFT id (for non-fungible).
-   Change outputs also carry the same `token_id`.
-   The balance proof partitions inputs and outputs by `token_id`: for each asset present, in − out − fee = 0 (fees are NAV-only; token outputs must sum to zero change).

`sendtokentoblsctaddress` and `sendnfttoblsctaddress` in the [BLSCT RPC](../rpc/blsct.md) handle this automatically.

## NFT metadata encoding

Two metadata maps per NFT:

-   **Collection metadata** — set at `createnft` time. Applies to the collection as a whole.
-   **Per-NFT metadata** — set at `mintnft` time. Applies to that one NFT.

Both are `{string → string}` maps, serialised in the output. The receiver recovers them via their audit key / view key (same mechanism as amount recovery).

Typical conventions:

```json
{
    "name":        "Mona Lisa",
    "description": "Digital masterpiece",
    "artist":      "Da Vinci",
    "image":       "ipfs://bafybei...",
    "rarity":      "legendary"
}
```

Implementers are free to use any schema — there is no enforced spec. Ecosystem conventions (OpenSea-style `attributes`, ERC-721 `tokenURI` patterns) are recommended for interoperability with external tooling.

## On-chain cost

Tokens add a small per-output overhead (typically 32–40 bytes for `token_id` plus any per-NFT metadata). NFT mints with rich metadata can be larger, but the amount is bounded by block size limits.

## Security invariants

Consensus rules enforced at `CreateToken` / mint validation (`ExecutePredicate` in `src/blsct/tokens/predicate_exec.cpp`) and in `TokenEntry::Mint` (`src/blsct/tokens/info.h`). These were hardened by recent navio-core fixes; a violating block is rejected.

| # | Invariant | Where | Rationale |
| - | --------- | ----- | --------- |
| #286 | On `CreateToken`: `info.type` must be `TOKEN` (0) or `NFT` (1); `info.nTotalSupply >= 0`; and for `TOKEN` type, `nTotalSupply` must satisfy `MoneyRange()` (≤ `MAX_MONEY`). | `ExecutePredicate` | An unknown type serialises no supply state, leaving the token unmintable; a negative or oversized supply breaks the mint bounds checks. |
| #285 | A `MintToken` predicate executes only against a `TOKEN`-type entry; `MintNft` only against an `NFT`-type entry. A type mismatch is rejected. | `ExecutePredicate` | `TokenEntry` serialises `nSupply` only for `TOKEN` entries and `mapMintedNft` only for `NFT` entries. A mismatched mint mutates in-memory state that is never persisted, so the supply cap resets to 0 on block reload — silent inflation. |
| #284 | An NFT mint's `nftId` must satisfy `0 <= nftId < nTotalSupply`, compared in the unsigned (`uint64_t`) domain. | `ExecutePredicate` | The previous code cast `nftId` to a signed `CAmount`, letting ids ≥ 2⁶³ go negative and bypass the upper-bound check. |
| #281 | `TokenEntry::Mint` enforces the supply cap without signed-overflow UB: it checks `amount <= nTotalSupply - nSupply` (and `amount >= -nSupply` on disconnect) instead of computing `amount + nSupply` first; all operands are required to be in `MoneyRange`. | `TokenEntry::Mint` | Computing the sum before the comparison could overflow signed `CAmount` (undefined behaviour) and bypass the cap. |

Together these guarantee that a token's declared `nTotalSupply` is a hard, persisted ceiling: the entry's type is fixed and well-formed at creation, mints can only target a matching and correctly serialised entry, and the running supply can never exceed the cap or wrap around — whether checked at mint time or replayed on reload.

## RPC primitives

-   [`createtoken`](../rpc/blsct.md#createtoken) / [`createnft`](../rpc/blsct.md#createnft)
-   [`minttoken`](../rpc/blsct.md#minttoken) / [`mintnft`](../rpc/blsct.md#mintnft)
-   [`sendtokentoblsctaddress`](../rpc/blsct.md#sendtokentoblsctaddress) / [`sendnfttoblsctaddress`](../rpc/blsct.md#sendnfttoblsctaddress)
-   [`gettoken`](../rpc/blsct.md#gettoken) / [`listtokens`](../rpc/blsct.md#listtokens)
-   [`gettokenbalance`](../rpc/blsct.md#gettokenbalance) / [`getnftbalance`](../rpc/blsct.md#getnftbalance)

See the [Tokens & NFTs](../rpc/tokens-nfts.md) tutorial page for a narrative walkthrough.
