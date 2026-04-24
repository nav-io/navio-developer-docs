# Install `naviod`

Three paths:

1.  **Build from source** — Linux, macOS, Windows (MSYS), BSD.
2.  **Docker** — self-contained container.
3.  **Release binaries** — when available, the fastest path.

!!! warning "Service manager"
    Navio docs is deliberately service-manager-agnostic. Examples below run `naviod` in the foreground (container-friendly) or via `tmux`/`screen`. Plug your own supervisor (runit, OpenRC, s6, supervisord, launchd, Docker restart policies, …) around these — the binary itself only needs to stay running, capture stdout, and restart on exit.

## 1. Build from source

### Dependencies

Standard Bitcoin Core toolchain plus BLSCT deps (bundled in-tree via `depends/`).

**Debian / Ubuntu:**

```bash
sudo apt-get install -y \
    build-essential libtool autotools-dev automake pkg-config \
    libssl-dev libevent-dev bsdmainutils \
    libboost-system-dev libboost-filesystem-dev libboost-chrono-dev \
    libboost-test-dev libboost-thread-dev \
    libminiupnpc-dev libzmq3-dev libsqlite3-dev git
```

**macOS (Homebrew):**

```bash
brew install automake libtool boost pkg-config libevent miniupnpc zeromq sqlite
```

### Build

```bash
git clone https://github.com/nav-io/navio-core.git
cd navio-core
./autogen.sh
./configure --enable-wallet --with-gui=no
make -j"$(nproc)"
sudo make install    # optional; installs to /usr/local/bin
```

Binaries land in `src/` if you skip `make install`:

-   `src/naviod`
-   `src/navio-cli`
-   `src/navio-staker`
-   `src/navio-wallet`
-   `src/navio-tx`

### Build options

| Flag                           | Effect                                                    |
| ------------------------------ | --------------------------------------------------------- |
| `--enable-wallet`              | Enable wallet (default on)                                |
| `--disable-wallet`             | Node-only (smaller binary, no wallet/RPC wallet cmds)     |
| `--with-gui=no`                | Skip Qt GUI (default, recommended for servers)            |
| `--enable-debug`               | Debug symbols, assertion checks                           |
| `--enable-tests`               | Build unit tests                                          |
| `--enable-fuzz`                | Build fuzz harnesses                                      |
| `--enable-reduce-exports`      | Smaller binary via symbol hiding                          |
| `--enable-zmq`                 | ZMQ pub/sub interface                                     |

Full list: `./configure --help`.

### Cross-compilation

Navio inherits Bitcoin Core's `depends/` system. Reproducible Linux build on another Linux box:

```bash
cd depends
make HOST=x86_64-pc-linux-gnu -j"$(nproc)"
cd ..
./autogen.sh
CONFIG_SITE="$PWD/depends/x86_64-pc-linux-gnu/share/config.site" ./configure --prefix=/
make -j"$(nproc)"
```

