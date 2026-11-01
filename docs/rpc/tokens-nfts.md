# Tokens & NFTs

A tutorial-shaped view of the token and NFT subset of the [BLSCT RPC surface](blsct.md). Use this page when you want a narrative walkthrough; use the [BLSCT commands page](blsct.md) for the auto-generated definitive reference.

## Overview

Navio supports two native asset types:

-   **Tokens** — fungible, with a maximum supply. Balances are hidden via BLSCT commitments.
-   **NFTs** — non-fungible, each with a unique `nft_id` inside a collection, with per-instance metadata.

Both live on the BLSCT transaction format with confidential amounts. An NFT effectively has "balance 1" per `nft_id` — the chain tracks ownership without revealing who owns which id to outside observers.

**Identifier conventions:**

-   **Token / collection id** — 64 hex characters. Identifies a fungible token or an NFT collection. Returned as `tokenId` from `createtoken` / `createnft`.
-   **NFT** — a collection id plus a numeric `nft_id` (subid). The mint and send commands take them as two arguments (`token_id`, `nft_id`). Commands that take a single token string — the `token_id` of a [`createblsctrawtransaction`](blsct.md#createblsctrawtransaction) output and the RFQ / standing-order commands on the [P2P messaging page](p2pmsg.md) — write an NFT as `<64-hex token id>#<subid>`, for example `ba12…7edd#42`, the form `listorders` prints. The subid is plain decimal. NAV is the empty string.

!!! info "Version note"
    The `#<subid>` form in `createblsctrawtransaction` and the RFQ / order RPCs is on master, after v0.2.2. Earlier releases accept only a 64-hex token id there, so they cannot name an NFT.

The SDK normalises both forms — pass either `tokenId: '<64-hex>'` (collection, fungible send) or `tokenId: '<80-hex>'` (specific NFT: collection id followed by the 16-hex subid) or `collectionTokenId + nftId` to [`NavioClient.sendNft`](../sdk/sending.md#send-nft).

!!! warning "`outputHash` is not a txid"
    `createtoken`, `createnft`, `minttoken`, `mintnft`, `sendtokentoblsctaddress` and `sendnfttoblsctaddress` return the output hash of one output they created. Use [`gettxfromoutputhash`](categories/rawtransactions.md#output-hash-lookups) to find the transaction.

## Create a token collection

```bash
navio-cli createtoken '{"name":"MyToken","symbol":"MTK","description":"A utility token"}' 1000000
```

Returns:

```json
{
  "outputHash": "<output hash of the creating output>",
  "tokenId":    "<64-hex token id>"
}
```

The calling wallet becomes the collection owner — only it can mint into the collection.

## Create an NFT collection

```bash
navio-cli createnft '{"name":"Art Collection","description":"Digital art NFTs"}' 100
```

`max_supply` here caps the number of NFTs mintable in this collection (100 in the example).

## Mint tokens

```bash
navio-cli minttoken <token_id> <bech32m_address> 50000
```

`<bech32m_address>` can be a sub-address of the owner wallet or an external address. The minted tokens become confidential outputs addressed to `<bech32m_address>`.

## Mint NFTs

```bash
navio-cli mintnft <collection_token_id> <nft_id> <bech32m_address> '{"name":"Mona Lisa","artist":"Da Vinci"}'
```

`nft_id` must not already be minted in the collection.

## Query balances

```bash
# NAV and all assets
navio-cli getblsctbalance

# Specific token balance
navio-cli gettokenbalance <token_id>

# NFTs owned from a specific collection
navio-cli getnftbalance <collection_token_id>
```

## Transfer

```bash
# Fungible tokens
navio-cli sendtokentoblsctaddress <token_id> <recipient_address> 100 "Optional memo"

# NFT
navio-cli sendnfttoblsctaddress <collection_token_id> <nft_id> <recipient_address> "Optional memo"
```

## Token queries

```bash
# List all tokens known to the node
navio-cli listtokens

# Inspect a specific token
navio-cli gettoken <token_id>

# Wallet-aware variants (v0.2.2+): add an "ismine" flag, true when this wallet created the token and can mint it
navio-cli listwallettokens          # pass true to list only tokens this wallet created
navio-cli getwallettoken <token_id>
```

`listwallettokens` and `getwallettoken` are read-only. They need the wallet to be unlocked, and a wallet without an HD seed (for example one created from an audit key) reports `ismine` false for everything.

## From the SDK

```ts
// Create a collection
const collection = await client.createTokenCollection({
    metadata: { name: 'Token Collection', symbol: 'TOK' },
    totalSupply: 5_000_000,
});

// Mint
const mint = await client.mintToken({
    address: 'tnv1...',
    collectionTokenId: collection.collectionTokenId,
    amount: 123_456,
});

// Transfer
await client.sendToken({
    address: 'tnv1...',
    amount: 25n,
    tokenId: collection.collectionTokenId,
    memo: 'Token payment',
});

// NFTs
const nftCollection = await client.createNftCollection({
    metadata: { collection: 'Artifacts', creator: 'navio' },
    totalSupply: 250,
});

const nftMint = await client.mintNft({
    address: 'tnv1...',
    collectionTokenId: nftCollection.collectionTokenId,
    nftId: 42n,
    metadata: { name: 'Artifact', rarity: 'legendary' },
});

await client.sendNft({
    address: 'tnv1...',
    collectionTokenId: nftCollection.collectionTokenId,
    nftId: 42n,
});
```

See the [SDK tokens guide](../sdk/tokens.md) for the full TypeScript surface.

## Error codes

| Code                          | Meaning                                                       |
| ----------------------------- | ------------------------------------------------------------- |
| `RPC_INVALID_ADDRESS_OR_KEY`  | Invalid address, unknown token id, or wallet not token owner  |
| `RPC_INVALID_PARAMETER`       | Invalid parameter (malformed metadata, wrong nft_id type)     |
| `RPC_WALLET_INSUFFICIENT_FUNDS` | Not enough funds or token balance                            |
| `RPC_WALLET_UNLOCK_NEEDED`    | Wallet is encrypted and locked                                |

## See also

-   [BLSCT RPC commands](blsct.md) — full reference for every token/NFT command and the rest of the BLSCT surface.
-   [Token format on-chain](../blsct/tokens.md) — byte layout, commitments, how token outputs differ from NAV outputs.
-   [Guides → Mint an NFT collection](../guides/mint-nft.md) — end-to-end tutorial.
