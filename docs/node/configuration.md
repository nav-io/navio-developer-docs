# `navio.conf` reference

All options can be set in `navio.conf` or passed on the command line as `-key=value`. Network-specific overrides live under `[main]`, `[test]`, `[signet]`, `[regtest]` or `[blsctregtest]` section headers.

Default config locations:

| OS      | Path                                                      |
| ------- | --------------------------------------------------------- |
| Linux   | `~/.navio/navio.conf`                                     |
| macOS   | `~/Library/Application Support/Navio/navio.conf`          |
| Windows | `%APPDATA%\Navio\navio.conf`                              |

## Minimal example

```ini
server=1
listen=1
txindex=1
rpcuser=navio
rpcpassword=CHANGE_ME_TO_A_LONG_RANDOM_STRING
```

Mainnet peers are found through the built-in DNS seed (`seed.nav.io`) and fixed seed; no `addnode` is needed. Testnet has no built-in seeds — see the [network-specific example](#network-specific-section-example).

## Option reference

This page lists the options operators most often need. `naviod -help` (and `-help-debug` for debug options) on your release is authoritative; see [`src/init.cpp`](https://github.com/nav-io/navio-core/blob/master/src/init.cpp) and [`src/wallet/init.cpp`](https://github.com/nav-io/navio-core/blob/master/src/wallet/init.cpp).

### Chain selection

| Option           | Description                                                       |
| ---------------- | ----------------------------------------------------------------- |
| `chain=`         | `main`, `test`, `signet`, `regtest`, or `blsctregtest`            |
| `testnet=1`      | Equivalent to `chain=test`                                        |
| `signet=1`       | Equivalent to `chain=signet` (non-BLSCT; no built-in seeds)       |
| `regtest=1`      | Equivalent to `chain=regtest` (non-BLSCT private test chain)      |
| `blsctregtest=1` | Equivalent to `chain=blsctregtest` (BLSCT / PoPS private test chain) |

### Server / RPC

| Option                 | Default           | Description                                                                 |
| ---------------------- | ----------------- | --------------------------------------------------------------------------- |
| `server=`              | `0`               | Accept RPC commands                                                         |
| `rpcuser=`             |                   | RPC username                                                                |
| `rpcpassword=`         |                   | RPC password                                                                |
| `rpcauth=`             |                   | Alternative: `<user>:<salt>$<hash>` generated with `share/rpcauth/rpcauth.py` |
| `rpcbind=`             | `127.0.0.1`       | Bind RPC to this address/port                                               |
| `rpcport=`             | `48471` (main) / `33677` (test) / `48487` (signet) / `48486` (regtest) / `48484` (blsctregtest) | RPC port |
| `rpcallowip=`          | `127.0.0.1`       | CIDR allowed to access RPC                                                  |
| `rpcworkqueue=`        | `16`              | Max depth of RPC work queue                                                 |
| `rpcthreads=`          | `4`               | RPC worker threads                                                          |
| `rpcservertimeout=`    | `30`              | Per-request timeout, seconds                                                |
| `rpccookiefile=`       | datadir `/.cookie` | Path of generated cookie auth file                                         |

### Network / P2P

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `listen=`              | `1`                     | Accept inbound connections                                             |
| `port=`                | `48470` (main) / `33670` (test) / `38333` (signet) / `18444` (regtest, blsctregtest) | P2P port |
| `bind=`                |                         | Bind P2P to specific address                                           |
| `externalip=`          |                         | Advertise this IP to peers                                             |
| `maxconnections=`      | `125`                   | Max concurrent connections                                             |
| `addnode=`             |                         | Connect and maintain open connection to this node                      |
| `connect=`             |                         | Connect *only* to these nodes (disables DNS seeding)                   |
| `seednode=`            |                         | One-shot peer seed                                                     |
| `dnsseed=`             | `1`                     | Use DNS seeds for peer discovery                                       |
| `bantime=`             | `86400`                 | Ban duration for misbehaving peers, seconds                            |
| `whitelist=`           |                         | Grant permissions to peers from these CIDRs. Does **not** apply to WebSocket peers |
| `v2transport=`         | `0`                     | Support BIP324 v2 encrypted transport and advertise `NODE_P2P_V2`      |
| `dandelion=`           | `1`                     | Use Dandelion++ stem/fluff propagation for transactions                |
| `p2pwsbind=`           |                         | `<addr>[:<port>]`, repeatable. Also accept P2P over WebSocket (plain `ws://`) for browser clients; implies `listen=1`. See [WebSocket listener](../concepts/p2p-protocol.md#websocket-listener) |
| `p2pwsexternal=`       |                         | Public `ws://`/`wss://` URL of the WebSocket listener behind a reverse proxy; requires `p2pwsbind` |
| `peeroutkeys=`         | `0`                     | Serve per-block output keys to light wallets (`getoutkeys`, `NODE_OUTKEYS`). Incompatible with `prune` |
| `onion=`               |                         | SOCKS5 proxy for `.onion` connections                                  |
| `proxy=`               |                         | SOCKS5 proxy for all outgoing connections                              |
| `i2psam=`              |                         | I2P SAM proxy address                                                  |
| `cjdnsreachable=`      | `0`                     | Announce CJDNS reachability                                            |

`-checkpoints` was removed together with the Bitcoin-era checkpoint data; setting it only logs a warning. Remove it from old configs.

### P2P encrypted messaging

| Option                     | Default | Description |
| -------------------------- | ------- | ----------- |
| `p2pmsg=`                  | `1`     | Enable the [encrypted messaging overlay](../concepts/p2p-messaging.md) and advertise `NODE_P2PMSG_V2` |
| `p2pmsgstoresize=`         | `64`    | User-message store size in MiB (inbox 40 % / session 40 % / broadcast 20 %); `0` disables it |
| `p2pmsgstoreexpiry=`       | `30`    | Days a stored user message is kept; `0` = no age limit |
| `p2pmsgtopic=`             |         | Subscribe to a broadcast topic at startup (repeatable) |
| `p2pmsgnotify=`            |         | Command run per stored message; `%s` = message id |
| `p2pmsgarchive=`           | `0`     | Retain flagged envelopes and serve them to offline peers; advertises `NODE_P2PMSG_ARCHIVE` |
| `p2pmsgarchivesize=`       | `4096`  | Archive size cap, MiB |
| `p2pmsgarchiveexpiry=`     | `14`    | Archive retention, days |

Debug-only: `p2pmsgpowbits`, `p2pmsgarchivepowbits`, `p2pmsginboxrotation`, `p2pmsgpersistidentity`, `onionworkers`, `candidatepullinterval`, `servecandidateinterval`.

### Storage and indexes

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `datadir=`             | OS-specific             | Base data directory                                                    |
| `blocksdir=`           | `datadir/blocks/`       | Override blocks storage                                                |
| `prune=`               | `0`                     | Target storage size in MiB; `0` = no pruning                           |
| `txindex=`             | `0`                     | Maintain a full txid → tx index (needed by most explorers)             |
| `outindex=`            | `0`                     | Maintain an output hash → creating/spending position index (`getoutputinfo`, faster `gettxfromoutputhash`). Incompatible with `prune` |
| `blockfilterindex=`    | `0`                     | Maintain BIP-157/158 filter index                                      |
| `coinstatsindex=`      | `0`                     | Maintain UTXO set stats index                                          |
| `par=`                 | `0` (auto)              | Verification threads; also sizes Navio's parallel BLSCT worker pools   |
| `dbcache=`             | `2048`                  | Max database cache size in MiB                                         |
| `maxorphantx=`         | `100`                   | Max orphan transactions in memory                                      |
| `maxmempool=`          | `300`                   | Max mempool size in MiB                                                |
| `mempoolexpiry=`       | `336`                   | Mempool entry expiry, hours                                            |

### Wallet

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `disablewallet=`       | `0`                     | Disable wallet subsystem entirely                                      |
| `wallet=`              |                         | Wallet filename to load (can repeat)                                   |
| `walletdir=`           | `datadir/wallets/`      | Wallet storage directory                                               |
| `keypool=`             | `1000`                  | Keypool size                                                           |
| `walletbroadcast=`     | `1`                     | Relay wallet transactions                                              |
| `aggregatesends=`      | `1`                     | Merge fee-0 cover candidates from the p2pmsg pool into wallet BLSCT sends; falls back to a plain send when none are available |
| `servecandidates=`     | `1`                     | Answer cover-candidate pull requests with fee-0 self-spends of loaded BLSCT wallets' coins (rate-limited) |
| `blsctpadoutputs=`     | `1`                     | Always give an ordinary BLSCT send a change output (zero-value when needed) so all sends share one output count |
| `consolidatestakedcommitments=` | `1`            | Fold existing staked commitments into a new `stakelock` so the wallet holds one stake |

### BLSCT verification

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `blsctfixedbase=`      | `1`                     | Precomputed fixed-base tables for range-proof verification; `0` uses the generic multi-scalar multiplication (slower, less memory) |

### Logging

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `debug=`               |                         | Log category: `net`, `rpc`, `blsct`, `mempool`, `dandelion`, `1`, `none` |
| `debugexclude=`        |                         | Exclude a category from `debug=1`                                      |
| `logtimestamps=`       | `1`                     | Prefix log lines with timestamp                                        |
| `logtimemicros=`       | `0`                     | Microsecond precision timestamps                                       |
| `logratelimit=`        | `1`                     | Rate-limit repetitive unconditional log lines                          |
| `printtoconsole=`      | `0`                     | Log to stdout (useful for Docker / runit / any supervisor that captures stdout) |
| `shrinkdebugfile=`     | `1`                     | Truncate `debug.log` on start                                          |

Staking is not configured in `naviod`; it runs in the separate [`navio-staker`](staking.md) process.

### ZMQ publishers

Enable to stream chain events to external consumers:

| Option                        | Description                                     |
| ----------------------------- | ----------------------------------------------- |
| `zmqpubrawblock=tcp://…`      | Publish full raw blocks                         |
| `zmqpubhashblock=tcp://…`     | Publish block hashes                            |
| `zmqpubrawtx=tcp://…`         | Publish full raw transactions                   |
| `zmqpubhashtx=tcp://…`        | Publish transaction hashes                      |
| `zmqpubsequence=tcp://…`      | Publish mempool add/remove sequence             |
| `zmqpubp2pmsg=tcp://…`        | Publish stored p2pmsg user messages (topic `p2pmsg`) |

### REST

| Option         | Default | Description                    |
| -------------- | ------- | ------------------------------ |
| `rest=`        | `0`     | Enable Bitcoin-style REST API  |

## Network-specific section example

```ini
# shared across all networks
server=1
txindex=1

[main]
rpcuser=main_user
rpcpassword=long_random_a

[test]
rpcuser=test_user
rpcpassword=long_random_b
# testnet has no built-in seeds
addnode=testnet.nav.io
addnode=testnet2.nav.io

[regtest]
rpcuser=regtest_user
rpcpassword=long_random_c
```

When you start `naviod -testnet` it reads the top section plus the `[test]` section.
