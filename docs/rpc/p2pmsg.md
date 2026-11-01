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
| **Node state** | `getp2pmsginfo`, `rotatep2pmsginbox`, `getp2pmsgdetectionkey`, `sendp2pping` |
| **User messaging** | `sendp2pmsg`, `mintp2pmsgreplykey`, `subscribep2pmsgtopic`, `unsubscribep2pmsgtopic`, `listp2pmsgtopics`, `listp2pmsgs`, `clearp2pmsgs` |
| **Aggregation (cover traffic)** | `aggregatesend`, `getaggregationhint`, `getp2pmsgaggregate`, `listpendingcandidaterequests`, `replycandidate`, `sendcandidate`, `addaggregationcandidate` |
| **RFQ swaps — taker** | `requestquote`, `listquotes`, `acceptquote`, `acceptquotewallet`, `listrfqs`, `cancelrfq` |
| **RFQ swaps — maker** | `setswapintent`, `clearswapintent`, `listswapintents`, `listpendingquoterequests`, `sendquote`, `replyquote`, `addrfqquote` |
| **Standing orders** | `broadcastorder`, `sendorder`, `listorders` |

!!! note "Token arguments and NFTs"
    Every token argument of `setswapintent`, `requestquote`, `sendquote`, `sendorder` and `broadcastorder` takes the 64-hex token id, the token id followed by `#<subid>` for an NFT (the form `listorders` prints), or the empty string for NAV. The subid is plain decimal (no sign, leading zeros or `0x`). A malformed value fails with `RPC_INVALID_PARAMETER` and a message naming the argument, e.g. `buy_token must be a 64-hex token id, followed by #<subid> for an NFT, or empty for NAV`. `listswapintents` and `listpendingquoterequests` print the `#<subid>` suffix for NFTs.

!!! note "Message store cursors"
    When the user-message store is enabled (`-p2pmsgstoresize` above 0), `getp2pmsginfo` returns a `store` object with `entries`, `bytes`, `last_id` and `undecodable`. `undecodable` counts messages on disk that this node cannot read; they are not returned by `listp2pmsgs` and not counted in `entries` or `bytes`. `clearp2pmsgs` returns the number of messages it removed, including undecodable ones in its range, so it can be larger than what `listp2pmsgs` showed. To drop only what you have read, pass the highest id `listp2pmsgs` returned. `0`, the default, drops everything.

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

### `getp2pmsgdetectionkey`

Derive a fuzzy-message-detection key for this node's inbox at a chosen
false-positive rate.

This is what you hand an ARCHIVING node so it can pick out the messages you
missed while offline. It matches your messages plus a 2^-precision fraction of
everyone else's, and the holder cannot tell the two apart.

SECRET, and long-lived: whoever holds it can test every FUTURE flag at this
precision until the clue key rotates (rotatep2pmsginbox). Lower precision means
more decoys, more bandwidth, and a larger anonymity set; higher precision means
the opposite. Choosing the maximum tells the holder exactly which messages are
yours.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `precision` | `NUM` | yes |  |

**Examples**

```bash
navio-cli getp2pmsgdetectionkey 8
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

### `sendp2pmsg`

Encrypt an application message to a recipient key and broadcast it over the p2pmsg bus.
`recipient` selects the delivery mode:
- an inbox (prekey) pubkey hex: confidential 1:1 delivery. Obtain it from the recipient's
getp2pmsginfo and verify its prekey_sig against their stable identity_pubkey.
- a reply pubkey minted with mintp2pmsgreplykey on the other side: 1:1 delivery to that
one-shot session key (the RFQ reply pattern; does not expose the recipient's inbox).
- the literal string \"broadcast\": public pub/sub — every node can read it, and nodes
SUBSCRIBED to `topic` (subscribep2pmsgtopic) store it.
With stem propagation (default) observers cannot tell where a message entered the network.

The node interprets only `topic` (the pub/sub routing key). Everything else an application
needs — sender identity, a reply key, threading, content type — must be framed inside the
payload by the application; the transport deliberately adds no sender information.

Calls to this RPC for the same recipient go out in the order they are received, even when
issued concurrently (each send grinds proof-of-work for a variable time before it can be
broadcast). That orders only what THIS node emits: messages still travel the bus over
independent paths, so an application that needs a guaranteed order must carry its own
sequence number in the payload.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `recipient` | `STR` | yes | Recipient pubkey hex (inbox prekey or minted reply key), or \"broadcast\" |
| 2 | `topic` | `STR` | yes |  |
| 3 | `payload` | `STR_HEX` | yes |  |
| 4 | `stem` | `BOOL` | no (default `true`) | Send via the Dandelion stem variant (hides the entry point) |
| 5 | `cluekey` | `STR_HEX` | no | The recipient's fmd_clue_key (from their getp2pmsginfo, verified against their identity via fmd_sig). Attaches a detection flag so the recipient can retrieve this message from an archiving node if they were offline. The flag carries NO recipient identifier: only someone holding the matching detection key can test it |

**Examples**

```bash
navio-cli sendp2pmsg "<inboxhex>" "chat" "<payloadhex>"
```

```bash
navio-cli sendp2pmsg "broadcast" "my-app-announce" "<payloadhex>"
```

---

### `mintp2pmsgreplykey`

Mint a fresh one-shot session keypair and register it with the transport so USER_DATA
messages encrypted to it are decrypted and stored (scope \"session\"). Hand the returned
pubkey to a counterparty (e.g. framed inside a broadcast) to receive 1:1 replies without
exposing this node's inbox prekey — the RFQ reply pattern, for applications.
The key expires after `ttl` seconds and is then pruned; messages already stored remain.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `ttl` | `NUM` | no (default `3600`) | Seconds the key stays registered (1-86400) |

**Examples**

```bash
navio-cli mintp2pmsgreplykey 600
```

---

### `subscribep2pmsgtopic`

Subscribe to a broadcast topic: broadcast USER_DATA messages carrying this topic are
stored in the inbox (they are relayed either way). 1:1 inbox and session-keyed messages
are always stored regardless of subscriptions. Persisted across restarts; seed at startup
with -p2pmsgtopic=<topic>.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `topic` | `STR` | yes |  |

**Examples**

```bash
navio-cli subscribep2pmsgtopic "my-app-announce"
```

---

### `unsubscribep2pmsgtopic`

Unsubscribe from a broadcast topic. Messages already stored remain until cleared or pruned.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `topic` | `STR` | yes | Topic string |

**Examples**

```bash
navio-cli unsubscribep2pmsgtopic "my-app-announce"
```

---

### `listp2pmsgtopics`

List the broadcast topics this node is subscribed to.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli listp2pmsgtopics
```

