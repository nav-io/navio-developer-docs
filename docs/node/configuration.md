# `navio.conf` reference

All options can be set in `navio.conf` or passed on the command line as `-key=value`. Network-specific overrides live under `[main]`, `[test]`, `[signet]`, or `[regtest]` section headers.

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

[main]
addnode=seed1.nav.io
addnode=seed2.nav.io
```

## Full option reference

### Chain selection

| Option       | Description                                                       |
| ------------ | ----------------------------------------------------------------- |
| `chain=`     | `main`, `test`, `signet`, or `regtest`                            |
| `testnet=1`  | Equivalent to `chain=test`                                        |
| `signet=1`   | Equivalent to `chain=signet`                                      |
| `regtest=1`  | Equivalent to `chain=regtest` (private test chain, no seeds)      |

### Server / RPC

| Option                 | Default           | Description                                                                 |
| ---------------------- | ----------------- | --------------------------------------------------------------------------- |
| `server=`              | `0`               | Accept RPC commands                                                         |
| `rpcuser=`             |                   | RPC username                                                                |
| `rpcpassword=`         |                   | RPC password                                                                |
| `rpcauth=`             |                   | Alternative: `<user>:<salt>$<hash>` generated with `share/rpcauth/rpcauth.py` |
| `rpcbind=`             | `127.0.0.1`       | Bind RPC to this address/port                                               |
| `rpcport=`             | `48471` (main) / `33677` (test) | RPC port                                                      |
| `rpcallowip=`          | `127.0.0.1`       | CIDR allowed to access RPC                                                  |
| `rpcworkqueue=`        | `16`              | Max depth of RPC work queue                                                 |
| `rpcthreads=`          | `4`               | RPC worker threads                                                          |
| `rpcservertimeout=`    | `30`              | Per-request timeout, seconds                                                |
| `rpccookiefile=`       | datadir `/.cookie` | Path of generated cookie auth file                                         |

### Network / P2P

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `listen=`              | `1`                     | Accept inbound connections                                             |
| `port=`                | `33670` (main)          | P2P port                                                               |
| `bind=`                |                         | Bind P2P to specific address                                           |
| `externalip=`          |                         | Advertise this IP to peers                                             |
| `maxconnections=`      | `125`                   | Max concurrent connections                                             |
| `addnode=`             |                         | Connect and maintain open connection to this node                      |
| `connect=`             |                         | Connect *only* to these nodes (disables DNS seeding)                   |
| `seednode=`            |                         | One-shot peer seed                                                     |
| `dnsseed=`             | `1`                     | Use DNS seeds for peer discovery                                       |
| `banscore=`            | `100`                   | Misbehaviour threshold for banning                                     |
| `bantime=`             | `86400`                 | Ban duration, seconds                                                  |
| `whitelist=`           |                         | Relax relay rules for these CIDRs                                      |
| `onion=`               |                         | SOCKS5 proxy for `.onion` connections                                  |
| `proxy=`               |                         | SOCKS5 proxy for all outgoing connections                              |
| `i2psam=`              |                         | I2P SAM proxy address                                                  |
| `cjdnsreachable=`      | `0`                     | Announce CJDNS reachability                                            |

### Storage

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `datadir=`             | OS-specific             | Base data directory                                                    |
| `blocksdir=`           | `datadir/blocks/`       | Override blocks storage                                                |
| `prune=`               | `0`                     | Target storage size in MiB; `0` = no pruning                           |
| `txindex=`             | `0`                     | Maintain a full txid → tx index (needed by most explorers)             |
| `blockfilterindex=`    | `0`                     | Maintain BIP-157/158 filter index                                      |
| `coinstatsindex=`      | `0`                     | Maintain UTXO set stats index                                          |
| `par=`                 | `0` (auto)              | Script verification threads                                            |
| `dbcache=`             | `450`                   | Max dbcache size in MiB                                                |
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
| `fallbackfee=`         |                         | Fee rate used when fee estimation has no data                          |
| `mintxfee=`            |                         | Minimum tx fee per kB                                                  |
| `discardfee=`          |                         | Discard leftover output below this as fee                              |
| `walletbroadcast=`     | `1`                     | Relay wallet transactions                                              |

### BLSCT

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `blsct=`               |                         | Enable BLSCT wallet flag on creation                                   |
| `blsctscan=`           | `1`                     | Scan blocks for BLSCT outputs on sync                                  |
| `blsctviewtagonly=`    | `0`                     | Skip full ECDH scan when view tag does not match                       |

### Staking

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `staking=`             |                         | Enable in-daemon staking (prefer `navio-staker` instead)               |
| `minstakeamount=`      |                         | Minimum stake amount threshold                                         |
| `stakesplitthreshold=` |                         | Split stake UTXOs above this to increase stake chances                 |

### Logging

| Option                 | Default                 | Description                                                            |
| ---------------------- | ----------------------- | ---------------------------------------------------------------------- |
| `debug=`               |                         | Log category: `net`, `rpc`, `blsct`, `mempool`, `1`, `none`            |
| `debugexclude=`        |                         | Exclude a category from `debug=1`                                      |
| `logtimestamps=`       | `1`                     | Prefix log lines with timestamp                                        |
| `logtimemicros=`       | `0`                     | Microsecond precision timestamps                                       |
| `printtoconsole=`      | `0`                     | Log to stdout (useful for Docker / runit / any supervisor that captures stdout) |
| `shrinkdebugfile=`     | `1`                     | Truncate `debug.log` on start                                          |

### ZMQ publishers

Enable to stream chain events to external consumers:

| Option                        | Description                                     |
| ----------------------------- | ----------------------------------------------- |
| `zmqpubrawblock=tcp://…`      | Publish full raw blocks                         |
| `zmqpubhashblock=tcp://…`     | Publish block hashes                            |
| `zmqpubrawtx=tcp://…`         | Publish full raw transactions                   |
| `zmqpubhashtx=tcp://…`        | Publish transaction hashes                      |
| `zmqpubsequence=tcp://…`      | Publish mempool add/remove sequence             |

### REST

| Option         | Default | Description                    |
| -------------- | ------- | ------------------------------ |
| `rest=`        | `0`     | Enable Bitcoin-style REST API  |

See [`src/init.cpp`](https://github.com/nav-io/navio-core/blob/master/src/init.cpp) in navio-core for the canonical list — the automated documentation pipeline regenerates this page from `naviod -help` output on each release.

## Network-specific section example

```ini
# shared across all networks
server=1
txindex=1

[main]
rpcuser=main_user
rpcpassword=long_random_a
addnode=seed1.nav.io

[test]
rpcuser=test_user
rpcpassword=long_random_b
addnode=testnet.nav.io
addnode=testnet2.nav.io

[regtest]
rpcuser=regtest_user
rpcpassword=long_random_c
```

When you start `naviod -testnet` it reads the top section plus the `[test]` section.
