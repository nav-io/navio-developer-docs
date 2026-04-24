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

| Kind      | Byte length | Layout                                                        |
| --------- | ----------- | ------------------------------------------------------------- |
| Collection (fungible) | 32 bytes (64 hex)    | Hash of metadata + totalSupply                      |
| NFT item              | 40 bytes (80 hex)    | Collection (32) ‖ nft_id (8, big-endian)             |

Where collection id is `token_hash = H(metadata || totalSupply)`.

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
    -   An output containing the collection metadata and the token pubkey = `token_scalar · G`.
    -   A BLS signature under `token_scalar` committing to the metadata + totalSupply.
3.  The block assigns the output hash as the collection's *on-chain identity*. The `tokenId` returned is `H(metadata || totalSupply)`.

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

## RPC primitives

-   [`createtoken`](../rpc/blsct.md#createtoken) / [`createnft`](../rpc/blsct.md#createnft)
-   [`minttoken`](../rpc/blsct.md#minttoken) / [`mintnft`](../rpc/blsct.md#mintnft)
-   [`sendtokentoblsctaddress`](../rpc/blsct.md#sendtokentoblsctaddress) / [`sendnfttoblsctaddress`](../rpc/blsct.md#sendnfttoblsctaddress)
-   [`gettoken`](../rpc/blsct.md#gettoken) / [`listtokens`](../rpc/blsct.md#listtokens)
-   [`gettokenbalance`](../rpc/blsct.md#gettokenbalance) / [`getnftbalance`](../rpc/blsct.md#getnftbalance)

See the [Tokens & NFTs](../rpc/tokens-nfts.md) tutorial page for a narrative walkthrough.