---

### `listp2pmsgs`

List stored USER_DATA messages, oldest first.
Ids increase monotonically and never repeat, so a client can poll with the last id it has
seen. The store is on disk and survives restarts; it is bounded by -p2pmsgstoresize (one
budget per scope, each pruned oldest first) and -p2pmsgstoreexpiry. Multiple applications
can read concurrently with their own cursors; clearp2pmsgs is optional early compaction,
not an ack.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `since_id` | `NUM` | no (default `0`) | Only return messages with id greater than this |
| 2 | `max_count` | `NUM` | no (default `100`) | Maximum messages to return (0 = all) |
| 3 | `topic` | `STR` | no (default `""`) | Only return messages with this topic (\"\" = all topics) |

**Examples**

```bash
navio-cli listp2pmsgs 0 50
```

```bash
navio-cli listp2pmsgs 0 50 "chat"
```

---

### `clearp2pmsgs`

Drop stored USER_DATA messages up to a cursor. Optional early compaction — the store
also prunes itself by -p2pmsgstoresize/-p2pmsgstoreexpiry.
To drop only what you have read, pass the highest id listp2pmsgs returned, and skip the
call when it returned nothing: 0 also drops messages that arrived after your last read.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `up_to_id` | `NUM` | no (default `0`) | Drop messages with id up to and including this (0 = drop all, including any stored since you last listed) |

**Examples**

```bash
navio-cli clearp2pmsgs 42
```

---

### `setswapintent`

Configure a local swap intent: offer to pay out `token_in` for `token_out`.
Never gossiped; used to answer matching RFQ requests.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_in` | `STR` | yes | Token the maker pays out: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
| 2 | `token_out` | `STR` | yes | Token the maker wants to receive: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
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

Report the standing-order cache state, optionally listing the cached orders.
Most fields are exactly what the maker broadcast to all peers in its
ORDER_ANN, but received and effective_expiry are THIS NODE's local
bookkeeping: the cache is memory-only with no backfill, so the set of
receive times maps this node's uptime since its last restart, and
effective_expiry reveals the receive time whenever the 14-day cap binds.
Strip both before republishing this output on a public endpoint.
Orders are sorted by declared order_expiry ascending (quote_id tie-break) --
a wire-public key, so the array order itself reveals nothing node-local.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `verbose` | `BOOL` | no (default `false`) | Also list the cached orders |
| 2 | `count` | `NUM` | no (default `"all"`) | The number of orders to list (verbose only) |
| 3 | `skip` | `NUM` | no (default `0`) | The number of orders to skip (verbose only) |

**Examples**

```bash
navio-cli listorders
```

```bash
navio-cli listorders true
```

---

### `addaggregationcandidate`

Inject a fee-0 cover candidate half-transaction into the local pool (debug).
Normally candidates arrive encrypted over the network; this is for testing.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The candidate half-transaction |
| 2 | `reward_input` | `BOOL` | no (default `false`) | Classify the candidate as spending a coinbase (block-reward) output, as the network ingest path would after a chainstate lookup. Without it a test can never populate the reward class |

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
| 1 | `buy_token` | `STR` | yes | Token to receive: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
| 2 | `sell_token` | `STR` | yes | Token to pay with: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
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
Fails while a quote of the RFQ is being accepted.

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
| 4 | `buy_token` | `STR` | yes | Token delivered to the taker: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
| 5 | `sell_token` | `STR` | yes | Token charged to the taker: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
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
| 2 | `offer_token` | `STR` | yes | Token the maker offers: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
| 3 | `offer_amount` | `NUM` | yes | Units of offer_token delivered to the taker |
| 4 | `want_token` | `STR` | yes | Token the maker wants: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
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

### `broadcastorder`

Publish a standing swap order: this wallet builds and signs an unbalanced
half-transaction offering `offer_amount` of `offer_token` for `want_amount`
of `want_token`, wraps it in a quote, caches it locally, and broadcasts it
over the p2pmsg bus as an ORDER_ANN so peers cache it and can answer RFQs
on the maker's behalf. The half over-funds the fee so a taker can accept
with a fee-free half.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `offer_token` | `STR` | yes | Token the maker offers: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
| 2 | `offer_amount` | `AMOUNT` | yes | Amount of offer_token to deliver |
| 3 | `want_token` | `STR` | yes | Token the maker wants: the 64-hex token id, followed by \"#<subid>\" for an NFT; empty for NAV |
| 4 | `want_amount` | `AMOUNT` | yes | Amount of want_token to receive |
| 5 | `expiry` | `NUM` | yes | Unix time the order expires (capped to 14 days) |

**Examples**

```bash
navio-cli broadcastorder "" 1.0 "01..." 1000 1893456000
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

