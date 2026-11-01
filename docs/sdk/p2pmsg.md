# Messaging library — `navio-p2pmsg`

Standalone TypeScript library for Navio's [p2pmsg encrypted broadcast bus](../concepts/p2p-messaging.md). It connects straight to Navio P2P nodes — TCP in Node.js, WebSocket in the browser — with no full node, no Electrum server and no wallet. It is application-agnostic: it gives an app identity, addressing, end-to-end encryption, reliable 1:1 delivery and public pub/sub on top of the bus, plus optional chat, group and multi-device layers.

-   **Repository**: [nav-io/navio-p2pmsg](https://github.com/nav-io/navio-p2pmsg)
-   **Package**: `navio-p2pmsg` on npm — latest **0.2.0** (2026-09-27)
-   **License**: MIT

```bash
npm install navio-p2pmsg
```

Node.js ≥ 20. Browser builds need a bundler; the proof-of-work worker is a separate entry (`navio-p2pmsg/bus/pow-worker`) passed as `workerUrl`.

!!! warning "0.2.x needs Navio Core v0.2.2 or later"
    0.2.0 sends **envelope v2** and routes only to peers advertising `NODE_P2PMSG_V2`, which ships in [Navio Core v0.2.2](https://github.com/nav-io/navio-core/releases/tag/v0.2.2). Against an older node a 0.2.x client connects, drops every peer as unable to relay its envelope format, and sends nothing. This is deliberate: an older node penalises envelopes it cannot parse. For v0.2.1 nodes, stay on `navio-p2pmsg@0.1.x`, which speaks v1. The two overlays are disjoint.

## Node requirements

| Feature                          | Node option (off by default in `naviod`)          |
| -------------------------------- | ------------------------------------------------- |
| Browser clients (WebSocket)      | `-p2pwsbind=<addr>[:<port>]`                      |
| Offline delivery (`syncArchive`) | `-p2pmsgarchive` on at least one reachable node   |
| Archive queries                  | `-v2transport=1` on that node — the client refuses to send a detection key over a plaintext link |

## Quick start

```ts
import { MessagingClient, FileStore, utf8, fromUtf8 } from 'navio-p2pmsg';

const client = await MessagingClient.create({
    network: 'mainnet',                       // 'mainnet' | 'testnet' | 'regtest'
    seed,                                     // 32 bytes you generated and backed up
    store: await FileStore.open('./state.json'),
    // peers: ['wss://node.example.org'],     // browser: WebSocket-enabled nodes
});

client.on('message', (m) => console.log(m.from, m.topic, fromUtf8(m.payload)));
client.on('ack', (a) => console.log('delivered', a.msgId));
await client.connect();

console.log(client.identity);       // navid1…  — share this
console.log(client.bundle());       // navmsg1… — identity + prekey + signature

await client.addContact('navmsg1…');          // or a navid1…; the prekey is discovered over the bus
await client.send('navid1…', utf8('hello'));

client.subscribe('news', (m) => console.log('news:', fromUtf8(m.payload)));
await client.publish('news', utf8('hello world'));

// Fetch what arrived while this client was offline (needs an archive peer)
await client.syncArchive({ precision: 8 });
```

## What it provides

-   **Identity** — a stable BLS identity key and a rotating inbox prekey, both derived from the seed. `navid1…` is the address; `navmsg1…` the full bundle. `rotatePrekey()` rotates manually.
-   **Discovery** — given only a `navid1…`, the prekey is fetched over the bus (anonymous request, signed response). The request is encrypted to the target's identity key, so its topic is not visible on the bus.
-   **Encryption** — per-message ephemeral ECIES (BLS12-381 ECDH + HKDF + ChaCha20-Poly1305), byte-compatible with `naviod`, with length-bucket padding.
-   **Authentication** — every 1:1 message carries the sender's identity and a BLS signature bound to topic and recipient. Unsigned (anonymous) sends are possible but cannot be acked.
-   **Reply keys** — every message carries a fresh single-use reply key; replies use it instead of the static prekey.
-   **Reliable delivery** — signed, batched acks; unacked messages are re-sent with backoff until acked or the TTL (default 24 h) expires.
-   **Offline delivery** (0.2.0) — envelopes carry a fuzzy-message-detection flag (FMD2 over BLS12-381 G1) that names no recipient. Nodes advertising `NODE_P2PMSG_ARCHIVE` keep flagged envelopes; `syncArchive()` retrieves them with a per-peer, per-detection-key cursor and a query proof of work bound to a per-connection challenge.
-   **Chunking** — payloads above ~3.3 KB are split (default max 16 chunks).
-   **Pub/sub** — public topics readable by every bus participant; reserved `_p2pmsg/*` topics carry discovery and acks.
-   **Proof of work** — the bus's mandatory anti-spam stamp is ground in worker threads.
-   **Transport** — BIP324 v2 transport by default (`transportVersion: 'v2'`, falls back to v1 per address; `'v2-only'` refuses v1). The client advertises `NODE_P2PMSG_LEAF` plus `NODE_P2PMSG_V2`, so relays never pick it as a stem hop.

`SendOptions`: `topic`, `ttlMs`, `sign` (default true), `stem` (Dandelion stem, default true), and a flag toggle that saves 83 bytes per envelope when offline retrieval does not matter.

## Layers

| Import                    | Contents                                                                                     |
| ------------------------- | -------------------------------------------------------------------------------------------- |
| `navio-p2pmsg`            | `MessagingClient` and everything in `net`, `bus`, `usermsg`, `stores`                        |
| `navio-p2pmsg/usermsg`    | `USER_DATA` frames, keyring, bundle codecs, outbox, contacts                                 |
| `navio-p2pmsg/bus`        | `BusClient`, ECIES, PoW, BLS, envelope, FMD — raw access to any message `kind`               |
| `navio-p2pmsg/net`        | `PeerPool`, `Peer`, TCP / WebSocket transports, P2P codec, BIP324                            |
| `navio-p2pmsg/stores`     | `Store` interface, `MemoryStore`, `FileStore`, `IndexedDBStore`                              |
| `navio-p2pmsg/archive`    | `ArchiveClient`, the `getp2pmsgs` / `p2pmsgs` codecs (0.2.0)                                 |
| `navio-p2pmsg/chat`       | `ChatClient`: conversations, replies, edits, reactions, deletes, read receipts, search, profiles, contact requests, blocking, groups (0.2.0) |
| `navio-p2pmsg/devices`    | Account-epoch key schedule, signed device lists, pairing offers with a short authentication string, revocation (0.2.0) |
| `navio-p2pmsg/backup`     | BIP39 seed phrases, passphrase-encrypted state export (0.2.0)                                |
| `navio-p2pmsg/stream`     | Direct-channel transport seam, resumable file transfer, typing / presence (0.2.0; no WebRTC backend included) |

### Chat and groups

```ts
import { ChatClient } from 'navio-p2pmsg/chat';

const chat = await ChatClient.create({ client, store });
await chat.sendText('navid1…', 'hi');
const { messages, gaps } = await chat.history(chat.conversationWith('navid1…'));
const groupId = await chat.createGroup('team', ['navid1…', 'navid1…']);
```

Messages are ordered in a causal DAG with gap detection. A group's epoch secret derives its encryption, detection and content keys, so one envelope and one proof of work serve the whole group; membership is hash-chained and removal triggers a rekey.

### Multiple devices

A primary device starts pairing with `startPairing()`; the new device calls `requestPairing(offer, label)` and both show a short authentication string that the user must compare before `confirmPairing`. A secondary is created with `grant` + `device` instead of `seed`: it decrypts everything the primary does but signs with its own device key, checked against the account's signed device list. `revokeDevice` rotates every derived key. Sent messages are mirrored to the account's other devices (`mirrored` event), and a new device can backfill and verify history itself.

## Interop with `naviod`

A `USER_DATA` frame addressed to the client whose body is not a library AuthFrame — for example one sent with `naviod`'s `sendp2pmsg` RPC — is surfaced as an unauthenticated `raw` event. See [P2P messaging commands](../rpc/p2pmsg.md).

## Further reading

The repository's `DESIGN.md` covers the v1 wire spec and layers; `docs/` covers v2 (`wire-v2.md`, `fmd.md`, `archive.md`, `devices.md`, `groups.md`, `chat.md`, `stream.md`) and `security.md`, which records what remains observable — traffic-class fingerprints, the chunk-count size leak, and that a group detection key selects the whole group's mail.

## Releases

-   **0.2.0** (2026-09-27) — envelope v2 + fuzzy message detection, archive retrieval, chat / groups / devices / backup / stream layers, BIP324 on by default. Wire-incompatible with 0.1.x. Requires Navio Core v0.2.2+.
-   **0.1.0** (2026-09-17) — initial release: `net`, `bus`, `usermsg`, `stores`.
