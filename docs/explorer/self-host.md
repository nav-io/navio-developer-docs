# Self-host guide

## Prerequisites

-   Node.js ≥ 18
-   npm ≥ 9
-   `naviod` running with `txindex=1` and RPC enabled

## Install

```bash
git clone https://github.com/nav-io/navio-blocks.git
cd navio-blocks
npm install
cp .env.example .env
# edit .env with your RPC creds
```

Start `naviod` with RPC access:

```bash
naviod -server -txindex -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS
```

Or in `navio.conf`:

```ini
server=1
txindex=1
rpcuser=user
rpcpassword=pass
rpcport=33677
```

## Environment variables

| Variable                             | Default                      | Description                                                                 |
| ------------------------------------ | ---------------------------- | --------------------------------------------------------------------------- |
| `RPC_HOST`                           | `127.0.0.1`                  | naviod RPC host                                                             |
| `RPC_PORT`                           | `33677`                      | naviod RPC port                                                             |
| `RPC_USER`                           |                              | naviod RPC username                                                         |
| `RPC_PASSWORD`                       |                              | naviod RPC password                                                         |
| `NETWORK`                            | `mainnet`                    | `mainnet` or `testnet` — affects reward rules                                |
| `TESTNET_BOOTSTRAP_NODES`            | `testnet.nav.io,testnet2.nav.io` | Comma-separated seeds for testnet direct P2P crawl                    |
| `MAINNET_BOOTSTRAP_NODES`            |                              | Comma-separated seeds for mainnet direct P2P crawl                          |
| `P2P_PORT`                           |                              | Optional port override for all direct P2P crawls                            |
| `TESTNET_P2P_PORT`                   | `33670`                      | Default testnet P2P port if seed entry omits one                            |
| `MAINNET_P2P_PORT`                   | `48470`                      | Default mainnet P2P port if seed entry omits one                            |
| `P2P_MESSAGE_MAGIC_HEX`              |                              | Message-start override (8 hex chars); supersedes network-specific magic     |
| `P2P_TESTNET_MAGIC_HEX`              | `1c03bb83`                   | Testnet message-start bytes                                                 |
| `P2P_MAINNET_MAGIC_HEX`              | `bd5fc300`                   | Mainnet message-start bytes                                                 |
| `P2P_PROTOCOL_VERSION`               | `70016`                      | Protocol version announced in direct P2P `version` handshake                |
| `P2P_REQUEST_TIMEOUT_MS`             | `4500`                       | Timeout per direct P2P handshake/`getaddr` request                          |
| `P2P_CRAWL_CONCURRENCY`              | `24`                         | Concurrent direct P2P peer crawls per discovery round                       |
| `PEER_DISCOVERY_ROUNDS`              | `3`                          | Seeder-style direct P2P crawl rounds (`version`/`verack` + `getaddr`)       |
| `PEER_DISCOVERY_BATCH_SIZE`          | `64`                         | Nodes to crawl per round                                                    |
| `PEER_DISCOVERY_WAIT_MS`             | `1200`                       | Wait between crawl rounds                                                   |
| `PEER_DISCOVERY_MAX_CANDIDATES`      | `2000`                       | Upper bound on tracked addresses per cycle                                  |
| `PEER_CONNECT_TIMEOUT_MS`            | `2000`                       | TCP timeout for connectivity probes                                         |
| `PEER_CONNECT_CONCURRENCY`           | `48`                         | Parallel TCP probes                                                         |
| `PEER_CONNECT_TEST_LIMIT`            | `300`                        | Number of discovered peers to probe per cycle                               |
| `PEER_DISCOVERY_FILTER_UNREACHABLE`  | `true`                       | Drop probe-failing peers on testnet                                         |
| `PEER_GEO_LOOKUP_LIMIT`              | `80`                         | Max uncached geo lookups per cycle (ip-api rate limits)                     |
| `API_PORT`                           | `3001`                       | API server port                                                             |
| `API_HOST`                           | `0.0.0.0`                    | API bind address                                                            |
| `DB_PATH`                            | `./navio-blocks.db`          | SQLite path                                                                 |
| `VITE_API_URL`                       | `http://localhost:3001`      | Frontend API URL (dev only)                                                 |
| `LOG_LEVEL`                          | `info`                       | Fastify log level                                                           |

## Development

Build shared types first (once, or after type changes):

```bash
npm run build:shared
```

Run all three services with colour-coded output:

```bash
npm run dev
```

Starts:

-   **[IDX]** Indexer — `tsx watch`
-   **[API]** API server — port 3001
-   **[WEB]** Frontend — port 5173 (proxies `/api` to 3001)

Or individually:

```bash
npm run dev:indexer
npm run dev:api
npm run dev:frontend
```

## Production

```bash
npm run build
npm start
```

`npm start` runs indexer + API. The API serves the compiled frontend at `/` and endpoints at `/api/*`. Swagger UI at `/docs`.

Process management with `pm2`:

```bash
npm install -g pm2
pm2 start "npm run start:indexer" --name navio-indexer
pm2 start "npm run start:api"     --name navio-api
pm2 save
```

## Reverse proxy

Front the API with nginx + TLS:

```nginx
server {
    listen 443 ssl http2;
    server_name explorer.example.com;

    ssl_certificate     /etc/letsencrypt/live/explorer.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/explorer.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Listen locally on `0.0.0.0` or `127.0.0.1` as appropriate; never expose RPC credentials outside the host.

## Reindexing

See the [reindex guide](reindex.md).

## Docker

`docker-compose.yml` example:

```yaml
services:
  naviod:
    image: navio/naviod:latest
    volumes: [./naviod-data:/home/navio/.navio]
    ports: ["33670:33670"]
    environment:
      RPC_USER: user
      RPC_PASSWORD: pass
    command: [naviod, -printtoconsole, -testnet, -txindex=1, -server=1,
              -rpcbind=0.0.0.0:33677, -rpcallowip=172.16.0.0/12, -rpcuser=user, -rpcpassword=pass]

  navio-blocks:
    build: .
    depends_on: [naviod]
    environment:
      RPC_HOST: naviod
      RPC_USER: user
      RPC_PASSWORD: pass
      NETWORK: testnet
      API_PORT: 3001
    ports: ["3001:3001"]
    volumes: [./blocks-data:/app/data]
```
