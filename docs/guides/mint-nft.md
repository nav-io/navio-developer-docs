# Mint an NFT collection

Create a collection, mint several NFTs with metadata, and transfer one.

## Prereqs

-   SDK wallet set up (see [sdk-wallet](sdk-wallet.md)).
-   At least ~1 NAV in the wallet to cover create + mint + transfer fees.
-   Wallet synced.

## 1. Create the collection

```ts
import { NavioClient } from 'navio-sdk';

const client = new NavioClient({ /* … */ });
await client.initialize();
await client.sync();

const collection = await client.createNftCollection({
    metadata: {
        collection:  'Artifacts',
        description: 'A small collection of rare artifacts',
        creator:     'alice',
    },
    totalSupply: 100,          // cap on mintable NFTs
});

console.log('collection token id:', collection.collectionTokenId);
console.log('createnft txid:',       collection.txId);

// Wait for confirmation before minting — collection must be on-chain
await new Promise(r => setTimeout(r, 20_000));
await client.sync();
```

## 2. Mint a few NFTs

```ts
const self = client.getKeyManager().getSubAddressBech32m(
    { account: 0, address: 0 },
    'testnet',
);

async function mint(nftId: bigint, metadata: Record<string, string>) {
    const r = await client.mintNft({
        address:           self,
        collectionTokenId: collection.collectionTokenId,
        nftId,
        metadata,
    });
    console.log(`minted NFT #${nftId}: tokenId ${r.tokenId}`);
    return r;
}

await mint(1n, { name: 'Sword of Sparks',   rarity: 'common',    image: 'ipfs://bafyb.../1.png' });
await mint(2n, { name: 'Staff of Storms',   rarity: 'rare',      image: 'ipfs://bafyb.../2.png' });
await mint(3n, { name: 'Crown of Creation', rarity: 'legendary', image: 'ipfs://bafyb.../3.png' });

// Wait and sync to see them in the wallet
await new Promise(r => setTimeout(r, 20_000));
await client.sync();
```

## 3. List owned NFTs

```ts
const nfts = await client.getNftBalances();
for (const n of nfts) {
    console.log(`  ${n.collectionTokenId!.slice(0, 8)}#${n.nftId} (balance: ${n.balance})`);
}
```

## 4. Transfer an NFT

```ts
await client.sendNft({
    address:           'tnav1...friend...',
    collectionTokenId: collection.collectionTokenId,
    nftId:             3n,
    memo:              'Gift',
});
```

After the recipient syncs their wallet, the NFT appears in their `getNftBalances()`.

## Constraints

-   **Only the collection creator wallet can mint.** The token-signing key is derived from the creator's master spending secret; losing the mnemonic permanently disables minting for that collection.
-   **`nftId` must be unique** within the collection. Re-minting the same id fails.
-   **`totalSupply` is enforced** — the 101st mint on a cap-100 collection fails.
-   **Metadata is receiver-visible** — stored encrypted with the stealth shared secret, but the receiver of any transfer can read it.

## Metadata tips

-   **Stable attribute names** — pick a schema and use it across every mint, so downstream indexers can query cleanly.
-   **Store large assets off-chain.** IPFS URIs for images, video, JSON attribute packs. The on-chain metadata is a pointer.
-   **JSON attribute arrays** — for compatibility with NFT tooling, encode `attributes` as a JSON string:

```ts
await mint(1n, {
    name:        'Sword of Sparks',
    image:       'ipfs://…',
    description: 'A simple practice sword.',
    attributes: JSON.stringify([
        { trait_type: 'Rarity',  value: 'common' },
        { trait_type: 'Element', value: 'fire' },
        { trait_type: 'Damage',  value: 15 },
    ]),
});
```

## On-chain visibility

To outside observers:

-   The `createnft` transaction reveals: collection metadata, `totalSupply`, the creator's token-signing pubkey.
-   `mintnft` transactions reveal: which collection (token id cleartext), and per-NFT metadata (also cleartext in this position). Recipient identity and fee-paying balances remain hidden.
-   Transfer transactions reveal: the asset is moving (token_id cleartext) but not who sent, who received, or any amount.
