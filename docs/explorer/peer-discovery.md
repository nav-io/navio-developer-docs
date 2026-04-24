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

`P2P_MAINNET_MAGIC_HEX` (default `bd5fc300`) and `P2P_TESTNET_MAGIC_HEX` (default `1c03bb83`). The magic bytes open every P2P message; sending the wrong magic results in the peer ignoring or banning us. Override with `P2P_MESSAGE_MAGIC_HEX` if a cut of testnet changes magic.

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
