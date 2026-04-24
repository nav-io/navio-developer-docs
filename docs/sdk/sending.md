# Sending transactions

The SDK exposes three high-level send methods, plus raw broadcast and aggregation for advanced flows.

## Send NAV

```ts
const result = await client.sendTransaction({
    address: 'tnav1...',
    amount:  100_000_000n,        // satoshis
    memo:    'Coffee',
    subtractFeeFromAmount: false, // default
});

console.log('txid:', result.txId);
console.log('fee:',  Number(result.fee) / 1e8, 'NAV');
console.log('ins:',  result.inputCount,
            'outs:', result.outputCount);
```

`SendTransactionOptions`:

```ts
interface SendTransactionOptions {
    address: string;                  // bech32m recipient
    amount: bigint;                   // in satoshis
    memo?: string;                    // UTF-8, stored encrypted
    subtractFeeFromAmount?: boolean;
    tokenId?: string | null;          // null for NAV (default)
}
```

Result:

```ts
interface SendTransactionResult {
    txId:        string;  // hex
    rawTx:       string;  // hex
    fee:         bigint;  // sats
    inputCount:  number;
    outputCount: number;  // includes change
}
```

### Subtract fee from amount

Use when sending "everything in this wallet":

```ts
await client.sendTransaction({
    address: 'tnav1...',
    amount: 50_000_000n,
    subtractFeeFromAmount: true,
});
```

## Send token

```ts
await client.sendToken({
    address: 'tnav1...',
    amount:  25n,
    tokenId: 'abcdef...64-hex...',    // collection id
    memo:    'Token payment',
});
```

Accepts the 64-hex collection id or an 80-hex full token id (auto-normalised to the 64-hex prefix).

## Send NFT {#send-nft}

Either pass a full 80-hex token id:

```ts
await client.sendNft({
    address: 'tnav1...',
    tokenId: '<80-hex>',
    memo:    'NFT transfer',
});
```

Or pass the collection + nft_id pair:

```ts
await client.sendNft({
    address:           'tnav1...',
    collectionTokenId: '<64-hex>',
    nftId:             1n,
    memo:              'NFT transfer',
});
```

## Broadcast a pre-built raw tx

If you constructed a transaction manually (via [`createblsctrawtransaction`](../rpc/blsct.md#createblsctrawtransaction) + sign):

```ts
const txHash = await client.broadcastRawTransaction(rawHex);
```

## Aggregate transactions {#aggregate-transactions}

Combine multiple independently-signed BLSCT transactions into one. Used for [intra-chain swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps) and coordinated multi-party transactions.

```ts
const aggregated = client.aggregateTransactions([
    aliceSignedHex,
    bobSignedHex,
]);

console.log(aggregated.txId);
await client.broadcastRawTransaction(aggregated.rawTx);
```

Return shape:

```ts
interface AggregateTransactionsResult {
    txId:  string;
    rawTx: string;
}
```

Does **not** broadcast automatically — call `broadcastRawTransaction` yourself after inspecting the aggregated tx.

Under the hood calls [`CTx.aggregateTransactions`](../blsct-lib/transactions.md#ctx-aggregation) in navio-blsct.

## Coin selection

The default selector:

1.  Partitions unspent outputs by `tokenId`.
2.  Picks outputs from the target `tokenId` until the amount + estimated fee is covered.
3.  Creates a BLSCT output to the destination and a change output back to a sub-address in the change pool (`account = -1`).
4.  Balances amount commitments.

Tweakable via raw-transaction RPC flows for fine-grained control.

## Fee estimation

The SDK asks the backend for a fee rate (via Electrum's `blockchain.estimatefee` or RPC `estimatesmartfee`) and applies it to the estimated transaction size. No per-call override today — use the raw-transaction flow if you need explicit fee control.

## Error cases

| Thrown error                              | Likely cause                                                |
| ----------------------------------------- | ----------------------------------------------------------- |
| `"insufficient funds"`                    | Not enough spendable UTXOs of the requested tokenId         |
| `"wallet is locked"`                      | Call `keyManager.unlock(pw)` first                          |
| `"backend not connected"`                 | Run `await client.initialize()` / check backend health      |
| `"invalid address"`                       | Malformed bech32m or wrong-network HRP                      |
| `"audit-only wallet"`                     | Wallet restored from audit key; no spend key                |
