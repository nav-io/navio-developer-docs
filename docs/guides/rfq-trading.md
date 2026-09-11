# Trade tokens with RFQ

How to trade tokens for NAV (or the other way round) directly on the Navio network — no exchange, no escrow, no counterparty risk. Makers offer liquidity, takers ask for prices, and the trade settles as **one single transaction** that either happens completely or not at all.

RPC reference: [P2P messaging commands](../rpc/p2pmsg.md) · How the message bus works: [P2P encrypted messaging](../concepts/p2p-messaging.md)

---

## The terms, in plain words

| Term | What it means |
| ---- | ------------- |
| **Maker** | Someone offering to trade — like a market stall holder who posts "I'll sell TokenA for NAV". Makers *make* the market by having something on offer before anyone asks. |
| **Taker** | Someone who wants to trade *now* and takes an offer that already exists. |
| **Liquidity** | Offers actually available to trade against. A market with many makers has "deep liquidity": you can trade a lot without moving the price. |
| **Swap intent** | A maker's standing offer, stored **only on their own node** — nothing is announced to the network. It just tells your node: "if someone asks for this pair, answer them". |
| **RFQ (request for quote)** | The taker's question, broadcast to the whole network: "who will sell me 500 TokenA, and at what price?" Like shouting into the market square — every maker hears it, nobody knows who asked (the bus hides the origin). |
| **Quote** | A maker's answer to an RFQ: "I will. Here's my price — and here's my **signed half** of the trade, ready to go." Quotes are encrypted so only the asking taker can read them. |
| **Half-transaction** | Each side signs only *their* half of the swap (what they pay and what they receive). Neither half is valid alone — combine the two halves and you get one complete, balanced transaction. That's what makes the swap **atomic**: nobody can take your tokens without their side happening in the same instant. |
| **Fill** | How much of your requested size a quote actually covers. |
| **Slippage bounds** | Your safety rails when accepting: "pay at most X, receive at least Y". If the quote doesn't fit inside them, the accept is rejected instead of trading at a worse price. |
| **Standing order** | A maker's offer that keeps working **while the maker is offline**: a pre-signed half-transaction that other nodes cache and answer RFQs with on the maker's behalf. |
| **uuid / quote_id** | Just receipts: the id of your RFQ, and the id of one particular quote answering it. |

Amounts are in the smallest unit (like satoshis): `1 NAV = 100000000`. The empty string `""` means NAV itself; a token is identified by its hex `tokenId`.

---

## The sequence

```
 MAKER                              NETWORK                              TAKER
   |                                   |                                   |
   |  1. setswapintent                 |                                   |
   |     (stored locally, silent)      |                                   |
   |                                   |   2. requestquote  ------------>  |
   |  <---------- RFQ broadcast ------ | <--- "who sells 500 TokenA?"      |
   |                                   |                                   |
   |  3. replyquote                    |                                   |
   |     (signed maker half) --------> | ----> quote arrives, encrypted    |
   |                                   |                                   |
   |                                   |   4. listquotes (cheapest first)  |
   |                                   |   5. acceptquotewallet            |
   |                                   |      taker half + maker half      |
   |                                   |      = ONE swap transaction  ---> broadcast
   |                                   |                                   |
   |            both sides settle in the same block, atomically            |
```

---

## Step by step

The walkthrough below trades **TokenA for NAV**. `TOKA` stands for the token's hex id (from `createtoken` / `listtokens`).

### 1. Maker: put liquidity on offer

```bash
# "I pay out TokenA and want NAV in return:
#  I'll fill orders between 1 and 500 TokenA units,
#  at a price of at least 0.1 NAV per unit, until <expiry>."
navio-cli -rpcwallet=maker setswapintent "$TOKA" "" 100000000 50000000000 10000000 1893456000
```

- `token_in` — what the maker pays out (here TokenA), `token_out` — what they want back (`""` = NAV).
- `min_size` / `max_size` — the fill range they're willing to serve.
- `price_min` — the worst price they'll accept, in `token_out` units per whole `token_in` unit.
- `expiry` — unix time after which the intent stops answering.