Supported `HOST` triplets: `x86_64-pc-linux-gnu`, `aarch64-linux-gnu`, `x86_64-w64-mingw32` (Windows), `x86_64-apple-darwin` (macOS, needs Apple SDK). Navio supports [Guix](https://guix.gnu.org/) reproducible builds — see `contrib/guix/`.

## 2. Quick-start on a fresh box (no init system assumed)

```bash
# install build deps (see above)
git clone https://github.com/nav-io/navio-core.git ~/navio-core
cd ~/navio-core
./autogen.sh && ./configure --enable-wallet --with-gui=no && make -j"$(nproc)"
sudo make install

# config
mkdir -p ~/.navio
cat > ~/.navio/navio.conf <<EOF
server=1
listen=1
testnet=1
rpcuser=$(whoami)
rpcpassword=$(openssl rand -base64 32)

[test]
addnode=testnet.nav.io
addnode=testnet2.nav.io
EOF

# create wallet
navio-wallet -blsct -chain=test -wallet=wallet create

# run in the foreground
naviod -testnet -printtoconsole
```

For production, wrap the final `naviod` invocation in whatever supervisor you prefer. Equivalent pattern for the staker:

```bash
navio-staker -testnet -wallet=wallet
```

Run it in a separate process, supervised the same way.

### tmux example

```bash
tmux new -d -s naviod 'naviod -testnet -printtoconsole'
tmux new -d -s staker 'navio-staker -testnet -wallet=wallet'
tmux attach -t naviod   # follow logs
```

### runit example (`/etc/service/naviod/run`)

```sh
#!/bin/sh
exec chpst -u navio naviod -testnet -printtoconsole -conf=/home/navio/.navio/navio.conf 2>&1
```

### OpenRC example (`/etc/init.d/naviod`)

```sh
#!/sbin/openrc-run
name="naviod"
command="/usr/local/bin/naviod"
command_args="-testnet -printtoconsole -conf=/home/navio/.navio/navio.conf"
command_user="navio"
command_background="yes"
pidfile="/run/naviod.pid"
```

Logs go where your supervisor redirects them.

## 3. Docker

Example `Dockerfile`:

```dockerfile
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libtool autotools-dev automake pkg-config \
    libssl-dev libevent-dev bsdmainutils \
    libboost-all-dev \
    libminiupnpc-dev libzmq3-dev libsqlite3-dev \
    git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/nav-io/navio-core.git /src
WORKDIR /src
RUN ./autogen.sh && ./configure --enable-wallet --with-gui=no && make -j"$(nproc)"
RUN strip src/naviod src/navio-cli src/navio-staker src/navio-wallet

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libboost-system1.81 libboost-filesystem1.81 libboost-thread1.81 \
    libevent-2.1-7 libevent-pthreads-2.1-7 \
    libminiupnpc17 libzmq5 libsqlite3-0 \
    tini ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/src/naviod        /usr/local/bin/
COPY --from=builder /src/src/navio-cli     /usr/local/bin/
COPY --from=builder /src/src/navio-staker  /usr/local/bin/
COPY --from=builder /src/src/navio-wallet  /usr/local/bin/

RUN useradd -r -m -s /bin/bash navio
USER navio
WORKDIR /home/navio
VOLUME ["/home/navio/.navio"]

EXPOSE 33670 33677
ENTRYPOINT ["tini","--","naviod","-printtoconsole"]
```

`docker-compose.yml`:

```yaml
services:
  naviod:
    build: .
    image: navio/naviod:latest
    container_name: naviod
    restart: unless-stopped
    volumes:
      - ./data:/home/navio/.navio
    ports:
      - "33670:33670"           # p2p
      - "127.0.0.1:33677:33677" # rpc, loopback only
    command:
      - naviod
      - -printtoconsole
      - -testnet
      - -server=1
      - -rpcallowip=127.0.0.1
      - -rpcbind=0.0.0.0:33677
      - -rpcuser=${RPC_USER}
      - -rpcpassword=${RPC_PASSWORD}
```

Docker's own `restart` policy handles supervision — no separate init needed.

## 4. Release binaries

[nav-io/navio-core releases](https://github.com/nav-io/navio-core/releases). Verify signatures / SHA256SUMS before use.

```bash
curl -LO https://github.com/nav-io/navio-core/releases/download/<tag>/navio-<tag>-x86_64-linux-gnu.tar.gz
curl -LO https://github.com/nav-io/navio-core/releases/download/<tag>/SHA256SUMS
curl -LO https://github.com/nav-io/navio-core/releases/download/<tag>/SHA256SUMS.asc
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS
tar xzf navio-<tag>-x86_64-linux-gnu.tar.gz
sudo install -m 755 navio-<tag>/bin/naviod /usr/local/bin/
sudo install -m 755 navio-<tag>/bin/navio-cli /usr/local/bin/
sudo install -m 755 navio-<tag>/bin/navio-staker /usr/local/bin/
```

## Post-install checks

```bash
navio-cli -testnet getblockchaininfo
navio-cli -testnet getnewaddress
navio-cli -testnet getblsctbalance
```

## Testnet faucet

Join [Discord](https://discord.com/invite/eBQ2QUkVXy), post `/faucet` in `#testnet`.

## Next steps

-   [Configure naviod](configuration.md)
-   [Enable staking](staking.md)
-   [Harden the node](security.md)
