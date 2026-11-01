# P2P encrypted messaging

Navio nodes carry an **application-agnostic encrypted broadcast overlay** (*p2pmsg*) on top of the normal P2P network. It is the transport under aggregation cover-traffic, RFQ token swaps, standing orders and user messaging — but the relay layer itself is deliberately kind-blind: it forwards any well-formed message to its peers regardless of whether it understands or can decrypt the payload.

!!! info "Optional and gated"
    The subsystem is enabled by default and turned off with `-p2pmsg=0`. Participation is advertised via a service bit, so enabling it is network-visible (see [Service bits](#service-bits)). Message *contents* and a node's role in any given message are not.

!!! note "Version availability"
    Envelope v2 and detection flags, `NODE_P2PMSG_V2`, `NODE_P2PMSG_LEAF`, the envelope archive (`-p2pmsgarchive`, `NODE_P2PMSG_ARCHIVE`, `getp2pmsgs`), the user-messaging RPCs and notifiers, and type-aware cover selection ship in **v0.2.2**. Per-kind recipient-key enforcement, per-scope store budgets and the `store.undecodable` counter are merged on `master` and land in the next release.

## The bus

Every message is an opaque, length-bucket-padded **envelope (version 2)**:

| Field          | Purpose                                                             |
| -------------- | ------------------------------------------------------------------- |
| `kind` (u8)    | Opaque application id. The relay never inspects it beyond keying handler dispatch. Kinds `0..7` are this build's apps (`PING`, `PONG`, `AGG_ANN`, `CANDIDATE_TX`, `RFQ_REQ`, `RFQ_QUOTE`, `ORDER_ANN`, `USER_DATA`); `8..255` are reserved. |
| `pow`          | Hashcash-style proof-of-work header (version 2) over the payload, the flag and a timestamp. |
| `flen`, `flag` | Optional fuzzy-message-detection flag (83 bytes when present, empty otherwise) — see [Offline retrieval](#offline-retrieval-detection-flags-and-the-archive). |
| `enc`          | 1-layer ECIES ciphertext (BLS ephemeral ECDH + ChaCha20-Poly1305 + HKDF). |

A node that receives a new, valid message **relays it to every eligible peer except the origin** (kind-blind flood), then hands it to the local handler for its `kind` if one is registered. A replay cache keyed on `(kind, payload hash)` breaks the relay loop. Because relay is kind-blind, a new application simply claims a new `kind` byte and ships a handler in a wallet or daemon — existing nodes propagate it network-wide **with no protocol upgrade**.

!!! warning "Envelope v1 is not interoperable"
    Envelope v1 (v0.2.1 and older) has no flag field and a v1 PoW header. Current builds reject v1 envelopes outright, and v1 nodes cannot parse v2. The two formats use different service bits (`NODE_P2PMSG` vs `NODE_P2PMSG_V2`), so the v1 and v2 overlays stay **disjoint**: aggregation cover, RFQ quotes and user messages only reach peers running the same envelope version.

### Proof-of-work admission

PoW is mandatory on *every* message and is the universal admission gate that keeps kind-blind relay safe: it prices each message so a sender cannot make the network fan traffic out for free. Navio is Proof-of-Stake, so chain difficulty is not a CPU-cost anchor — the target is a flat leading-zero-bits threshold (default **23 bits**, ~100–200 ms of CPU), tunable with the debug option `-p2pmsgpowbits` (regtest uses trivial difficulty). The v2 header hashes the ciphertext together with the flag, so a relay can neither strip nor rewrite a flag without redoing the work. A malformed or under-PoW message is dropped and DoS-scored; a merely stale timestamp (outside ±120 s) is dropped **without** penalising the relaying peer.

### Recipient key classes

Each kind is accepted only when it decrypts under the key class its senders use; a message that decrypts under any other class is dropped before its handler runs (relay is unaffected — every kind is still relayed). SDKs and light makers must encrypt to the class shown:

| Kind           | Value | Accepted under |
| -------------- | ----- | -------------- |
| `PING`         | 0     | inbox key |
| `PONG`         | 1     | none (relayed only) |
| `AGG_ANN`      | 2     | broadcast key |
| `CANDIDATE_TX` | 3     | internal session key carried by the pull request |
| `RFQ_REQ`      | 4     | broadcast key |
| `RFQ_QUOTE`    | 5     | internal session key carried by the RFQ request |
| `ORDER_ANN`    | 6     | broadcast key |
| `USER_DATA`    | 7     | inbox key, broadcast key, or a reply key minted with `mintp2pmsgreplykey` |

"Inbox key" includes previous prekeys still held during the post-rotation grace window. A minted reply key accepts `USER_DATA` only, and internal session keys never accept `USER_DATA`.

## Crypto: identity / prekey split

The inbox a peer encrypts to is split into two keys:

-   An **identity key** — the node's stable address. It signs prekeys. By default it is **ephemeral per run** (nothing at rest); with `-p2pmsgpersistidentity` the identity scalar is stored in `<datadir>/p2pmsg_identity.dat` (owner-only) so the address survives restarts — an explicit opt-in that trades the not-on-disk property for durable reachability.
-   A rotating **inbox prekey** — the key peers actually encrypt confidential messages to. `getp2pmsginfo` publishes the bundle `{identity_pubkey, inbox_pubkey (= prekey), prekey_sig}`; a sender verifies `prekey_sig` under `identity_pubkey` before encrypting, so a substituted prekey is rejected.

Rotating the prekey bounds two things without disturbing reachability: confidential replies are linkable to one node only within an epoch, not for the whole run; and an in-memory prekey extraction decrypts at most the current epoch plus a bounded grace window (retired prekeys are dropped). Because the prekey is a contact address, **rotation is manual by default** — trigger a privacy reset with the `rotatep2pmsginbox` RPC (which also rotates the detection clue key), or opt into periodic rotation with `-p2pmsginboxrotation=<secs>`.

### Forward secrecy posture

Each message uses a fresh ephemeral sender key (ephemeral-static ECDH), so a sender's key never sits at rest. The recipient prekey is static between rotations, so within-epoch replies are not individually forward-secret; rotation bounds a key-extraction to one epoch (+ grace). The **session-key path** — RFQ reply keys, aggregation reply keys and user reply keys minted with `mintp2pmsgreplykey` — has per-exchange forward secrecy, because those keys are per-request and dropped after use. Full per-message forward secrecy on inbox traffic would need an ephemeral-ephemeral (X3DH-style) handshake, which is a poor fit for a serverless flood overlay and is tracked as future work.

## Routing

### Dandelion++ stem

In the **fluff** phase (`p2pmsg`) a message floods every eligible peer. In the **stem** phase (`dp2pmsg`) it forwards to a **single successor pinned for the whole epoch** (~10 min, with a per-node random phase), not a fresh random successor per message — so an adversary watching a node's stem traffic cannot separate the messages it *originated* from the ones it merely *relayed*. The successor is re-rolled only when the epoch rolls over or the pinned peer disconnects; if no eligible successor exists (or the pinned one is the peer a message arrived from), the node fluffs instead of dead-ending. Each node gives a message at most one stem pass and one fluff pass, so a stem loop between peers turns into a flood instead of dropping the message.

### Service bits

| Bit | Flag                  | Meaning |
| --- | --------------------- | ------- |
| 24  | `NODE_P2PMSG`         | Envelope v1 relay. Not advertised by current builds; they do not route to peers that set only this bit. |
| 25  | `NODE_P2PMSG_LEAF`    | A client that **receives** fluff traffic but never relays (browser / mobile SDK clients). Relays fluff to leaves but never pick a leaf as a stem successor. A leaf must also set `NODE_P2PMSG_V2` to name the envelope format it reads. |
| 26  | `NODE_P2PMSG_ARCHIVE` | Retains flagged envelopes and serves them with `getp2pmsgs` (`-p2pmsgarchive`). |
| 27  | `NODE_P2PMSG_V2`      | Envelope v2 relay. Set by every node with `-p2pmsg=1`. |

The relay bit means the node **relays** the overlay; it does *not* promise the node serves candidates (that is the separate `-servecandidates` behaviour). Because service flags ride ADDR gossip, enabling `-p2pmsg` makes participation enumerable network-wide. `getp2pmsginfo` reports `relay_capable_peers` (a lower bound on participation), `leaf_peers` and `archive_peers`. Block-relay-only connections carry no p2pmsg traffic.

## Offline retrieval: detection flags and the archive

The bus carries no recipient field, so a node cannot hold messages for an offline peer by address. **Fuzzy message detection** (FMD2, Beck–Len–Miers–Green, over BLS12-381 G1) closes that gap without adding one:

-   The recipient publishes a **clue key** (1152 bytes, in `getp2pmsginfo` with `fmd_sig` signed by the identity key). A sender passes it as the `cluekey` argument of `sendp2pmsg` to attach an 83-byte flag. Senders must verify `fmd_sig` first.
-   The recipient derives a **detection key** at a false-positive rate of its choosing with `getp2pmsgdetectionkey <precision>` (rate `2^-precision`, precision ≤ 24). The key is secret and long-lived: it keeps matching until the clue key rotates with `rotatep2pmsginbox`.
-   Knowing a public clue key does not let anyone test flags; testing needs the detection key.

An **archiving node** (`-p2pmsgarchive=1`, default off) stores the *flagged* envelopes it relays — ciphertext it cannot read — in a LevelDB store bounded by `-p2pmsgarchivesize` (MiB, default 4096) and `-p2pmsgarchiveexpiry` (days, default 14), pruned oldest-first, and advertises `NODE_P2PMSG_ARCHIVE`. Clients query it over P2P:

-   After the handshake the archive sends `p2pmsgchal`, a per-connection challenge.
-   `getp2pmsgs` carries a cursor, a match limit, a scan budget, the detection key and a proof-of-work stamp that commits to every field and to the challenge. The stamp's difficulty grows with the scan requested (base `-p2pmsgarchivepowbits`, defaulting to the bus difficulty, up to base + 8).
-   `p2pmsgs` returns matches, `next_cursor` (the highest id *scanned*) and a `complete` flag. Hard caps: 500 entries returned, 50,000 scanned, 2 MiB per response; 3-query burst, 6 per minute per peer (excess is dropped silently).

The archive learns the requester's detection key (and so can test future flags at that precision until the clue key rotates), a match set that mixes the requester's messages with a `2^-precision` share of everyone else's, and the requester's address and timing. A query sent over a v1 (plaintext) link exposes the detection key to on-path observers, so clients should use BIP324 (`-v2transport`) or TLS in front of a WebSocket listener. `naviod` itself never sends `getp2pmsgs` — a full node reads its own messages from its local inbox.

## Applications on the bus

### Cover-traffic aggregation

Nodes with loaded BLSCT wallets **serve fee-0 cover candidates** — signed 1-in/1-out self-spends of one real unspent output — so a real send is mixed with decoys. The loop is pull-based:

1.  **Pull.** A background puller (`-candidatepullinterval`, default 60 s) broadcasts an `AGG_ANN` request carrying a fresh reply key while the node's **candidate pool** holds fewer than 20 candidates. Pulling runs on a fixed cadence, independent of sends.
2.  **Serve.** On by default (`-servecandidates=0` to opt out). Each request is answered with a `CANDIDATE_TX` encrypted 1:1 to the reply key, bounded by a per-input reservation and a rolling per-window coin budget so repeated pulling saturates instead of walking the coin set. Coins are picked uniformly at random.
3.  **Collect.** Candidates are pooled only if they decrypted under one of the node's own pull session keys. The pool holds at most 512 candidates (sharded, deduplicated by input, first-seen wins) and evicts a candidate as soon as its input is spent in the mempool or a block. Pool contents are node-private.
4.  **Aggregate.** With `-aggregatesends=1` (default) every wallet BLSCT send picks a random subset of the pool, over-funds its own fee to cover the combined weight, and broadcasts one aggregate with a single shuffled fee output. If the pool is empty or the merge fails, the send goes out as a plain transaction — aggregation never blocks a payment.

Cover selection is sized and typed to the send:

-   **Count:** one cover per 4 of the send's own inputs (rounded up), capped at 16 covers per aggregate.
-   **Type:** whether a spent output came from a block reward is public, so the wallet re-picks covers to mirror its own input mix (reward-backed vs transfer-backed), topping up from the other type when one runs short.

Serving trades some wallet-clustering resistance for aggregation supply: each served candidate proves to its requester that the node owns one specific output. The per-peer request cap and the rolling budget bound how fast an active puller can learn a wallet's coins; operators who do not want this exposure set `-servecandidates=0`. See [Outpoint model → Wallet behaviour for merged sends](outpoint.md#wallet-behaviour-for-merged-sends) for how the wallet handles an aggregate that conflicts or expires.

### RFQ token swaps

Takers broadcast quote requests and makers reply with signed quotes over the overlay; matching is config-only, so probing cannot binary-search a maker's balance. See [Atomic swaps](atomic-swaps.md) and [Token trading (RFQ swaps)](../sdk/trading.md).

### Standing orders

Broadcast standing orders are cached (14-day cap, evicted when an input is spent) and re-served by relaying nodes. `listorders verbose=true` exposes the cache.

### User messaging

The bus carries application payloads as `USER_DATA`, so a chat or notification client can be built on RPC polling alone. A payload is **topic-framed**: the node interprets only the topic; sender identity, threading and reply addresses belong in the application body (`sender_session` in results is the per-message ephemeral key, **not** a reply address). Topic plus body is limited to **3584 bytes** serialized; applications chunk larger data.

`sendp2pmsg <recipient> <topic> <payload_hex> [stem=true] [cluekey]` selects the **delivery mode** with `recipient`:

| Mode | `recipient` | Stored as scope |
| ---- | ----------- | --------------- |
| Confidential 1:1 | the recipient's inbox prekey (verify its `prekey_sig` first) | `inbox` |
| 1:1 without exposing the inbox | a reply key the recipient minted with `mintp2pmsgreplykey [ttl=3600]` | `session` |
| Public pub/sub | the literal `"broadcast"` | `broadcast` |

Inbox and session messages are always stored. Broadcast messages are relayed regardless but **stored only for subscribed topics**: `subscribep2pmsgtopic`, `unsubscribep2pmsgtopic`, `listp2pmsgtopics`, or `-p2pmsgtopic=<topic>` (repeatable) at startup.

**Store.** Received messages go to a LevelDB store (`<datadir>/p2pmsg_inbox`) that survives restarts. `listp2pmsgs [since_id] [max_count] [topic]` returns them oldest-first with monotonic ids; `getp2pmsginfo`'s `store.last_id` is a cursor for "only new messages". `clearp2pmsgs [up_to_id]` is optional compaction, not an acknowledgement: `0` drops everything, so pass the highest id you read. Bounds:

-   `-p2pmsgstoresize` (MiB, default 64; `0` disables the store and `USER_DATA` handling) is split into per-scope budgets — inbox 40 %, session 40 %, broadcast 20 % — and each scope prunes only its own oldest messages, so a flood of one kind cannot evict another.
-   `-p2pmsgstoreexpiry` (days, default 30; `0` = no age limit).
-   Entries this node cannot decode are kept but not returned, and are counted in `store.undecodable`.

**Notifiers.** `-zmqpubp2pmsg=<address>` publishes each stored message (serialized store entry) on ZMQ topic `p2pmsg`; `-p2pmsgnotify=<cmd>` runs a command per stored message with `%s` replaced by the message id (fetch the content with `listp2pmsgs`; the payload never reaches the shell).

## RPCs & configuration

| RPC                         | Purpose |
| --------------------------- | ------- |
| `getp2pmsginfo`             | Identity pubkey, inbox prekey + `prekey_sig`, clue key + `fmd_sig`, peer counts (`relay_capable_peers`, `leaf_peers`, `archive_peers`), `archive` and `store` objects. |
| `rotatep2pmsginbox`         | Rotate the inbox prekey and clue key now. |
| `getp2pmsgdetectionkey`     | Derive a detection key at a chosen precision (secret). |
| `sendp2pmsg`                | Send a topic-framed user message (inbox / reply key / broadcast). |
| `mintp2pmsgreplykey`        | Mint a short-lived reply key for `session` delivery. |
| `listp2pmsgs` / `clearp2pmsgs` | Read / compact the message store. |
| `subscribep2pmsgtopic` / `unsubscribep2pmsgtopic` / `listp2pmsgtopics` | Manage stored broadcast topics. |
| `sendp2pping`               | Debug echo to a given inbox pubkey. |

| Option                          | Default | Effect |
| ------------------------------- | ------- | ------ |
| `-p2pmsg`                       | `1`     | Enable the subsystem and advertise `NODE_P2PMSG_V2`. |
| `-p2pmsgpersistidentity`        | `0`     | Keep a stable identity across restarts (debug option). |
| `-p2pmsginboxrotation=<secs>`   | `0`     | Periodic prekey rotation; `0` = manual only (debug option). |
| `-p2pmsgpowbits=<n>`            | `23`    | Anti-spam PoW difficulty (debug option). |
| `-p2pmsgstoresize=<MiB>`        | `64`    | User-message store size; `0` disables it. |
| `-p2pmsgstoreexpiry=<days>`     | `30`    | User-message retention. |
| `-p2pmsgtopic=<topic>`          | —       | Subscribe to a broadcast topic at startup (repeatable). |
| `-p2pmsgnotify=<cmd>`           | —       | Run a command per stored message. |
| `-zmqpubp2pmsg=<address>`       | —       | ZMQ publisher for stored messages. |
| `-p2pmsgarchive`                | `0`     | Retain and serve flagged envelopes; advertise `NODE_P2PMSG_ARCHIVE`. |
| `-p2pmsgarchivesize=<MiB>`      | `4096`  | Archive size cap. |
| `-p2pmsgarchiveexpiry=<days>`   | `14`    | Archive retention (the offline catch-up window). |
| `-p2pmsgarchivepowbits=<n>`     | `-p2pmsgpowbits` | Base PoW for archive queries (debug option). |
| `-servecandidates`              | `1`     | Answer aggregation pull requests with cover candidates. |
| `-aggregatesends`               | `1`     | Merge cover candidates into wallet sends. |

Full RPC reference: [RPC → p2pmsg](../rpc/p2pmsg.md).

## Security posture at a glance

-   **Unlinkability**: 1-layer ECIES + Dandelion++ stem + a rotating prekey under a per-run-ephemeral identity. Weaker than onion routing against a global passive adversary; an optional mix layer is future work.
-   **DoS**: mandatory per-message PoW, a global relay token bucket capping this node's amplification, DoS scoring for malformed/under-PoW messages, silent drop on MAC failure, bounded queues/caches/stores that drop rather than grow, and separately priced, rate-limited archive queries.
-   **Participation is public**, contents are not: the p2pmsg service bits make "who relays / archives the overlay" enumerable, but message contents and per-message roles stay hidden.
-   **Archives** hold only ciphertext and learn recipients only as precisely as a requester's detection key allows.
-   **Crypto**: per-message ephemeral BLS ECDH + ChaCha20-Poly1305 + HKDF, with the `kind` byte bound as AEAD associated data and length-bucket padding. No post-quantum primitives yet.
