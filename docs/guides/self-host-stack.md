# Self-host full stack

`naviod` + ElectrumX + `navio-blocks` explorer, containerised.

## Goal

```
┌─────────────────────────────────────────────────┐
│                  nginx (TLS)                     │
└────────────┬──────────────────────┬─────────────┘
             │                      │
   explorer.example.com    electrum.example.com
             │                      │
   ┌─────────▼─────────┐  ┌─────────▼─────────┐
   │   navio-blocks    │  │    ElectrumX      │
   │   (api + web)     │  │    (TCP/SSL/WSS)  │
   └─────────┬─────────┘  └─────────┬─────────┘
             │   RPC         RPC    │
             └──────────┬───────────┘
                        │
                ┌───────▼───────┐
                │    naviod     │
                │   (txindex=1) │
                └───────────────┘
```

## Images

-   **naviod** — build from [`nav-io/navio-docker`](https://github.com/nav-io/navio-docker), which packages the official, checksum-verified navio-core release binaries on `debian:bookworm-slim` (non-root `navio` user, `tini` as PID 1, datadir `/home/navio/.navio`). Pin a release with the `NAVIO_RELEASE_TAG` build argument. Three Dockerfile targets:

    | Target           | Adds                                   | Node flags set by the entrypoint | Disable at run time |
    | ---------------- | -------------------------------------- | -------------------------------- | ------------------- |
    | `node` (default) | —                                      | —                                | —                   |
    | `tor`            | Tor client; publishes an onion service | `-onion=127.0.0.1:9050`          | `NAVIO_TOR=0`       |
    | `i2p`            | i2pd router (SAM on loopback only)     | `-i2psam=127.0.0.1:7656`         | `NAVIO_I2P=0`       |

    Keep the router state on a volume (`/home/navio/.tor` or `/home/navio/.i2pd`). Tor needs no published port; for I2P, publishing router port `48480` TCP+UDP is optional but speeds up tunnel building. The `i2p` target builds for `linux/amd64`, `linux/arm64` and `linux/arm/v7` only.
-   **electrumx** and **navio-blocks** — build from [`nav-io/electrumx`](https://github.com/nav-io/electrumx) and [`nav-io/navio-blocks`](https://github.com/nav-io/navio-blocks); the `image:` names below are local tags.

## `docker-compose.yml`

```yaml
services:
  naviod:
    build:
      context: https://github.com/nav-io/navio-docker.git
      target: node            # or tor / i2p
    image: navio/naviod:local
    container_name: naviod
    restart: unless-stopped
    volumes:
      - ./data/naviod:/home/navio/.navio
    networks: [navionet]
    environment:
      RPC_USER: ${RPC_USER}
      RPC_PASSWORD: ${RPC_PASSWORD}
    command:
      - naviod
      - -printtoconsole
      - -testnet
      - -txindex=1
      - -server=1
      - -rpcbind=0.0.0.0:33677
      - -rpcallowip=172.16.0.0/12
      - -rpcuser=${RPC_USER}
      - -rpcpassword=${RPC_PASSWORD}
      - -dbcache=2000

  electrumx:
    image: navio/electrumx:local
    container_name: electrumx
    restart: unless-stopped
    depends_on: [naviod]
    volumes:
      - ./data/electrumx:/data/db
    networks: [navionet]
    environment:
      COIN: Navio
      NET: testnet
      DB_DIRECTORY: /data/db
      DAEMON_URL: ${RPC_USER}:${RPC_PASSWORD}@naviod:33677
      SERVICES: tcp://0.0.0.0:40001,ssl://0.0.0.0:40002,wss://0.0.0.0:40004
      SSL_CERTFILE: /etc/letsencrypt/live/electrum.example.com/fullchain.pem
      SSL_KEYFILE:  /etc/letsencrypt/live/electrum.example.com/privkey.pem
      MAX_SEND: 10000000
      ANON_LOGS: 1
    volumes:
      - ./data/electrumx:/data/db
      - /etc/letsencrypt:/etc/letsencrypt:ro

  explorer:
    image: navio/blocks:local
    container_name: navio-blocks
    restart: unless-stopped
    depends_on: [naviod]
    networks: [navionet]
    environment:
      RPC_HOST: naviod
      RPC_PORT: 33677
      RPC_USER: ${RPC_USER}
      RPC_PASSWORD: ${RPC_PASSWORD}
      NETWORK: testnet
      API_PORT: 3001
      API_HOST: 0.0.0.0
      DB_PATH: /data/navio-blocks.db
    volumes:
      - ./data/blocks:/data

  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "40002:40002"    # electrum SSL
      - "40004:40004"    # electrum WSS
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on: [explorer, electrumx]
    networks: [navionet]

networks:
  navionet:
    driver: bridge
```

## `.env`

```dotenv
RPC_USER=navio
RPC_PASSWORD=PUT_A_LONG_RANDOM_STRING_HERE
```

## `nginx.conf`

```nginx
events { }
http {
    server {
        listen 443 ssl http2;
        server_name explorer.example.com;
        ssl_certificate     /etc/letsencrypt/live/explorer.example.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/explorer.example.com/privkey.pem;
        location / {
            proxy_pass http://explorer:3001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
    # Electrum TCP/SSL/WSS are on their own ports via the ports: mapping above.
}
```

## First boot

```bash
# get TLS certs first
docker run --rm -v /etc/letsencrypt:/etc/letsencrypt -p 80:80 certbot/certbot \
    certonly --standalone -d explorer.example.com -d electrum.example.com

docker compose up -d

# watch sync progress
docker logs -f naviod
docker logs -f explorer
```

Initial naviod sync: testnet a few GB, mainnet (after transition) much more. ElectrumX indexing runs after naviod is synced; expect a second long wait before Electrum clients can query.

## Health checks

```bash
# naviod
docker exec naviod navio-cli -testnet getblockchaininfo | jq '.blocks, .headers, .verificationprogress'

# explorer API
curl https://explorer.example.com/api/health | jq

# electrum
openssl s_client -connect electrum.example.com:40002 -servername electrum.example.com </dev/null | head -5
```

## Upgrade procedure

```bash
# rebuild naviod from the newest navio-core release (or set NAVIO_RELEASE_TAG)
docker compose build --pull --no-cache naviod
docker compose up -d

# verify heights match across services
docker exec naviod navio-cli -testnet getblockcount
curl -s https://explorer.example.com/api/stats | jq '.height'
```

## Backup

-   Back up `./data/naviod/wallets/*` and the wallet mnemonic (off-host).
-   Explorer DB (`./data/blocks/navio-blocks.db`) is derived — no backup needed; reindex on disaster.
-   Electrum DB (`./data/electrumx/*`) is derived — reindex on disaster.
