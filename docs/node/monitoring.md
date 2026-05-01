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
-   `navio-cli listblscttransactions "*" 50 0 true | jq '[.[] | select(.category == "stake")] | length'` — count of recent stake rewards received by this wallet.
-   Block-height advancement at the expected rate (~120 s on mainnet, ~60 s on testnet).

## Metrics via Prometheus

No first-party exporter ships with navio-core. Community options:

-   Custom exporter script polling RPC every 30 s, exposing `/metrics`.
-   Generic blackbox exporter for RPC probing.

Starter Python script:

```python
from prometheus_client import start_http_server, Gauge
import requests, time

RPC = "http://user:pass@127.0.0.1:33677/"
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
```

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
