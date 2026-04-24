# Balances & UTXOs

All balance queries return *recovered* amounts — the SDK has already decrypted the hidden amounts for you. Aggregates are summed in-memory from the wallet DB; individual output queries hit the DB directly.

## NAV balance

```ts
const sats = await client.getBalance();              // bigint, satoshis
const nav  = await client.getBalanceNav();           // number with 8 decimals
console.log(`${nav.toFixed(8)} NAV`);
```

## Token balance

```ts
const tokenSats = await client.getBalance(tokenId);      // bigint
const tokenBal  = await client.getTokenBalance(tokenId); // bigint
```

`tokenId` is a 64-hex collection id for fungible tokens, or an 80-hex id for NFTs.

## All asset balances

```ts
const assets = await client.getAssetBalances();
for (const a of assets) {
    console.log(a.tokenId, a.kind, a.balance, 'outputs:', a.outputCount);
}
```

`WalletAssetBalance`:

```ts
interface WalletAssetBalance {
    tokenId: string;
    kind: 'token' | 'nft';
    balance: bigint;
    outputCount: number;
    collectionTokenId: string | null;    // for NFTs: the 64-hex collection
    nftId: bigint | null;                // for NFTs: the subid
}
```

Filter by kind:

```ts
const tokens = await client.getTokenBalances();   // fungibles only
const nfts   = await client.getNftBalances();     // NFTs only
```

## Unspent outputs (UTXOs)

```ts
const utxos = await client.getUnspentOutputs();               // all, NAV
const navUtxos = await client.getUnspentOutputs(null);        // explicit NAV
const tokenUtxos = await client.getUnspentOutputs(tokenId);   // specific asset
```

`WalletOutput`:

```ts
interface WalletOutput {
    outputHash:        string;  // 64-hex
    txHash:            string;
    outputIndex:       number;
    blockHeight:       number;
    amount:            bigint;
    memo:              string | null;
    tokenId:           string | null;
    blindingKey:       string;
    spendingKey:       string;
    isSpent:           boolean;
    spentTxHash:       string | null;
    spentBlockHeight:  number | null;
}
```

`outputHash` is the canonical outpoint identifier — see [outpoint model](../concepts/outpoint.md).

## All outputs (including spent)

```ts
const history = await client.getAllOutputs();
const spent = history.filter(o => o.isSpent);
```

Useful for UI balance history, audit reports, tax exports.

## Outputs for a specific asset

```ts
const tokenOutputs = await client.getTokenOutputs(tokenId);
```

Equivalent to `getUnspentOutputs(tokenId)` but returns only unspent entries. For full history, use `getAllOutputs` and filter by `tokenId`.

## Summed display example

```ts
const balanceNav = await client.getBalanceNav();
const utxos = await client.getUnspentOutputs();
console.log(`${balanceNav.toFixed(8)} NAV in ${utxos.length} UTXOs`);

const assets = await client.getAssetBalances();
for (const a of assets) {
    const humanAmount = Number(a.balance);
    const label = a.kind === 'nft'
        ? `NFT ${a.collectionTokenId!.slice(0, 8)}#${a.nftId}`
        : `Token ${a.tokenId.slice(0, 8)}`;
    console.log(`  ${label}: ${humanAmount}`);
}
```

## Snapshot semantics

Balance and UTXO queries reflect the state of the wallet DB at the moment of the call. After a successful `sendTransaction`:

-   Spent inputs are marked spent *optimistically* (`isSpent: true`, `spentTxHash` set) before the tx is confirmed.
-   Newly-created outputs (including change) become visible only when sync observes them in a block.
-   If the tx fails to propagate or gets evicted from mempool, the optimistic spent markers clear on next sync reorg handling.

For exchange-grade deposit detection, require ≥ 6 confirmations before crediting — use `utxo.blockHeight` against `(await client.getChainTip()).height`.
