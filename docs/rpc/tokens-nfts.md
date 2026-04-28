# Tokens & NFTs

A tutorial-shaped view of the token and NFT subset of the [BLSCT RPC surface](blsct.md). Use this page when you want a narrative walkthrough; use the [BLSCT commands page](blsct.md) for the auto-generated definitive reference.

## Overview

Navio supports two native asset types:

-   **Tokens** — fungible, with a maximum supply. Balances are hidden via BLSCT commitments.
-   **NFTs** — non-fungible, each with a unique `nft_id` inside a collection, with per-instance metadata.

Both live on the BLSCT transaction format with confidential amounts. An NFT effectively has "balance 1" per `nft_id` — the chain tracks ownership without revealing who owns which id to outside observers.

**Identifier conventions:**

-   **Collection token id** — 64-hex. Identifies the collection itself. Returned from `createtoken` / `createnft`.
-   **NFT token id** — 80-hex. Equal to `collection_token_id (64 hex) || subid (16 hex)` in navio-core RPC byte order. Identifies a specific NFT inside a collection.

The SDK normalises both forms — pass either `tokenId: '<64-hex>'` (collection, fungible send) or `tokenId: '<80-hex>'` (specific NFT) or `collectionTokenId + nftId` to [`NavioClient.sendNft`](../sdk/sending.md#send-nft).

## Create a token collection

```bash
navio-cli createtoken '{"name":"MyToken","symbol":"MTK","description":"A utility token"}' 1000000
```

Returns:

```json
{
  "outputHash": "<tx_output_hash>",
  "tokenId":    "<64-hex collection id>"
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

`nft_id` must not already be minted in the collection. The 80-hex full NFT id is `collection_token_id || nft_id_serialised`.

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
```

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
