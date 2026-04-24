# ElectrumX server

ElectrumX is a server implementation of the Electrum protocol. It sits next to `naviod` and provides efficient wallet-friendly queries (address history, balance, output lookup, transaction broadcast) without requiring each client to run a full node. Navio uses a fork that understands BLSCT semantics.

Why run your own:

-   **Privacy** — your IP and queries never leave your server.
-   **Self-sovereignty** — no third-party uptime dependency, no query rate limits, no censorship.
-   **Performance** — one wallet workload on one box; no noisy neighbours.
-   **Network health** — more Electrum servers = more resilient SPV infrastructure.

The [navio-sdk](../sdk/index.md) can use either Electrum or direct P2P. Most wallets default to Electrum for faster initial sync.

## Prerequisites

-   Linux (Ubuntu 22.04+ / Debian 12+ recommended)
-   Python ≥ 3.7
-   `naviod` installed, fully synced, RPC-accessible on localhost
-   Optional: domain name + TLS cert for SSL/WSS clients

## Install

```bash
git clone https://github.com/nav-io/electrumx.git
cd electrumx

sudo apt-get update
sudo apt-get install -y python3-pip python3-dev python3-venv build-essential libssl-dev

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

sudo useradd -m -s /bin/bash electrumx
sudo mkdir -p /home/electrumx/db
sudo chown -R electrumx:electrumx /home/electrumx/db
```

## TLS certificate (optional)

```bash
sudo apt-get install -y certbot
sudo certbot certonly --standalone -d electrum.example.com
```

Cert output: `/etc/letsencrypt/live/electrum.example.com/`.

## Configuration

`/etc/electrumx.conf`:

```ini
COIN=Navio
NET=testnet
DB_DIRECTORY=/home/electrumx/db
DAEMON_URL=user:password@127.0.0.1:48471
USERNAME=electrumx
ANON_LOGS=1
SSL_CERTFILE=/etc/letsencrypt/live/electrum.example.com/fullchain.pem
SSL_KEYFILE=/etc/letsencrypt/live/electrum.example.com/privkey.pem
SERVICES=tcp://0.0.0.0:40001,ssl://0.0.0.0:40002,wss://0.0.0.0:40004
MAX_SEND=10000000
COST_SOFT_LIMIT=0
COST_HARD_LIMIT=0
```

Replace `DAEMON_URL` with your real RPC credentials and port, and adjust `SERVICES` bindings.

## Running the daemon

Navio docs don't prescribe systemd. Use whatever supervisor fits your box.

### Foreground / tmux

```bash
# as the electrumx user, sourcing /etc/electrumx.conf into the env
set -a; . /etc/electrumx.conf; set +a
cd /home/electrumx/electrumx
./venv/bin/python3 ./electrumx_server
```

Supervise with tmux / screen:

```bash
tmux new -d -s electrumx 'bash -lc "set -a; . /etc/electrumx.conf; set +a; cd /home/electrumx/electrumx && ./venv/bin/python3 ./electrumx_server"'
tmux attach -t electrumx
```

### runit

`/etc/service/electrumx/run`:

```sh
#!/bin/sh
set -a; . /etc/electrumx.conf; set +a
cd /home/electrumx/electrumx
exec chpst -u electrumx ./venv/bin/python3 ./electrumx_server 2>&1
```

### OpenRC

`/etc/init.d/electrumx`:

```sh
#!/sbin/openrc-run
name="electrumx"
command="/home/electrumx/electrumx/venv/bin/python3"
command_args="/home/electrumx/electrumx/electrumx_server"
command_user="electrumx:electrumx"
command_background="yes"
pidfile="/run/electrumx.pid"
output_log="/var/log/electrumx.log"
error_log="/var/log/electrumx.log"
```

### Docker

Package the server into a container and let Docker's `restart: unless-stopped` policy supervise it.

## Firewall

```bash
sudo ufw allow 40001/tcp  # TCP
sudo ufw allow 40002/tcp  # SSL
sudo ufw allow 40004/tcp  # WSS
```

## Runtime checks

```bash
sudo -u electrumx /home/electrumx/electrumx/venv/bin/python3 \
    /home/electrumx/electrumx/electrumx_rpc getinfo
```

Follow logs via whatever your supervisor exposes (tmux attach, `sv status`, `docker logs -f`, file tail).

## Navio-specific protocol additions

The Navio fork extends the Electrum protocol with BLSCT-aware methods and removes legacy Navcoin DAO methods.

### `blockchain.block.get_txs_keys`

Returns all per-output transaction keys for a block.

-   Params: `[height: int]`
-   Returns: array of `[output_hash_hex, keys_object]` tuples.

Example:

```json
[
  ["a1b2c3...", {"blinding_key": "...", "ephemeral_key": "...", "view_tag": 17}],
  ["d4e5f6...", {"blinding_key": "...", "ephemeral_key": "...", "view_tag": 203}]
]
```

### `blockchain.block.get_range_txs_keys`

Paginated range variant, respects `MAX_SEND`:

```json
{
  "method": "blockchain.block.get_range_txs_keys",
  "params": [12345]
}
```

Response:

```json
{
  "blocks": [ /* per-block arrays as above */ ],
  "next_height": 12350
}
```

The [SDK Electrum sync provider](../sdk/sync.md#electrum-provider) uses this exclusively during initial sync — call latency dominates otherwise.

### `blockchain.transaction.get_output`

Fetch a serialised BLSCT output by `output_hash`:

```json
{
  "method": "blockchain.transaction.get_output",
  "params": ["a1b2c3d4..."]
}
```

Returns the raw serialised output (hex string).

### Removed methods

The Navcoin legacy DAO methods are removed in this fork:

-   `blockchain.dao.subscribe`
-   `blockchain.stakervote.subscribe`
-   `blockchain.consensus.subscribe`
-   `blockchain.listproposals`
-   `blockchain.listconsultations`
-   `blockchain.getcfunddbstatehash`

Clients that call them will receive an unknown-method error.

## Maintenance

```bash
cd /home/electrumx/electrumx
git pull
source venv/bin/activate
pip install -r requirements.txt
# restart via your supervisor (runit: sv restart electrumx; OpenRC: rc-service electrumx restart; Docker: docker compose restart electrumx; tmux: kill-session and recreate)
```

Database backup (stop service first for a consistent snapshot):

```bash
# stop via your supervisor, then:
sudo tar -czf electrumx_db_backup.tar.gz /home/electrumx/db
# start via your supervisor
```

## Troubleshooting

| Symptom                           | Likely cause                                                            |
| --------------------------------- | ----------------------------------------------------------------------- |
| `Connection refused` to naviod    | RPC not enabled or port mismatch in `DAEMON_URL`                        |
| SSL handshake errors              | Cert path/permissions, or cert belongs to another host                  |
| `Output not found`                | Client passed `txid:vout`; use `output_hash` (see [outpoint model](../concepts/outpoint.md)) |
| Permission denied on `db/`        | `/home/electrumx/db` ownership wrong                                    |
| High memory                       | `MAX_SEND` too large, or large client subscription set                  |
