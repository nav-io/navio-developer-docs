# Token trading — RFQ atomic swaps

Light wallets can trade tokens peer-to-peer over Navio's encrypted p2p messaging bus — no order-book server holds custody, and no funds move unless the swap settles atomically. The SDK supports both roles:

-   **Taker** — request quotes, then accept the best one.
-   **Maker** — advertise intents, answer quote requests, and publish standing orders that peers can fill while you are offline.

Swap halves are deliberately unbalanced BLSCT transactions (see [intra-chain aggregated swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps)) whose received leg is supplied by the counterparty's half. They are **always built and signed locally** — the server only wraps, encrypts, and relays them.

## Requirements

-   The `electrum` backend, connected to an ElectrumX server that runs the **RFQ bridge**.
-   That ElectrumX is connected to a daemon with encrypted p2p messaging enabled (`-p2pmsg`, see [P2P encrypted messaging](../concepts/p2p-messaging.md)).

### Timeouts

Every p2pmsg message carries mandatory anti-spam proof of work that the daemon grinds before the call returns; a request-for-quote can take 10–30 s or more and the time is probabilistic. Since **0.1.34**, the calls that make the daemon broadcast (`requestQuote`, `acceptQuote`, `replyQuote`, `broadcastOrder`) use `electrum.p2pmsgTimeout` (default 180 000 ms) instead of the regular request timeout. Server operators must raise ElectrumX's `REQUEST_TIMEOUT` to match (for example `REQUEST_TIMEOUT=180`); the default 30 s aborts these requests. See [ElectrumX → RFQ bridge](../node/electrumx.md#rfq-bridge).

`requestQuote`, `setSwapIntent` and `broadcastOrder` validate `expiry` as a Unix time in **seconds** and reject durations, millisecond timestamps and past times.

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

### Standing orders {#standing-orders}

Publish a standing order that peers can fill while you are offline:

```ts
await client.broadcastOrder({
    offerTokenId: tokenId,
    offerAmount:  100n,
    wantTokenId:  null,
    wantAmount:   10n,
    expiry:       Math.floor(Date.now() / 1000) + 86400,
    // reserveInputs: true (default)
});

const orders = await client.listStandingOrders();   // StandingOrderRecord[]
await client.forgetStandingOrder(orders[0].localId); // release its reservation
```

Since **0.1.35** the SDK records every order it publishes and, by default (`reserveInputs: true`), keeps the coins committed to live orders out of the next order's coin selection. The network's order cache refuses an order that spends an input of an order it already holds, so re-publishing from the same coins would fail. A record's `status` is `live` once the daemon accepted it, or `unconfirmed` when the broadcast timed out; an unconfirmed order keeps its reservation until expiry, because the daemon may still have published it. Records are pruned when they expire or an input is spent on chain. Records live in the `standing_orders` SQLite table / `standingOrders` IndexedDB store.

!!! warning "Don't spend the backing coins"
    The reservation applies only to other standing orders. Ordinary sends can still select coins that back an outstanding quote or order; spending them makes the swap fail to confirm. Wait for expiry, or forget the order first.

## How it settles

Both halves are unbalanced BLSCT transactions. When the taker accepts, the two locally-signed halves are aggregated into one balanced transaction (inputs − outputs − fee = 0) and broadcast as a single atomic unit — the same [aggregation mechanism](sending.md#aggregate-transactions) used for manual intra-chain swaps, here brokered over encrypted p2p messaging instead of by hand.
