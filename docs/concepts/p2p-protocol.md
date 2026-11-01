# P2P protocol

Navio speaks the Bitcoin Core P2P protocol (version handshake, `inv`/`getdata`, headers-first sync, BIP152 compact blocks, `addr` gossip) with Navio-specific network magic (see [Networks](networks.md#p2p-wire-protocol-magic)) and a set of extensions for output-centric identity, aggregated blocks, light wallets, browser clients and the [encrypted messaging overlay](p2p-messaging.md). This page lists those extensions as implemented in `src/protocol.h` and `src/net_processing.cpp` on navio-core `master`.

!!! note "Version availability"
    The WebSocket listener (`-p2pwsbind`), p2pmsg envelope v2 (`NODE_P2PMSG_V2`), `NODE_P2PMSG_LEAF` and the envelope archive (`NODE_P2PMSG_ARCHIVE`, `p2pmsgchal`, `getp2pmsgs`/`p2pmsgs`) ship in **v0.2.2**. The rest of the Navio-specific behaviour on this page — serving `getdata` by output id with relay rules applied, compact-block version 3, `getoutkeys`/`outkeys` (`NODE_OUTKEYS`), `NODE_P2P_WS` + `wsendpoint` + `-p2pwsexternal`, the `-whitelist` exclusion for WebSocket peers, confirmation by containment and mempool output-id uniqueness — is merged on `master` and lands in the next release.

## Service bits

Navio uses Bitcoin's standard bits plus the experiment range (bits 24–31):

| Bit | Flag                  | `getpeerinfo` name | Meaning                                                                                  | Enabled by |
| --- | --------------------- | ------------------ | ---------------------------------------------------------------------------------------- | ---------- |
| 0   | `NODE_NETWORK`        | `NETWORK`          | Serves the full chain.                                                                   | unpruned node |
| 3   | `NODE_WITNESS`        | `WITNESS`          | Serves blocks/transactions with witness data.                                            | always |
| 6   | `NODE_COMPACT_FILTERS`| `COMPACT_FILTERS`  | Serves BIP157/158 filters.                                                               | `-peerblockfilters` + `-blockfilterindex` |
| 10  | `NODE_NETWORK_LIMITED`| `NETWORK_LIMITED`  | Serves at least the last 288 blocks.                                                     | always (pruned nodes set only this, not `NETWORK`) |
| 11  | `NODE_P2P_V2`         | `P2P_V2`           | Supports BIP324 v2 transport.                                                            | `-v2transport=1` |
| 24  | `NODE_P2PMSG`         | `P2PMSG`           | p2pmsg relay, envelope v1. **Not advertised** by current builds, which reject v1 envelopes. | — |
| 25  | `NODE_P2PMSG_LEAF`    | `P2PMSG_LEAF`      | Receives p2pmsg fluff traffic but never relays; never chosen as a Dandelion++ stem hop. Set by light clients, not by `naviod`. | client-side |
| 26  | `NODE_P2PMSG_ARCHIVE` | `P2PMSG_ARCHIVE`   | Retains flagged p2pmsg envelopes and serves them with `getp2pmsgs`.                      | `-p2pmsgarchive` |
| 27  | `NODE_P2PMSG_V2`      | `P2PMSG_V2`        | p2pmsg relay, envelope v2.                                                               | `-p2pmsg` (default on) |
| 28  | `NODE_OUTKEYS`        | `OUTKEYS`          | Serves `getoutkeys` (per-block output keys for light wallets).                           | `-peeroutkeys` |
| 30  | `NODE_P2P_WS`         | `P2P_WS`           | Accepts P2P connections over WebSocket; port sent in `wsendpoint`.                       | `-p2pwsbind` (see [below](#websocket-listener)) |

Service bits are unauthenticated advertisements and ride `addr` gossip, so they make a node's participation in each service visible network-wide.

## Transport: v1 and BIP324 v2

Connections use the v1 (plaintext) transport unless `-v2transport=1` is set. **v2transport is off by default** (`DEFAULT_V2_TRANSPORT = false`). With it on, the node advertises `NODE_P2P_V2`, accepts v2 inbound, and attempts v2 outbound to peers that advertise the bit, falling back to v1 when a peer does not support it.

```ini
# navio.conf
v2transport=1
```

WebSocket connections always use the v1 byte stream; BIP324 is not attempted over them. Use a TLS-terminating proxy (`wss://`) for confidentiality on that path.

## Output-centric identity

A Navio input spends an output by its **output id**: `COutPoint` holds one 32-byte hash equal to `CTxOut::GetHash()` — the double-SHA256 of the serialized output, including its BLSCT data. There is no `vout` index. See [Outpoint model](outpoint.md). `CTransaction` computes and caches its output ids once at construction, alongside txid and wtxid.

### `getdata` by output id: `MSG_OUTPUT_HASH`

| Inventory type      | Value | Meaning |
| ------------------- | ----- | ------- |
| `MSG_TX`            | 1     | Transaction by txid |
| `MSG_DTX`           | 6     | Dandelion++ stem transaction |
| `MSG_DWTX`          | 7     | Dandelion++ stem transaction, by wtxid |
| `MSG_OUTPUT_HASH`   | 8     | The transaction that **created** the output with this id |
| `MSG_WITNESS_TX`    | `MSG_TX \| 1<<30` | By txid; Navio nodes also resolve an output id sent this way |

A node resolves an output id through its mempool's output-to-tx index and its most-recent-block cache, then applies **exactly the same serving rules** as a request by txid: a transaction still in its Dandelion++ stem phase is served (as `dtx`) only to the selected stem peer, and a transaction not yet announced to the requesting peer gets `notfound`.

Missing parents of an orphan transaction are requested by output id with a `MSG_WITNESS_TX` getdata, because every released version answers that form, whereas released versions drop `MSG_OUTPUT_HASH` silently.

!!! info "Dandelion++ and older peers"
    Released versions (v0.2.2 and older) check the stem embargo by txid, so an output-id request never matches it. A peer running one of those versions can answer such a request with a parent that is still in its stem phase as a plain `tx`, ending that transaction's stem phase early. This is not new behaviour and goes away as peers upgrade. Dandelion++ itself is on by default (`-dandelion=1`).

### Mempool uniqueness

Because outputs are identified by content, the mempool rejects (policy, not consensus) a transaction that repeats one of its own spendable outputs, creates a spendable output another mempool transaction already creates (unless it replaces that transaction), or recreates a coin that is still unspent on chain: reject reason `txn-duplicate-output` (`package-duplicate-output` within a package). This mirrors `ConnectBlock`'s `bad-txns-BIP30` rule. Unspendable outputs may repeat.

## Aggregated blocks

On BLSCT chains the block assembler merges every user transaction of a template into **one aggregate** with `blsct::AggregateTransactions`: a block with more than one user transaction is `[coinbase, aggregate]`. The component transactions never appear in the block by txid. The aggregate concatenates the components' inputs and outputs in order and folds their fee outputs into one; it does **no cut-through**, so a chain of unconfirmed sends merged into one block keeps each intermediate change output together with the input that spends it.

### Confirmation by containment

When a block connects, the mempool treats a transaction as **confirmed by containment** if every one of its inputs is spent by the block and every one of its non-fee outputs (at least one) is created by the block. Such transactions leave the mempool as confirmed (`BLOCK`), not as conflicts; their in-mempool descendants stay; the fee estimator and other block listeners see them; and the node marks their txids as recently confirmed so peers re-announcing them are not asked for them again. Anything else that shares an input with the block is still treated as a conflict. Wallets confirm their own merged sends the same way (see [Wallet behaviour](outpoint.md#wallet-behaviour-for-merged-sends)).

### Compact blocks version 3

BIP152 cannot rebuild an aggregate from a mempool, because the aggregate is never in one. Navio adds a component encoding, negotiated as a **capability**:

-   After the usual `sendcmpct(false, 2)`, a node also sends `sendcmpct(false, 3)`. Version 3 only signals support; high/low-bandwidth mode is still negotiated with version 2. Peers that do not know version 3 ignore it. `-blocksonly` nodes do not announce it.
-   `cmpctaggblk` carries the header, the prefilled coinbase and the 6-byte short ids of the aggregate's **component** transactions in aggregation order (same layout as `cmpctblock`).
-   The receiver fills components from its mempool and extra-transaction pool, requests missing ones with `getaggblktxn` (indexes into the component list, 0 = coinbase) answered by `aggblocktxn`, re-aggregates, and accepts the block only if the merkle root matches; otherwise it falls back to a full block download.
-   A sender uses the encoding only when it knows the block's components (it recovers them from its mempool, or kept them from a rebuilt `cmpctaggblk`; the last 16 such blocks are remembered). Otherwise, and for blocks with a single user transaction, it uses ordinary version 2 `cmpctblock`.

## Light-wallet output keys: `getoutkeys` / `outkeys`

A node started with `-peeroutkeys=1` (default off) advertises `NODE_OUTKEYS` and serves, per block, the keys a BLSCT wallet needs to recognise its outputs without downloading range proofs. It is incompatible with `-prune`, because replies are read from block files.

| Message      | Payload |
| ------------ | ------- |
| `getoutkeys` | `uint32 start_height`, `uint256 stop_hash` — active-chain blocks from `start_height` to `stop_hash` inclusive, at most **1000** blocks |
| `outkeys`    | One message per block, in height order: `uint256 block_hash`; a vector of entries, one per output carrying BLSCT keys, in block order (`uint256 output_hash`, 48-byte `blinding_key`, 48-byte `spending_key`, `uint16 view_tag`, `scriptPubKey` — empty unless `spending_key` is the identity point); then a vector of the output hashes the block's inputs spend |

A reply stops before the block that would take its total payload over **4,000,000 bytes** (the first block is always sent); a client that receives fewer blocks than requested continues from the height after the last one. A request for an unknown or not-yet-servable stop block, a start above the stop block, a range over 1000 blocks, or any request to a node that does not advertise `NODE_OUTKEYS` disconnects the peer.

Scanning: derive the nonce from `blinding_key` and the view key, discard outputs whose `view_tag` does not match, resolve the sub-address from `spending_key` (or the keys in `scriptPubKey`), then fetch the transactions of matching outputs by output id (they carry the range proofs needed to recover amounts). The `spent` list marks which of the wallet's outputs a block consumed. See [Output detection](../blsct/detection.md).

## WebSocket listener

`-p2pwsbind=<addr>[:<port>]` (repeatable, off by default) adds listening sockets that accept P2P connections carried over WebSocket (RFC 6455), so browser and other WebSocket-only SDK clients can join as ordinary inbound peers.

-   **Framing.** Binary frames carry the normal v1 P2P byte stream; frame boundaries have no meaning. Text frames close the connection. Client frames must be masked. No extensions or subprotocols. Upgrade requests are capped at 8 KiB, frame payloads at 4 MiB.
-   **TLS.** `naviod` speaks plain `ws://` only. For `wss://` (required by browsers on `https://` pages) terminate TLS in a reverse proxy and forward to the `-p2pwsbind` address, bound to loopback or a private interface.
-   **Peers.** A WebSocket peer is a normal inbound peer: it counts against `-maxconnections` and is subject to the usual DoS scoring, eviction and bans. It gets **no permissions**: `-whitelist` does not apply to WebSocket peers, because behind a proxy every client shares the proxy's address. `getpeerinfo` shows `"websocket": true`.
-   **`-p2pwsexternal=<ws(s)://host[:port][/path]>`** names the public URL when the listener sits behind a proxy. It requires `-p2pwsbind`. Setting `-p2pwsbind` implies `-listen=1`.

### Advertisement: `NODE_P2P_WS` and `wsendpoint`

A service bit cannot carry a port, so a node with a usable listener sets `NODE_P2P_WS` and sends each peer a `wsendpoint` message right after the version handshake: `uint16 port`, then a URL string (max 256 bytes) that is empty when the listener is reachable at `ws://<peer address>:<port>`, or the full public `ws://`/`wss://` URL when proxied (its port, or 80/443 by scheme, is the one announced). Received announcements appear in `getpeerinfo` as `ws_port` / `ws_url`; they are informational and an invalid one is ignored without penalty.

Which addresses advertise:

| Configuration | `NODE_P2P_WS` |
| ------------- | ------------- |
| A `-p2pwsbind` address that is not loopback-only (public or private LAN) | set — peers dial `ws://<address they see>:<port>`, so behind NAT the port must be forwarded |
| Only loopback `-p2pwsbind` addresses, with `-p2pwsexternal` | set — the external URL is announced |
| Only loopback `-p2pwsbind` addresses, no `-p2pwsexternal` | not set |

Even when set, the bit and `wsendpoint` are withheld on Tor, I2P and CJDNS connections and on outbound connections made through a proxy, so the clearnet endpoint is never linked to a privacy-network identity; the node's `version` and self-advertised `addr` on those connections omit the bit. `naviod` warns when `-p2pwsexternal` is combined with `-proxy`.

## p2pmsg overlay messages

| Message      | Purpose |
| ------------ | ------- |
| `p2pmsg`     | Encrypted overlay envelope, fluff phase |
| `dp2pmsg`    | Same envelope, Dandelion++ stem phase |
| `p2pmsgchal` | Per-connection challenge an archiving node sends after the handshake |
| `getp2pmsgs` / `p2pmsgs` | Archive query (PoW-stamped, keyed by a fuzzy-message-detection key) and response |

Details: [P2P encrypted messaging](p2p-messaging.md).
