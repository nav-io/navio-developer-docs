# P2P messaging commands

The JSON-RPC surface of the encrypted p2p messaging subsystem (`-p2pmsg`, default on) and the applications shipping on it: cover-candidate aggregation for private sends, and RFQ atomic swaps (standing orders, quotes, wallet-side settlement).

This page is **automatically generated** by `scripts/extract-blsct-rpc.py --p2pmsg` from [navio-core](https://github.com/nav-io/navio-core) source:

-   `src/rpc/p2pmsg.cpp`
-   `src/blsct/wallet/rpc.cpp` (p2pmsg-related wallet commands)

Run `navio-cli help <command>` on your node for the definitive help text — source may have evolved since the last documentation build.

See the [p2p encrypted messaging concept page](../concepts/p2p-messaging.md) for how the bus works (kind-blind relay, per-message PoW, identity/prekey split, Dandelion stem), and [Trade tokens with RFQ](../guides/rfq-trading.md) for the full maker/taker trading sequence in plain terms.

## Quick index

| Category | Commands |
| -------- | -------- |
| **Node state** | `getp2pmsginfo`, `rotatep2pmsginbox`, `sendp2pping` |
| **Aggregation (cover traffic)** | `aggregatesend`, `getaggregationhint`, `getp2pmsgaggregate`, `listpendingcandidaterequests`, `replycandidate`, `sendcandidate`, `addaggregationcandidate` |
| **RFQ swaps — taker** | `requestquote`, `listquotes`, `acceptquote`, `acceptquotewallet`, `listrfqs`, `cancelrfq` |
| **RFQ swaps — maker** | `setswapintent`, `clearswapintent`, `listswapintents`, `listpendingquoterequests`, `sendquote`, `replyquote`, `addrfqquote` |
| **Standing orders** | `sendorder`, `listorders` |

---

### `getp2pmsginfo`

Return state of the encrypted p2p messaging subsystem (debug).

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli getp2pmsginfo
```

---

### `rotatep2pmsginbox`

Rotate the p2p-messaging inbox prekey now (manual privacy reset). The
stable node identity is unchanged; only the encryption prekey peers
target is replaced and re-signed. The previous prekey stays decryptable
for a short grace window so in-flight messages are not lost.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli rotatep2pmsginbox
```

---

### `sendp2pping`

Encrypt a PING to the given inbox pubkey and broadcast it over p2pmsg (debug).

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `inbox_pubkey` | `STR_HEX` | yes | Recipient inbox pubkey (hex), from getp2pmsginfo |
| 2 | `stem` | `BOOL` | no (default `true`) | Send via the Dandelion stem variant |

**Examples**

```bash
navio-cli sendp2pping "<hex>"
```

---

### `setswapintent`

Configure a local swap intent: offer to pay out `token_in` for `token_out`.
Never gossiped; used to answer matching RFQ requests.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_in` | `STR_HEX` | yes | Token the maker pays out (hex token hash, empty for NAV) |
| 2 | `token_out` | `STR_HEX` | yes | Token the maker wants to receive (hex, empty for NAV) |
| 3 | `min_size` | `NUM` | yes | Minimum fill size |
| 4 | `max_size` | `NUM` | yes | Maximum fill size |
| 5 | `price_min` | `NUM` | yes | Minimum price, sell-units per buy-unit scaled by 1e8 |
| 6 | `expiry` | `NUM` | yes | Unix time the intent expires |

**Examples**

```bash
navio-cli setswapintent "" "abcd..." 100 1000 100000000 1893456000
```

---

### `clearswapintent`

Remove a local swap intent by id.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `intent_id` | `NUM` | yes | The intent id |

**Examples**

```bash
navio-cli clearswapintent 1
```

---

### `listswapintents`

List all local swap intents.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli listswapintents
```

---

### `listorders`

Report the standing-order cache state (debug).

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli listorders
```

---

### `addaggregationcandidate`

Inject a fee-0 cover candidate half-transaction into the local pool (debug).
Normally candidates arrive encrypted over the network; this is for testing.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The candidate half-transaction |

**Examples**

```bash
navio-cli addaggregationcandidate "<hex>"
```

---

### `listpendingcandidaterequests`

Fetch and REMOVE (one-shot) queued candidate pull requests received via
AGG_ANN. Each entry is a requester's fresh reply session pubkey; answer
it with the wallet RPC replycandidate, which sends a CANDIDATE_TX
encrypted 1:1 to that key. Stale requests (older than the requester's
reply-key TTL) are pruned, not returned.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `max` | `NUM` | no (default `16`) | Maximum requests to claim |

**Examples**

```bash
navio-cli listpendingcandidaterequests
```

---

### `sendcandidate`

Encrypt a cover candidate half-transaction to `reply_pubkey` and send it
as a CANDIDATE_TX over p2pmsg (debug). The requester decrypts it under
its registered pull session key and adds it to its candidate pool;
recipients reject candidates not encrypted to one of their pull keys.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `reply_pubkey` | `STR_HEX` | yes | Requester's reply session pubkey (from its AGG_ANN pull request) |
| 2 | `tx_hex` | `STR_HEX` | yes | The candidate half-transaction |
| 3 | `stem` | `BOOL` | no (default `true`) | Send via the Dandelion stem variant |

**Examples**

```bash
navio-cli sendcandidate "<inboxhex>" "<txhex>"
```

---

### `getaggregationhint`

Return the parameters a wallet needs to size an aggregated send: how
many cover candidates are available and the per-candidate fee to add.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli getaggregationhint
```

---

### `getp2pmsgaggregate`

Aggregate a wallet-built BLSCT half-transaction with up to `max_candidates`
fee-0 cover candidates from the node's pool, then broadcast it.
The submitted half must already over-fund the fee to cover the combined
weight (see getaggregationhint). Used candidates are evicted from the pool.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The wallet's signed own half-transaction |
| 2 | `max_candidates` | `NUM` | no (default `16`) | Maximum cover candidates to merge |

**Examples**

```bash
navio-cli getp2pmsgaggregate "<signedhalfhex>" 16
```

---

### `requestquote`

Open a request-for-quote: collect maker quotes to buy `size` of `buy_token`
paying with `sell_token`. Returns a uuid + the session pubkey makers encrypt
their quotes to. (Broadcast over the wire is handled by the orchestrator.)

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `buy_token` | `STR_HEX` | yes | Token to receive (hex, empty for NAV) |
| 2 | `sell_token` | `STR_HEX` | yes | Token to pay with (hex, empty for NAV) |
| 3 | `size` | `NUM` | yes | Amount of buy_token wanted |
| 4 | `expiry` | `NUM` | yes | Unix time the collection window closes |

**Examples**

```bash
navio-cli requestquote "" "01..." 100 1893456000
```

---

### `listquotes`

List quotes collected for an open RFQ, ranked cheapest-price first.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `uuid` | `STR_HEX` | yes | The request uuid |
| 2 | `min_fill_ratio` | `NUM` | no (default `1`) | Drop quotes filling less than this fraction of size |

**Examples**

```bash
navio-cli listquotes "<uuid>"
```

---

### `acceptquote`

Combine the taker's signed half-transaction with a collected maker quote's
half and broadcast the resulting swap. The taker half must already balance
the multi-TokenId sums and fund the fee for the combined weight.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `uuid` | `STR_HEX` | yes | The request uuid |
| 2 | `quote_id` | `STR_HEX` | yes | The chosen quote id |
| 3 | `taker_half_hex` | `STR_HEX` | yes | The taker's signed half |

**Examples**

```bash
navio-cli acceptquote "<uuid>" "<quote_id>" "<takerhalfhex>"
```

---

### `listrfqs`

List open RFQ request uuids.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli listrfqs
```

---

### `cancelrfq`

Cancel an open RFQ, discarding its collected quotes.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `uuid` | `STR_HEX` | yes | The request uuid |

**Examples**

```bash
navio-cli cancelrfq "<uuid>"
```

---

### `addrfqquote`

Inject a maker quote for an open RFQ (debug). Normally quotes arrive
encrypted over the network.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `uuid` | `STR_HEX` | yes | The request uuid |
| 2 | `quote_id` | `STR_HEX` | yes | Unique quote id |
| 3 | `fill` | `NUM` | yes | Units of buy token offered |
| 4 | `sell_cost` | `NUM` | yes | Units of sell token charged |
| 5 | `half_tx_hex` | `STR_HEX` | yes | Maker's half-transaction |
| 6 | `order_expiry` | `NUM` | no (default `0`) | Quote expiry |

**Examples**

```bash
navio-cli addrfqquote "<uuid>" "<qid>" 1000 100 "<halfhex>"
```

---

### `listpendingquoterequests`

List inbound RFQ requests that matched one of this node's local swap
intents and are awaiting a wallet reply (see replyquote).

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli listpendingquoterequests
```

---

### `sendquote`

Send an externally built maker quote for an RFQ request over the p2pmsg
bus. The caller (e.g. a light wallet that built and signed its own
unbalanced half-transaction) supplies the half and the economic terms;
this node wraps them in a quote, authenticates it under its session
identity, encrypts it to the requester's reply key and broadcasts it.
If the uuid matches a pending matched request on this node (see
listpendingquoterequests) the pending entry is consumed.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `uuid` | `STR_HEX` | yes | The RFQ request uuid being answered |
| 2 | `reply_key` | `STR_HEX` | yes | The requester's reply session pubkey (from the RFQ request) |
| 3 | `half_tx_hex` | `STR_HEX` | yes | The maker's signed unbalanced half-transaction |
| 4 | `buy_token` | `STR_HEX` | yes | Token delivered to the taker (hex, empty for NAV) |
| 5 | `sell_token` | `STR_HEX` | yes | Token charged to the taker (hex, empty for NAV) |
| 6 | `fill` | `NUM` | yes | Units of buy_token delivered |
| 7 | `sell_cost` | `NUM` | yes | Units of sell_token charged |
| 8 | `order_expiry` | `NUM` | yes | Unix time the quote expires |

**Examples**

```bash
navio-cli sendquote "<uuid>" "<replykeyhex>" "<halfhex>" "" "01..." 100000000 10000000 1893456000
```

---

### `sendorder`

Publish an externally built standing swap order over the p2pmsg bus.
The caller (e.g. a light wallet) supplies its signed unbalanced
half-transaction offering `offer_amount` of `offer_token` for
`want_amount` of `want_token`; this node wraps it in a quote,
authenticates it under its session identity, caches it locally and
broadcasts it as an ORDER_ANN so peers can answer RFQs on the maker's
behalf while the maker is offline.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `half_tx_hex` | `STR_HEX` | yes | The maker's signed unbalanced half-transaction |
| 2 | `offer_token` | `STR_HEX` | yes | Token the maker offers (hex, empty for NAV) |
| 3 | `offer_amount` | `NUM` | yes | Units of offer_token delivered to the taker |
| 4 | `want_token` | `STR_HEX` | yes | Token the maker wants (hex, empty for NAV) |
| 5 | `want_amount` | `NUM` | yes | Units of want_token charged to the taker |
| 6 | `expiry` | `NUM` | yes | Unix time the order expires (capped to 14 days) |

**Examples**

```bash
navio-cli sendorder "<halfhex>" "" 100000000 "01..." 10000000 1893456000
```

---

### `aggregatesend`

Send `amount` to a BLSCT `address`, aggregating the spend with up to
`max_candidates` fee-0 cover candidates from the node's pool so the
broadcast transaction hides which outputs are yours. The wallet builds
and signs its own half (over-funding the fee to cover the combined
weight), combines with the pool candidates, and broadcasts.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `address` | `STR` | yes | The destination BLSCT address |
| 2 | `amount` | `AMOUNT` | yes | The amount to send |
| 3 | `max_candidates` | `NUM` | no (default `16`) | Maximum cover candidates to merge |

**Examples**

```bash
navio-cli aggregatesend "<blsctaddress>" 1.0 16
```

---

### `replycandidate`

Answer one candidate pull request: build a fee-0 cover candidate from one
of the wallet's own coins (a value-balanced self-spend with no fee output)
and send it as a CANDIDATE_TX encrypted 1:1 to the requester's reply key.
Only the requester learns the candidate, so the cover it provides in a
later aggregate cannot be subtracted out by other bus observers. This is
the candidate *producer*: run it against the reply keys queued by the
node's AGG_ANN handler (listpendingcandidaterequests), e.g. from
navio-p2pmsg -producecandidates.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `reply_pubkey` | `STR_HEX` | yes | The requester's reply session pubkey (from listpendingcandidaterequests) |
| 2 | `stem` | `BOOL` | no (default `true`) | Send via the Dandelion stem variant |

**Examples**

```bash
navio-cli replycandidate "<replypubkeyhex>"
```

---

### `acceptquotewallet`

Accept a collected RFQ quote using this wallet: the wallet builds and
signs its own unbalanced taker half (paying the quoted sell amount from
its coins, receiving the quoted fill of the buy token), combines it with
the maker's half, and broadcasts the atomic swap. The maker's quote half
is expected to over-fund the combined fee.

max_pay / min_recv are slippage bounds: the accept is rejected unless the
quote charges at most max_pay of the sell token and delivers at least
min_recv of the buy token.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `uuid` | `STR_HEX` | yes | The RFQ request uuid |
| 2 | `quote_id` | `STR_HEX` | yes | The chosen quote id |
| 3 | `max_pay` | `NUM` | yes | Max sell-token amount willing to pay (slippage bound) |
| 4 | `min_recv` | `NUM` | yes | Min buy-token amount required to receive (slippage bound) |

**Examples**

```bash
navio-cli acceptquotewallet "<uuid>" "<quote_id>"
```

---

### `replyquote`

Answer a pending matched RFQ request (see listpendingquoterequests): this
wallet builds and signs the unbalanced quote half — delivering `fill` of the
requested buy token, receiving `sell_cost` of the sell token — wraps it in a
quote bound to the request uuid, and sends it encrypted to the requester's
reply key over the p2pmsg bus. The half over-funds the fee so the taker can
accept with a fee-free half.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `uuid` | `STR_HEX` | yes | The pending request uuid to answer |

**Examples**

```bash
navio-cli replyquote "<uuid>"
```

---

