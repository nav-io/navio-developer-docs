# Token trading — RFQ atomic swaps

!!! warning "Unreleased — preview"
    RFQ trading ships on the `rfq-swap-trading` branch of `navio-sdk` and is **not yet in a published npm release**. Method names and options may change before it lands. It also needs server-side support (an ElectrumX RFQ bridge). Track the [navio-sdk repo](https://github.com/nav-io/navio-sdk) for the release.

Light wallets can trade tokens peer-to-peer over Navio's encrypted p2p messaging bus — no order-book server holds custody, and no funds move unless the swap settles atomically. The SDK supports both roles:

-   **Taker** — request quotes, then accept the best one.
-   **Maker** — advertise intents, answer quote requests, and publish standing orders that peers can fill while you are offline.

Swap halves are deliberately unbalanced BLSCT transactions (see [intra-chain aggregated swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps)) whose received leg is supplied by the counterparty's half. They are **always built and signed locally** — the server only wraps, encrypts, and relays them.

## Requirements

-   The `electrum` backend, connected to an ElectrumX server that runs the **RFQ bridge**.
-   That ElectrumX is connected to a daemon started with `-p2pmsg=1` (encrypted p2p messaging enabled).

## Taker: request → quote → accept

```ts
// Buy 500 units of a token, paying NAV
const req = await client.requestQuote({
    buyTokenId:  tokenId,
    sellTokenId: null,                              // NAV
    amount:      500n,
    expiry:      Math.floor(Date.now() / 1000) + 300,
});

// Poll collected quotes (ranked cheapest first)
const quotes = await client.listQuotes(req.uuid);

// Accept with mandatory slippage bounds — your only trust anchor against a
// malicious quote. The swap either settles atomically or no funds move.
const result = await client.acceptQuote({
    uuid:        req.uuid,
    quoteId:     quotes[0].quoteId,
    buyTokenId:  tokenId,
    sellTokenId: null,
    maxPay:      60n,   // reject if charged more
    minRecv:     500n,  // reject if delivered less
});

console.log('Swap tx:', result.txId);
```

!!! warning "`maxPay` / `minRecv` are mandatory"
    They are the only protection against a malicious counterparty quote. Set them from your own price expectations, not from the quote you received.

`listQuotes(uuid, minFillRatio = 1.0)` optionally filters partial fills — pass a lower `minFillRatio` to also see quotes that only fill part of the request.

## Maker: intents, replies, standing orders

Advertise liquidity and answer matching quote requests:

```ts
await client.setSwapIntent({
    tokenInId:  tokenId,     // we deliver this
    tokenOutId: null,        // we want NAV
    minSize:    1n,
    maxSize:    10_000n,
    priceMin:   10_000_000n, // 0.1 NAV per unit (scaled 1e8)
    expiry:     Math.floor(Date.now() / 1000) + 3600,
});

await client.subscribePendingQuoteRequests(async (pending) => {
    for (const request of pending) {
        await client.replyQuote({ request }); // builds + signs the maker half
    }
});
```

Publish a standing order that peers can fill while you are offline:

```ts
await client.broadcastOrder({
    offerTokenId: tokenId,
    offerAmount:  100n,
    wantTokenId:  null,
    wantAmount:   10n,
    expiry:       Math.floor(Date.now() / 1000) + 86400,
});
```

!!! warning "Don't spend the backing coins"
    Maker halves spend wallet coins that are **not locked** while a quote or order is outstanding. Don't spend them manually until it expires, or the swap will fail to confirm.

## How it settles

Both halves are unbalanced BLSCT transactions. When the taker accepts, the two locally-signed halves are aggregated into one balanced transaction (inputs − outputs − fee = 0) and broadcast as a single atomic unit — the same [aggregation mechanism](sending.md#aggregate-transactions) used for manual intra-chain swaps, here brokered over encrypted p2p messaging instead of by hand.
