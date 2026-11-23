# Networks

Current `navio-core` exposes five chain types: `main`, `test`, `signet`, `regtest`, and `blsctregtest`. They share most of the codebase, but differ in genesis blocks, ports, message-start bytes, and whether BLSCT / PoPS is enabled.

## Summary

| Network      | Flag            | BLSCT active | Default P2P port | Default RPC port | BLSCT HRP | Magic (hex) |
| ------------ | --------------- | ------------ | ---------------- | ---------------- | --------- | ----------- |
| mainnet      | (default)       | yes          | `48470`          | `48471`          | `nav`     | `bd5fc300`  |
| testnet      | `-testnet`      | yes          | `33670`          | `33677`          | `tnv`     | `2467d2c1`  |
| signet       | `-signet -signetchallenge=<hex>` | yes (v0.3.0+) | `48488` (v0.3.0+) | `48487`          | `snv` (v0.3.0+) | first 4 bytes of the serialized challenge's sha256d |
| regtest      | `-regtest`      | no           | `18444`          | `48486`          | `rnv` in core chainparams, but BLSCT is inactive | `fdbf9ffb` |
| blsctregtest | `-blsctregtest` | yes          | `18444`          | `48484`          | `rnv`     | `fdbf9ffb` |

!!! warning "Port numbers"
    Mainnet uses `48470` (P2P) / `48471` (RPC) — distinct from Navcoin's ports to prevent cross-network misconfiguration. Always cross-check against `src/kernel/chainparams.cpp` (nDefaultPort) and `src/chainparamsbase.cpp` (RPC port) on the release you are running. On testnet, the SDK's P2P sync provider defaults to `43670` in its TypeScript defaults, while naviod uses `33670` — see the SDK [P2PSyncProvider](../sdk/sync.md#p2p-provider) config.

## Bootstrap nodes

Seeds are defined in [`src/kernel/chainparams.cpp`](https://github.com/nav-io/navio-core/blob/master/src/kernel/chainparams.cpp) (DNS seeds) and [`src/chainparamsseeds.h`](https://github.com/nav-io/navio-core/blob/master/src/chainparamsseeds.h) (fixed seeds).

| Network      | DNS seed      | Fixed seed                                   |
| ------------ | ------------- | -------------------------------------------- |
| mainnet      | `seed.nav.io` | `168.119.249.67:48470` (`blocks.nav.io`)     |
| testnet      | none          | none                                         |
| signet       | none (`-signetseednode`) | none                                |
| regtest / blsctregtest | none | none                                     |

Testnet and signet have **no built-in seeds**: earlier builds still carried Bitcoin's testnet3 and signet seed lists, which only led to Bitcoin peers, and v0.3.0 removes them. Connect testnet nodes explicitly, for example:

```ini
[test]
addnode=testnet.nav.io
addnode=testnet2.nav.io
```

Operators can always add peers with `addnode=` / `seednode=` / `connect=` in `navio.conf` or the equivalent command-line flags.

The Bitcoin-era checkpoint data and the `-checkpoints` option were also removed; setting `-checkpoints` now only logs a warning. Navio's **finality checkpoints** (`Consensus::Params::finalityCheckpoints`, empty on mainnet and testnet today) are unaffected and cannot be disabled.

## Address formats

On BLSCT-enabled chains, Navio addresses are **bech32m** encoded double public keys. A typical testnet address looks like:

```
tnv1q9rh...long...q8u30w
```

where:

-   **HRP** — `nav` (mainnet), `tnv` (testnet), `snv` (signet, v0.3.0+), `rnv` (`blsctregtest`)
-   **Witness version** — hidden inside the bech32m payload
-   **Payload** — 96-byte encoded double public key

`navio-blsct` used standalone takes the HRP from libblsct's `src/blsct/key_io.h`: `nav`, `tnv`, `snv` and `rnv` for its Mainnet, Testnet, Signet and Regtest chains. From v0.3.0 all four match `naviod`'s chainparams; before, `naviod`'s plain signet used `nav` and had BLSCT off.

## Signet {#signet}

!!! info "New in v0.3.0"
    In v0.2.2 and earlier, `-signet` used Bitcoin's signet challenge, genesis block and seeds with BLSCT disabled, so it could only follow Bitcoin's signet.

From v0.3.0, signet is a **BLSCT test network whose blocks must be signed** for the network's challenge script ([BIP 325](https://github.com/bitcoin/bips/blob/master/bip-0325.mediawiki)). Only the holders of the challenge keys can produce blocks, in the proof-of-work phase and in the proof-of-stake phase. It suits private multi-party test networks.

-   **No default network.** There is no public Navio signet yet, so `-signet` requires `-signetchallenge=<script hex>`; without it `naviod` refuses to start ("There is no default signet network yet: set -signetchallenge to the challenge of the signet to join."). The challenge also sets the network magic, so nodes with different challenges cannot talk to each other.
-   **Parameters.** Its own genesis block (shared by every signet; the challenge tells them apart), BLSCT and PoPS from genesis, proof-of-work blocks up to height 1000 and proof-of-stake after, 60-second PoS spacing, 4 NAV block reward, 10,000 NAV minimum stake, `snv` addresses, P2P port `48488`, RPC port `48487`, datadir `signet/`.
-   **Signing.** The block signature commits to the block's version, previous hash, transactions and time. Mine the PoW phase with `generatetoblsctaddress <n> <address> <maxtries> <signetkey>` and stake with `navio-staker -signet -signetblockkey=<key>`; both take the private key as 32 bytes of hex. Put the staker's key in its config file rather than on the command line.
-   **Peers.** Point the nodes at each other with `-addnode` or `-signetseednode`.
-   **Transparent RPCs.** Signet is a BLSCT-only network, so the transparent RPCs listed under [BLSCT-only networks](../rpc/index.md#blsct-only-networks) are refused.

```bash
naviod -signet -signetchallenge=0014<hash160 of the signing pubkey> -addnode=<peer>
navio-cli -signet generatetoblsctaddress 101 "$(navio-cli -signet getnewaddress)" 1000000 <key hex>
navio-staker -signet -signetblockkey=<key hex>
```

A proof of stake needs a set of at least two staked commitments, so lock at least two stakes before starting the staker. The full walkthrough is `contrib/signet/README.md` in navio-core.

## Switching networks

### naviod

```bash
# testnet
naviod -testnet

# blsct regtest
naviod -blsctregtest

# regtest
naviod -regtest

# signet (v0.3.0+: requires the network's challenge)
naviod -signet -signetchallenge=<challenge hex>

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

-   Testnet: `24 67 d2 c1`
-   Mainnet: `bd 5f c3 00`
-   Regtest / blsctregtest: `fd bf 9f fb`
-   Signet: the first 4 bytes of the double-SHA256 of the serialized challenge script (as in BIP 325)

The magic determines which messages a peer will accept. Explorer peer crawlers and custom P2P tooling must set the correct magic — see `P2P_MAINNET_MAGIC_HEX` / `P2P_TESTNET_MAGIC_HEX` in the [navio-blocks env vars](../explorer/self-host.md#environment-variables).

Navio's protocol extensions (service bits, `getdata` by output id, compact blocks for aggregated blocks, light-wallet `getoutkeys`, the WebSocket listener and BIP324 v2 transport) are described in [P2P protocol](p2p-protocol.md).

## Datadir layout

Default data directories:

-   Linux: `~/.navio/`
-   macOS: `~/Library/Application Support/Navio/`
-   Windows: `%APPDATA%\Navio\`

Mainnet lives at the datadir root. Subdirectories are currently `testnet7/`, `signet/`, `regtest/`, and `blsctregtest/`.

## Choosing a network for development

| Goal                               | Recommended network |
| ---------------------------------- | ------------------- |
| BLSCT integration tests, CI        | `blsctregtest`      |
| Plain non-BLSCT local tests        | `regtest`           |
| Pre-production manual testing      | `testnet`           |
| Low-noise private multi-party nets | `signet` (v0.3.0+: BLSCT, signed blocks) |
| Live transactions                  | `mainnet`           |

See the [SDK quickstart](../sdk/quickstart.md) for the SDK's current regtest-based development loop. For chain-faithful local BLSCT / PoPS testing in `navio-core`, prefer `blsctregtest`.