Nothing is broadcast. The intent sits on the maker's node, waiting for matching questions. Check it with `listswapintents`, remove it with `clearswapintent`.

### 2. Taker: ask the market

```bash
# "Who will sell me 500 TokenA for NAV?" — valid until <expiry>
navio-cli -rpcwallet=taker requestquote "$TOKA" "" 50000000000 1893456000
```

Returns a `uuid` — your RFQ's receipt. Behind the scenes the question is broadcast over the encrypted bus; every maker node hears it, and the bus's stem routing hides which node asked. Your node also mints a fresh one-time key, so makers' answers are readable by you alone and can't be linked to your wallet.

Open RFQs: `listrfqs`. Changed your mind: `cancelrfq <uuid>`.

### 3. Maker: answer with a quote

A maker node whose intent matches sees the request queued:

```bash
navio-cli -rpcwallet=maker listpendingquoterequests
# → shows the uuid, pair and size of the taker's question

navio-cli -rpcwallet=maker replyquote "<uuid>"
```

`replyquote` makes the wallet build and sign the **maker half** — "I put in 500 TokenA, I take out 50 NAV" — and sends it to the taker, encrypted to the RFQ's one-time key. The maker's coins are not spent yet; the half is worthless until it's combined with a taker half.

(Light wallets that build their half elsewhere use `sendquote` with the pre-built half instead.)

### 4. Taker: compare quotes

```bash
navio-cli -rpcwallet=taker listquotes "<uuid>"
```

Quotes arrive ranked **cheapest first**, each showing the fill, the price, and its `quote_id`. Wait a few seconds to let several makers answer, then pick.

### 5. Taker: accept — the trade settles

```bash
# max_pay: don't pay more than 50 NAV; min_recv: don't accept less than 500 TokenA
navio-cli -rpcwallet=taker acceptquotewallet "<uuid>" "<quote_id>" 5000000000 50000000000
```

Your wallet builds and signs the **taker half** (pay the quoted NAV, receive the tokens), checks the quote against your slippage bounds (`max_pay` / `min_recv` — reject rather than trade worse), combines the two halves into one transaction and broadcasts it.

That single transaction *is* the trade. Both transfers are inside it, so there's no moment where one side has paid and the other hasn't — it confirms for both or for neither. To everyone else on the network it looks like any other private transaction: amounts hidden, participants hidden.

```bash
# after a block confirms:
navio-cli -rpcwallet=taker gettokenbalance "$TOKA"   # tokens arrived
navio-cli -rpcwallet=maker getblsctbalance           # NAV arrived
```

---

## Standing orders: liquidity while you sleep

A swap intent only answers while the maker's node is online and its wallet unlocked. A **standing order** removes that requirement: the maker pre-signs their half once and publishes it, and *other* nodes cache it and answer matching RFQs with it on the maker's behalf.

```bash
# maker (or a light wallet that built half_tx_hex elsewhere):
navio-cli sendorder "<half_tx_hex>" "$TOKA" 50000000000 "" 5000000000 1893456000

# anyone:
navio-cli listorders     # standing orders this node has cached
```

Standing orders are signed under the maker's session identity, so cached copies can't be tampered with, and they drop out automatically when their coins are spent or they expire.

---

## When things don't happen

- **No quotes arrive** — no online maker had a matching intent (right pair, size inside `min_size`..`max_size`, your implied price above their `price_min`). Try a different size or wait for liquidity.
- **Accept rejected with a slippage error** — the quote's numbers fall outside your `max_pay` / `min_recv`. That's the bounds doing their job; accept a different quote or loosen the bounds deliberately.
- **Quote or RFQ expired** — both carry an `expiry`; ask again. Quotes reference real coins, so a maker whose coins moved in the meantime produces an invalid half — the combine simply fails and nothing is spent.

Everything above is also exposed for wallet apps through the same JSON-RPC — see the [P2P messaging RPC reference](../rpc/p2pmsg.md).
