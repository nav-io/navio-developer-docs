# Tokens & NFTs (SDK)

This page mirrors the [RPC Tokens & NFTs](../rpc/tokens-nfts.md) walkthrough but from the TypeScript SDK. See [BLSCT → Token format](../blsct/tokens.md) for the on-chain byte layout.

## Token ids {#token-ids}

| Kind                  | Length      | Example                                                         |
| --------------------- | ----------- | --------------------------------------------------------------- |
| Collection (fungible) | 64 hex      | `abcd1234...000000` (32 bytes)                                 |
| NFT item              | 80 hex      | `<64-hex collection>...<16-hex subid>` (40 bytes)              |

SDK methods that accept `tokenId` normalise both forms for fungible sends; NFT sends need either the full 80-hex id or the `collectionTokenId + nftId` pair.

## Create a token collection

```ts
const collection = await client.createTokenCollection({
    metadata: { name: 'My Token', symbol: 'MYT', description: '...' },
    totalSupply: 5_000_000,
});
console.log('collectionTokenId:', collection.collectionTokenId);  // 64 hex
```

`CreateCollectionResult`:

```ts
interface CreateCollectionResult {
    txId: string;
    collectionTokenId: string;   // 64-hex
    fee: bigint;
}
```

## Create an NFT collection

```ts
const nftCollection = await client.createNftCollection({
    metadata: { collection: 'Artifacts', creator: 'me' },
    totalSupply: 250,            // cap on NFTs mintable
});
```

## Mint a token

```ts
const mint = await client.mintToken({
    address:           'tnav1...recipient...',
    collectionTokenId: collection.collectionTokenId,
    amount:            123_456,  // bigint or number
});
```

## Mint an NFT

```ts
const nftMint = await client.mintNft({
    address:           'tnav1...recipient...',
    collectionTokenId: nftCollection.collectionTokenId,
    nftId:             42n,
    metadata:          { name: 'Artifact', rarity: 'legendary' },
});
console.log('full NFT tokenId:', nftMint.tokenId);  // 80 hex
```

`MintAssetResult`:

```ts
interface MintAssetResult {
    txId:    string;
    tokenId: string;       // 64 hex (fungible) or 80 hex (NFT)
    fee:     bigint;
}
```

## Transfer tokens

```ts
await client.sendToken({
    address: 'tnav1...',
    amount:  25n,
    tokenId: collection.collectionTokenId,
    memo:    'Thanks',
});
```

## Transfer an NFT

```ts
// Using full 80-hex token id
await client.sendNft({
    address: 'tnav1...',
    tokenId: '<80-hex>',
    memo:    'Gift NFT',
});

// Or collection + nft_id pair
await client.sendNft({
    address:           'tnav1...',
    collectionTokenId: '<64-hex>',
    nftId:             42n,
});
```

## Query balances

```ts
await client.getTokenBalance(tokenId);       // bigint
await client.getTokenOutputs(tokenId);       // WalletOutput[]

const tokenBalances = await client.getTokenBalances();   // all tokens
const nftBalances   = await client.getNftBalances();     // all NFTs
const allAssets     = await client.getAssetBalances();
```

See [Balances](balances.md) for the `WalletAssetBalance` shape.

## Who can mint

Only the wallet that ran `createTokenCollection` / `createNftCollection` holds the **token-signing key** — minting requires signing under that key. If the creator wallet is lost (mnemonic and audit key both gone), the collection becomes permanently unmintable. `totalSupply` is enforced by consensus; minting past it fails.

## NFT metadata conventions

No enforced spec — any `{string → string}` map works. For compatibility with NFT tooling, prefer:

```ts
{
    name:        'Artifact Name',
    description: 'Description',
    image:       'ipfs://...',
    attributes:  JSON.stringify([
        { trait_type: 'Rarity', value: 'Legendary' },
        { trait_type: 'Power', value: '9001' },
    ]),
}
```

The `attributes` JSON string re-serialises to the standard array used by OpenSea / ERC-721 metadata schemas.
