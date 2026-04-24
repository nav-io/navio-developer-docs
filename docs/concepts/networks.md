# Networks

Navio runs on four networks, sharing code but with distinct genesis blocks, magic bytes, port numbers, and bech32 HRPs.

## Summary

| Network   | Flag                | Status          | Default P2P port | Default RPC port | Address HRP | Magic (hex)  |
| --------- | ------------------- | --------------- | ---------------- | ---------------- | ----------- | ------------ |
| mainnet   | (default)           | Live from block 10.5M transition | `48470`          | `48471`          | `nav`       | `bd5fc300`   |
| testnet   | `-testnet`          | Live — current SDK/explorer testnet | `33670`          | `33677`          | `tnav`      | `1c03bb83`   |
| signet    | `-signet`           | Optional        | `33671`          | `33678`          | `tnav`      | (per-signet) |
| regtest   | `-regtest`          | Local developer | `18444`          | `18443`          | `tnavrt`    | (regtest)    |

!!! warning "Port numbers"
    Mainnet uses `48470` (P2P) / `48471` (RPC) — distinct from Navcoin's ports to prevent cross-network misconfiguration. Always cross-check against `src/kernel/chainparams.cpp` (nDefaultPort) and `src/chainparamsbase.cpp` (RPC port) on the release you are running. On testnet, the SDK's P2P sync provider defaults to `43670` in its TypeScript defaults, while naviod uses `33670` — see the SDK [P2PSyncProvider](../sdk/sync.md#p2p-provider) config.

## Bootstrap nodes

Navio relies on DNS seeds and hardcoded bootstrap nodes. Testnet currently bootstraps from:

```
testnet.nav.io
testnet2.nav.io
```

Mainnet bootstrap DNS seeds are defined in `src/chainparams.cpp` in [navio-core](https://github.com/nav-io/navio-core/blob/master/src/chainparams.cpp). Always consult the current release.

Operators can override with `addnode=` lines in `navio.conf` or with `-addnode=<host>` on the command line.

## Address formats

Navio addresses are **bech32m** encoded double public keys. A typical testnet address looks like:

```
tnav1q9rh...long...q8u30w
```

where:

-   **HRP** — `nav` (mainnet), `tnav` (testnet + signet), `tnavrt` (regtest)
-   **Witness version** — hidden inside the bech32m payload
-   **Payload** — 96-byte encoded double public key

## Switching networks

### naviod

```bash
# testnet
naviod -testnet

# regtest
naviod -regtest

# signet
naviod -signet

# mainnet (default)
naviod
```

Most RPC methods work identically across networks. Consensus-parameter methods (`getblockchaininfo`, `getnetworkinfo`) report network-specific values.

### navio-cli

```bash
navio-cli -testnet getblockcount
navio-cli -regtest generatetoaddress 101 $(navio-cli -regtest getnewaddress)
```

### SDK

```ts
const client = new NavioClient({
    network: 'testnet', // or 'mainnet' | 'signet' | 'regtest'
    electrum: { host: 'localhost', port: 50005 },
    // ...
});
```

Network string is passed through to `navio-blsct` to set the active BLSCT chain context (affects address HRP, token-id padding, etc.).

## P2P wire protocol magic

Navio uses the inherited Bitcoin P2P wire protocol with distinct message-start bytes:

-   Testnet: `1c 03 bb 83`
-   Mainnet: `bd 5f c3 00`

The magic determines which messages a peer will accept. Explorer peer crawlers and custom P2P tooling must set the correct magic — see `P2P_MAINNET_MAGIC_HEX` / `P2P_TESTNET_MAGIC_HEX` in the [navio-blocks env vars](../explorer/self-host.md#environment-variables).

## Datadir layout

Default data directories:

-   Linux: `~/.navio/`
-   macOS: `~/Library/Application Support/Navio/`
-   Windows: `%APPDATA%\Navio\`

Testnet lives under `testnet5/`, signet under `signet/`, regtest under `regtest/`, mainnet at the datadir root. The current active testnet directory is `testnet5` — verify against your release.

## Choosing a network for development

| Goal                              | Recommended network |
| --------------------------------- | ------------------- |
| Unit/integration tests, CI        | `regtest`           |
| Pre-production manual testing     | `testnet`           |
| Low-noise private multi-party nets | `signet`            |
| Live transactions                 | `mainnet` (post-transition) |

See the [SDK quickstart](../sdk/quickstart.md) for the recommended regtest-based development loop.
