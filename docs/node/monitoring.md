# Monitoring

!!! info "Service manager"
    Examples on this page do not assume systemd. Navio documentation deliberately avoids systemd-centric tooling — the project's stance is that operators should choose their own init / supervisor (runit, OpenRC, s6, supervisord, launchd, Docker, plain `tmux`/`screen`, or a release-specific service manager). Substitute your supervisor's log / restart commands where needed.

## Health checks

### RPC liveness

```bash
navio-cli getblockchaininfo | jq '.blocks, .headers, .initialblockdownload, .verificationprogress'
```

Healthy:

-   `blocks == headers` (or within a small lag).
-   `initialblockdownload: false`.
-   `verificationprogress: 1.0`.

### Peer count

```bash
navio-cli getconnectioncount
```

`< 8` is a warning; `< 2` is effectively disconnected. `getnetworkinfo.networks` confirms reachable address families.

### Mempool

```bash
navio-cli getmempoolinfo | jq '.size, .bytes, .usage, .mempoolminfee'
```

### Staking

Navio does **not** ship a `getstakinginfo` RPC. Verify the staker is functioning by inspecting:

-   The `navio-staker` process's own stdout/stderr — it logs each template poll, eligibility check, and submit result.
-   `navio-cli listtransactions "*" 50 0 true | jq '[.[] | select(.category == "stake")] | length'` — count of recent stake rewards received by this wallet.
-   Block-height advancement at the expected rate (~120 s on mainnet and testnet).
-   The staker's own log for connection backoff: `Lost connection to the node` / `Reconnected to the node after N failed attempt(s)` (next release). Operators in `-delegated` mode can watch the `-statsfile` JSON.

### Peer services

```bash
navio-cli getpeerinfo | jq '.[] | {addr, servicesnames, transport_protocol_type, websocket, ws_port, ws_url}'
```

`servicesnames` shows Navio's service bits (`P2P_V2`, `P2PMSG_V2`, `P2PMSG_LEAF`, `P2PMSG_ARCHIVE`, `OUTKEYS`, `P2P_WS`); `websocket` is `true` for peers connected through `-p2pwsbind`, and `ws_port` / `ws_url` appear for peers that announced a WebSocket endpoint. `getp2pmsginfo` reports overlay health: `relay_capable_peers`, `leaf_peers`, `archive_peers`, and the `store` / `archive` objects. See [P2P protocol](../concepts/p2p-protocol.md#service-bits).

## Metrics via Prometheus

No first-party exporter ships with navio-core. Community options:

-   Custom exporter script polling RPC every 30 s, exposing `/metrics`.
-   Generic blackbox exporter for RPC probing.

Starter Python script:

```python
from prometheus_client import start_http_server, Gauge
import requests, time

RPC = "http://user:pass@127.0.0.1:48471/"  # mainnet; testnet 33677
m_blocks = Gauge("navio_block_height", "Current block height")
m_peers = Gauge("navio_peer_count", "Peer count")
m_mempool = Gauge("navio_mempool_bytes", "Mempool size in bytes")

def rpc(method, params=[]):
    r = requests.post(RPC, json={"jsonrpc": "1.0", "id": "m", "method": method, "params": params})
    return r.json()["result"]

if __name__ == "__main__":
    start_http_server(9190)
    while True:
        try:
            m_blocks.set(rpc("getblockcount"))
            m_peers.set(rpc("getconnectioncount"))
            m_mempool.set(rpc("getmempoolinfo")["bytes"])
        except Exception as e:
            print("scrape error:", e)
        time.sleep(30)
```

## ZMQ publishers

Enable in `navio.conf`:

```ini
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubhashblock=tcp://127.0.0.1:28333
zmqpubrawtx=tcp://127.0.0.1:28334
zmqpubhashtx=tcp://127.0.0.1:28335
zmqpubsequence=tcp://127.0.0.1:28336
zmqpubp2pmsg=tcp://127.0.0.1:28337   # stored p2pmsg user messages, topic "p2pmsg"
```

For p2pmsg user messages there is also a command hook: `p2pmsgnotify=/path/to/script %s` runs once per stored message with the message id (fetch the content with `listp2pmsgs`). See [P2P encrypted messaging → User messaging](../concepts/p2p-messaging.md#user-messaging).

Subscribe with any ZMQ client. Use cases:

-   Trigger explorer re-index on new blocks without polling RPC.
-   Low-latency mempool feeds.
-   Event-sourced backends.

The [navio-blocks indexer](../explorer/architecture.md#indexer) uses RPC polling today; switching to ZMQ is a straightforward enhancement.

## Log management

Unless your init system captures stdout natively, `debug.log` and `staker.log` in the datadir grow unbounded. Rotate them with `logrotate` (or your supervisor's built-in log rotation).

Example `logrotate` drop-in:

```
/home/navio/.navio/testnet7/debug.log
/home/navio/.navio/testnet7/staker.log
/home/navio/.navio/debug.log
{
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

## Alerting signals

| Signal                                                | Severity  | Action                                                |
| ----------------------------------------------------- | --------- | ----------------------------------------------------- |
| Peer count < 3 for > 5 min                            | warning   | Check firewall, DNS seeds, external reachability       |
| `getblockchaininfo.blocks` not advancing for > 20 min | warning   | Peers stuck, restart, check `debug.log`                |
| `verificationprogress < 1.0` for > 1 h                | critical  | IBD stuck or flapping                                  |
| Staker produced no reward txs in 7 days at expected weight | warning   | Inspect staker stdout, RPC auth, wallet lock state    |
| Disk usage > 80 % on datadir partition                | warning   | Prune more aggressively or move datadir                |
| RPC 500 responses > 1 %                               | warning   | Overloaded — raise `rpcworkqueue`                       |
| `naviod` restart loop                                 | critical  | OOM, DB corruption, or config error                    |

## Grafana dashboards

Start from Bitcoin Core community dashboards; swap metric names for your Navio exporter labels.

## External uptime check

Run a cloud function (Cloudflare Worker, Lambda, simple cron on a different host) that hits a locked-down `/healthz` endpoint via an authenticated reverse proxy every minute. Alert on HTTP 5xx or timeout.
