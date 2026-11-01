# Peer discovery

The explorer maintains a map of network peers for the `/network` page. Two discovery paths:

1.  **naviod-hosted peer list** — `getpeerinfo` reports currently-connected peers.
2.  **Direct P2P crawl** — seeder-style discovery across the wider network, not limited to peers of the local node.

The second is necessary because `getpeerinfo` only sees ~8–125 peers. A full-chain network map needs to reach thousands.

## Direct P2P crawl

Configurable via [env vars](self-host.md#environment-variables) — `P2P_*`, `PEER_*`. Overview:

### Round structure

```
for round in 1..PEER_DISCOVERY_ROUNDS:
    candidates = select up to PEER_DISCOVERY_BATCH_SIZE nodes
                 from the known set, prioritising unseen / unchecked

    in parallel (P2P_CRAWL_CONCURRENCY workers):
        for candidate:
            tcp connect with PEER_CONNECT_TIMEOUT_MS
            send version message with P2P_PROTOCOL_VERSION, magic P2P_{MAIN,TEST}NET_MAGIC_HEX
            receive version + verack within P2P_REQUEST_TIMEOUT_MS
            send getaddr
            receive addr (up to 1000 addresses)
            merge new addresses into known set

    sleep PEER_DISCOVERY_WAIT_MS
```

Cap the total candidate set at `PEER_DISCOVERY_MAX_CANDIDATES` to bound memory.

### Connectivity probe

Separate stage from the handshake crawl. After discovery:

```
for up to PEER_CONNECT_TEST_LIMIT peers:
    TCP connect with PEER_CONNECT_TIMEOUT_MS
    if PEER_DISCOVERY_FILTER_UNREACHABLE: drop on failure
```

This separates "peer exists in the address manager" from "peer is currently reachable from our vantage point".

### Geolocation

For each new peer, look up the IP in `ip-api.com` with local caching. Rate-limited to `PEER_GEO_LOOKUP_LIMIT` uncached queries per cycle to stay within free-tier quotas. Cache hits are not counted.

The peers table stores `latitude`, `longitude`, `country`, `city`, `isp` — sent to the frontend for the interactive map.

### Network magic

`P2P_MAINNET_MAGIC_HEX` (default `bd5fc300`) and `P2P_TESTNET_MAGIC_HEX` (default `2467d2c1`). The magic bytes open every P2P message; sending the wrong magic results in the peer ignoring or banning us. Override with `P2P_MESSAGE_MAGIC_HEX` if a cut of testnet changes magic.

### Handshake refresh

A peer's record is refreshed by the explorer's own `version` handshake, not only by `addr` gossip:

-   Peers marked reachable by the TCP probe get a handshake while their user agent is unknown, and the crawl spends its handshake budget on the most recently seen addresses first.
-   A known user agent is never blanked by a later gossip-only sighting.
-   Service bits from a handshake are authoritative. Bits learned only from gossip (no `proto=` tag) trigger a fresh handshake for reachable peers, so a node that turns on a service (for example `-p2pmsgarchive` or `-v2transport`) shows its new badges after the next crawl instead of waiting for gossip to spread.
-   Gossip entries older than the 7-day retention window are dropped before geolocation, and `/api/nodes`, `/api/nodes/map` and the node-count snapshot all count only peers seen within the same 7 days, so the Total Nodes card and the history chart agree.

## Service bits {#service-bits}

`/api/nodes` decodes each peer's advertised services into `service_flags`, whether they came from `getpeerinfo` names, `UNKNOWN[2^n]` entries from an older node, or a raw bitmask from the crawl. The Network page shows a **Navio Service Bits** distribution card and a **Navio Services** badge column (union per /24 group):

| Bit | Flag                  | Badge meaning                                                |
| --- | --------------------- | ------------------------------------------------------------ |
| 11  | `NODE_P2P_V2`         | BIP324 encrypted transport                                   |
| 24  | `NODE_P2PMSG`         | p2pmsg relay, envelope v1 (legacy)                           |
| 25  | `NODE_P2PMSG_LEAF`    | p2pmsg leaf (client that should not be used as a stem hop)   |
| 26  | `NODE_P2PMSG_ARCHIVE` | Archives flagged p2pmsg envelopes for offline retrieval      |
| 27  | `NODE_P2PMSG_V2`      | p2pmsg relay, envelope v2                                    |
| 30  | `NODE_P2P_WS`         | WebSocket P2P listener; shown as `ws :port` / `wss :443` with the dialable URL on hover |

The WebSocket endpoint is captured from the node's `wsendpoint` announcement during the crawl, or from `ws_port` / `ws_url` in `getpeerinfo`, and exposed per peer as `ws_endpoint`. See [P2P encrypted messaging](../concepts/p2p-messaging.md) for the p2pmsg roles.

## Node counts

After every crawl the indexer stores a snapshot in `node_stats`, deduplicated per IP with the same rules as `/api/nodes`: **total** known nodes, **listening** (reachable) nodes, and **active** nodes (listening or handshaken within the last 3 hours). `/api/nodes/history` buckets the snapshots and the Network page charts all three series.

## Bootstrap seeds

Initial candidate set for the crawl. Testnet default:

```
testnet.nav.io
testnet2.nav.io
```

Mainnet: set `MAINNET_BOOTSTRAP_NODES` to whatever your deployment considers authoritative (typically the same DNS seeds `naviod` uses).

## Privacy notes

-   The crawl reveals the explorer operator's IP to every probed peer. For hidden operation, route the crawl through Tor (set `P2P_PROXY=socks5://localhost:9050` — note: not implemented in the default indexer, but the pattern is straightforward to add).
-   The explorer publishes IP + approximate geolocation of peers. Operators who want their node invisible should run `naviod` with `-listen=0` and connect only via outbound — such nodes will not appear in the `/network` map.

## Tuning for a public deployment

-   Increase `PEER_DISCOVERY_ROUNDS` to 5–8 for more coverage at the cost of longer cycle time.
-   Raise `P2P_CRAWL_CONCURRENCY` on a high-bandwidth host.
-   Keep `PEER_GEO_LOOKUP_LIMIT` ≤ 100/min if using free ip-api; sign up for a paid plan for a production deployment.
