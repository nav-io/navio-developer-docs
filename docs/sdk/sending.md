# Sending transactions

The SDK exposes four high-level send methods (`sendTransaction`, `sendToMany`, `sendToken`, `sendNft`), plus raw broadcast and aggregation for advanced flows.

## Send NAV

```ts
const result = await client.sendTransaction({
    address: 'tnv1...',
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
    selectedUtxos?: string[];         // outputHashes; skips automatic selection
    randomBlindingKeys?: boolean;     // default false — see Output authorship
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
    address: 'tnv1...',
    amount: 50_000_000n,
    subtractFeeFromAmount: true,
});
```

## Send to many {#send-to-many}

Pay several recipients in a **single** confidential NAV transaction. All recipients share one set of (auto- or manually-selected) NAV inputs and a single optional change output — cheaper and more private than N separate sends.

```ts
const result = await client.sendToMany({
    recipients: [
        { address: 'tnv1...', amount: 100_000_000n, memo: 'invoice 1' },
        { address: 'tnv1...', amount:  50_000_000n },
        { address: 'tnv1...', amount:  25_000_000n, subtractFeeFromAmount: true },
    ],
});

console.log('txid:', result.txId);
console.log('outs:', result.outputCount); // recipients + change
```

`SendToManyOptions`:

```ts
interface SendRecipient {
    address: string;                  // bech32m recipient
    amount: bigint;                   // satoshis, must be > 0
    memo?: string;                    // per-output memo
    subtractFeeFromAmount?: boolean;  // this recipient pays a share of the fee
}

interface SendToManyOptions {
    recipients: SendRecipient[];      // one or more, non-empty
    selectedUtxos?: string[];         // optional manual NAV UTXO selection (outputHashes)
}
```

When `subtractFeeFromAmount` is set on more than one recipient, the fee is split evenly between them (rounding remainder goes to the first such recipient). NAV only — for tokens/NFTs use `sendToken` / `sendNft`. Returns the same `SendTransactionResult` as `sendTransaction`.

## Send token

```ts
await client.sendToken({
    address: 'tnv1...',
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
    address: 'tnv1...',
    tokenId: '<80-hex>',
    memo:    'NFT transfer',
});
```

Or pass the collection + nft_id pair:

```ts
await client.sendNft({
    address:           'tnv1...',
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

Pass `selectedUtxos` (a list of `outputHash`es) to choose inputs yourself. Staked commitments are never selected (see [Staked outputs](balances.md#staked-outputs)). Coins backing a live [standing order](trading.md#standing-orders) are reserved only against other orders, not against ordinary sends.

## Fee estimation

The SDK computes the fee locally from the size of the signed transaction at the BLSCT default fee rate (125 sat per byte, plus a size headroom), rebuilding the outputs until the fee covers the signed size. No per-call fee override today — use the raw-transaction flow if you need explicit fee control. Since 0.4.0, wallet funding is checked against the fee of the built transaction rather than a rough pre-build estimate.

## Output authorship {#output-authorship}

Since **0.2.0**, the blinding scalar `k` of every BLSCT output the wallet creates is derived from the wallet seed instead of drawn at random and discarded. The sender can therefore recompute it later, even after restoring from the mnemonic alone, and prove they created a given output.

```ts
// Recover the private blinding scalar of an output this wallet created
const rec = await client.recoverBlindingKey({ txid, vout });
rec.blindingKey;   // private scalar, 64 hex — treat as a secret
rec.publicKey;     // k · G, 96 hex — the output's on-chain ephemeralKey
rec.source;        // 'stored' (wallet DB) or 'derived' (recomputed from the seed)

// Sign a message with it, e.g. to back a refund claim
const { signature, blindingKey } = await client.signOutput({ txid, vout, message: 'refund to …' });
// verifies with navio-blsct: Signature.verify(publicKey, message), publicKey = blindingKey
```

-   `signOutput` signs the message exactly as given and returns the **public** key the signature verifies against: `k · G`, which is on chain as the output's `blsctData.ephemeralKey`. It is not `WalletOutput.blindingKey`, which navio-core computes as `k · sk_destination`.
-   The derivation binds the seed to an anchor input (the smallest outid among the inputs the sender contributed) and a per-output counter; the exact construction is in the [navio-sdk 0.2.0 changelog](https://github.com/nav-io/navio-sdk/blob/master/CHANGELOG.md). navio-core exposes the same capability through the `signblsctoutput` RPC.
-   Recovery does not rely on output or input positions, which block aggregation and input shuffling change. Every candidate is checked against the output's on-chain point, so a match is proof and a wrong candidate can never yield a false key. Swap outputs remain recoverable.
-   The scalar is also stored when the output is created, in its own `output_blinding_keys` table, never in `WalletOutput`.

!!! warning "Only outputs created by 0.2.0 or later"
    Outputs created by navio-sdk 0.1.36 or earlier, or by another wallet, used a random scalar that no longer exists. They cannot be recovered.

To opt out, set `deterministicBlindingKeys: false` on the client, or `randomBlindingKeys: true` on an individual send (`sendTransaction`, `sendToMany`, token / NFT sends, `delegateStake`, `unstake`). Those outputs are then unrecoverable.

## Error cases

| Thrown error                              | Likely cause                                                |
| ----------------------------------------- | ----------------------------------------------------------- |
| `"insufficient funds"`                    | Not enough spendable UTXOs of the requested tokenId         |
| `"wallet is locked"`                      | Call `keyManager.unlock(pw)` first                          |
| `"backend not connected"`                 | Run `await client.initialize()` / check backend health      |
| `"invalid address"`                       | Malformed bech32m or wrong-network HRP                      |
| `"audit-only wallet"`                     | Wallet restored from audit key; no spend key                |
