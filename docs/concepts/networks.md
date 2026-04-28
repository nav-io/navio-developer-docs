# Networks

Current `navio-core` exposes five chain types: `main`, `test`, `signet`, `regtest`, and `blsctregtest`. They share most of the codebase, but differ in genesis blocks, ports, message-start bytes, and whether BLSCT / PoPS is enabled.

## Summary

| Network      | Flag            | BLSCT active | Default P2P port | Default RPC port | BLSCT HRP | Magic (hex) |
| ------------ | --------------- | ------------ | ---------------- | ---------------- | --------- | ----------- |
| mainnet      | (default)       | yes          | `48470`          | `48471`          | `nav`     | `bd5fc300`  |
| testnet      | `-testnet`      | yes          | `33670`          | `33677`          | `tnv`     | `1c03bb83`  |
| signet       | `-signet`       | no           | `38333`          | `48487`          | `nav` in core chainparams, but BLSCT is inactive | (per-signet) |
| regtest      | `-regtest`      | no           | `18444`          | `48486`          | `rnv` in core chainparams, but BLSCT is inactive | `fdbf9ffb` |
| blsctregtest | `-blsctregtest` | yes          | `18444`          | `48484`          | `rnv`     | `fdbf9ffb` |

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

On BLSCT-enabled chains, Navio addresses are **bech32m** encoded double public keys. A typical testnet address looks like:

```
tnv1q9rh...long...q8u30w
```

where:

-   **HRP** — `nav` (mainnet), `tnv` (testnet), `rnv` (`blsctregtest`)
-   **Witness version** — hidden inside the bech32m payload
-   **Payload** — 96-byte encoded double public key

If you use `navio-blsct` standalone instead of `naviod` chainparams, the library currently exposes `snv` and `rnav` for its Signet / Regtest enum values in `src/blsct/key_io.h`.

## Switching networks

### naviod

```bash
# testnet
naviod -testnet

# blsct regtest
naviod -blsctregtest

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
navio-cli -blsctregtest generatetoaddress 101 $(navio-cli -blsctregtest getnewaddress)
```

### SDK

```ts
const client = new NavioClient({
    network: 'testnet', // or 'mainnet' | 'signet' | 'regtest'
    electrum: { host: 'localhost', port: 50005 },
    // ...
});
```

For SDK and library usage, the network string is passed through to `navio-blsct` to set the active BLSCT chain context (affects address HRP, token-id padding, etc.).

## P2P wire protocol magic

Navio uses the inherited Bitcoin P2P wire protocol with distinct message-start bytes:

-   Testnet: `1c 03 bb 83`
-   Mainnet: `bd 5f c3 00`
-   Regtest / blsctregtest: `fd bf 9f fb`

The magic determines which messages a peer will accept. Explorer peer crawlers and custom P2P tooling must set the correct magic — see `P2P_MAINNET_MAGIC_HEX` / `P2P_TESTNET_MAGIC_HEX` in the [navio-blocks env vars](../explorer/self-host.md#environment-variables).

## Datadir layout

Default data directories:

-   Linux: `~/.navio/`
-   macOS: `~/Library/Application Support/Navio/`
-   Windows: `%APPDATA%\Navio\`

Mainnet lives at the datadir root. Subdirectories are currently `testnet6/`, `signet/`, `regtest/`, and `blsctregtest/`.

## Choosing a network for development

| Goal                               | Recommended network |
| ---------------------------------- | ------------------- |
| BLSCT integration tests, CI        | `blsctregtest`      |
| Plain non-BLSCT local tests        | `regtest`           |
| Pre-production manual testing      | `testnet`           |
| Low-noise private multi-party nets | `signet`            |
| Live transactions                  | `mainnet`           |

See the [SDK quickstart](../sdk/quickstart.md) for the SDK's current regtest-based development loop. For chain-faithful local BLSCT / PoPS testing in `navio-core`, prefer `blsctregtest`.
