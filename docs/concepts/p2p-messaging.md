# P2P encrypted messaging

Navio nodes carry an **application-agnostic encrypted broadcast overlay** on top of the normal P2P network. It is the transport under aggregation cover-traffic, RFQ token swaps, and standing orders — but the relay layer itself is deliberately kind-blind: it forwards any well-formed message to its peers regardless of whether it understands or can decrypt the payload.

!!! info "Optional and gated"
    The subsystem is enabled by default and turned off with `-p2pmsg=0`. Participation is advertised via a service bit, so enabling it is network-visible (see [Routing](#routing-dandelion-stem)). Message *contents* and a node's role in any given message are not.

## The bus

Every message is an opaque, length-bucket-padded envelope with three parts:

| Field       | Purpose                                                             |
| ----------- | ------------------------------------------------------------------- |
| `kind` (u8) | Opaque application id. The relay never inspects it beyond keying handler dispatch. Kinds `0..6` are this build's apps (PING, aggregation, RFQ, orders); `7..255` are reserved for future apps. |
| `pow`       | Hashcash-style proof-of-work stamp over the payload + a timestamp.  |
| `enc`       | 1-layer ECIES ciphertext (BLS ephemeral ECDH + ChaCha20-Poly1305 + HKDF). |

A node that receives a new, valid message **relays it to every peer except the origin** (kind-blind flood), then hands it to the local handler for its `kind` if one is registered. A replay cache breaks the relay loop and bounds re-processing. Because relay is kind-blind, a new application simply claims a new `kind` byte and ships a handler in a wallet or daemon — existing nodes propagate it network-wide **with no protocol upgrade**.

### Proof-of-work admission

PoW is mandatory on *every* message and is the universal admission gate that keeps kind-blind relay safe: it prices each message so a sender cannot make the network fan traffic out for free. Navio is Proof-of-Stake, so chain difficulty is not a CPU-cost anchor — the target is a flat leading-zero-bits threshold, runtime-tunable with `-p2pmsgpowbits` (regtest defaults to a trivial difficulty so tests don't grind). A malformed or under-PoW message is dropped and DoS-scored; a merely stale timestamp is dropped **without** penalising the relaying peer, so an honest message that aged in flight doesn't get good nodes banned.

## Crypto: identity / prekey split

The inbox a peer encrypts to is split into two keys:

-   An **identity key** — the node's stable address. It signs prekeys. By default it is **ephemeral per run** (nothing at rest); with `-p2pmsgpersistidentity` the identity scalar is stored in `<datadir>/p2pmsg_identity.dat` (owner-only) so the address survives restarts — an explicit opt-in that trades the not-on-disk property for durable reachability.
-   A rotating **inbox prekey** — the key peers actually encrypt confidential messages to. `getp2pmsginfo` publishes the bundle `{identity_pubkey, inbox_pubkey (= prekey), prekey_sig}`; a sender verifies `prekey_sig` under `identity_pubkey` before encrypting, so a substituted prekey is rejected.

Rotating the prekey bounds two things without disturbing reachability: confidential replies are linkable to one node only within an epoch, not for the whole run; and an in-memory prekey extraction decrypts at most the current epoch plus a bounded grace window (retired prekeys are dropped). Because the prekey is a contact address, **rotation is manual by default** — trigger a privacy reset with the `rotatep2pmsginbox` RPC, or opt into periodic rotation with `-p2pmsginboxrotation=<secs>`.

### Forward secrecy posture

Each message uses a fresh ephemeral sender key (ephemeral-static ECDH), so a sender's key never sits at rest. The recipient prekey is static between rotations, so within-epoch replies are not individually forward-secret; rotation bounds a key-extraction to one epoch (+ grace). The **session-key path** — RFQ reply keys and aggregation reply keys — already has per-exchange forward secrecy today, because those keys are per-request and dropped after use. Full per-message forward secrecy on inbox traffic would need an ephemeral-ephemeral (X3DH-style) handshake, which is a poor fit for a serverless flood overlay (no directory to distribute one-time prekeys) and is tracked as future work.

## Routing: Dandelion++ stem

In the **fluff** phase a message floods every eligible peer. In the **stem** phase it forwards to a **single successor pinned for the whole epoch** (Dandelion++), not a fresh random successor per message — so an adversary watching a node's stem traffic cannot separate the messages it *originated* from the ones it merely *relayed*. The successor is re-rolled only when the epoch rolls over or the pinned peer becomes ineligible; if no eligible successor exists (or the pinned one is the peer a message arrived from), the node fluffs instead of dead-ending.

### The `NODE_P2PMSG` service bit

Capability is advertised via the `NODE_P2PMSG` service flag, and routing goes only to peers that set it — a non-supporting node silently drops these messages. The bit means the node **relays** the overlay; it does *not* promise the node serves candidates (that is the separate `-servecandidates` behaviour). Because service flags ride ADDR gossip, enabling `-p2pmsg` makes participation enumerable network-wide. `getp2pmsginfo` reports `relay_capable_peers`, a lower bound on participation since capability propagates via ADDR beyond direct peers.

## Applications on the bus

### Cover-traffic aggregation

Nodes with loaded BLSCT wallets can **serve fee-0 cover candidates** — signed self-spends of one real unspent output — in response to pull requests, so a real aggregated send is mixed with decoys. Serving is on by default (`-servecandidates=0` to opt out) and bounded against enumeration by a rolling per-window coin budget, so repeated pulling saturates instead of walking the coin set. Ephemeral reply keys + Dandelion stem routing mean there is no stable per-requester identity; the per-peer request cap and FIFO claim order are local flood/fairness controls, not per-origin accounting.

### RFQ token swaps

Takers broadcast quote requests and makers reply with signed quotes over the overlay; matching is config-only, so probing cannot binary-search a maker's balance. See [Token trading (RFQ swaps)](../sdk/trading.md) in the SDK docs for the client side.

### Standing orders

Broadcast standing orders are cached and re-served by relaying nodes, propagating with the same kind-blind relay as everything else.

## RPCs & configuration

| RPC                  | Purpose                                                              |
| -------------------- | ------------------------------------------------------------------- |
| `getp2pmsginfo`      | Subsystem state: identity pubkey, inbox prekey, prekey signature, ping counter, `relay_capable_peers`. |
| `rotatep2pmsginbox`  | Rotate the inbox prekey now (manual privacy reset).                 |
| `sendp2pping`        | Debug echo to a given inbox pubkey.                                 |

| Option                        | Default | Effect                                                        |
| ----------------------------- | ------- | ------------------------------------------------------------- |
| `-p2pmsg`                     | on      | Enable the encrypted messaging subsystem.                     |
| `-p2pmsgpersistidentity`      | off     | Keep a stable node identity across restarts (`<datadir>/p2pmsg_identity.dat`). |
| `-p2pmsginboxrotation=<secs>` | 0       | Opt into periodic prekey rotation (0 = manual only).          |
| `-p2pmsgpowbits=<n>`          | tuned   | Anti-spam PoW difficulty (leading zero bits).                 |
| `-servecandidates`            | on      | Answer aggregation pull requests with fee-0 cover candidates. |

## Security posture at a glance

-   **Unlinkability**: 1-layer ECIES + Dandelion++ stem + a rotating prekey under a per-run-ephemeral identity. Weaker than onion routing against a global passive adversary; an optional mix layer is future work.
-   **DoS**: mandatory per-message PoW, a global relay token bucket capping this node's amplification, DoS scoring for malformed/under-PoW messages, silent drop on MAC failure, and bounded queues/caches that drop rather than grow.
-   **Participation is public**, contents are not: the `NODE_P2PMSG` bit makes "who relays the overlay" enumerable, but message contents and per-message roles stay hidden.
-   **Crypto**: per-message ephemeral BLS ECDH + ChaCha20-Poly1305 + HKDF, with the `kind` byte bound as AEAD associated data and length-bucket padding. No post-quantum primitives yet.
