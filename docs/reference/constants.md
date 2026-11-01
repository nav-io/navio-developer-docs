# Network constants

Cross-reference table. Authoritative core values live in [`src/kernel/chainparams.cpp`](https://github.com/nav-io/navio-core/blob/master/src/kernel/chainparams.cpp), [`src/chainparamsbase.cpp`](https://github.com/nav-io/navio-core/blob/master/src/chainparamsbase.cpp), and [`src/consensus/params.h`](https://github.com/nav-io/navio-core/blob/master/src/consensus/params.h) in navio-core — consult them for the release you target.

## Ports

| Network      | P2P default              | RPC default | ElectrumX TCP / SSL / WSS |
| ------------ | ------------------------ | ----------- | ------------------------- |
| mainnet      | 48470                    | 48471       | 50001 / 50002 / 50004     |
| testnet      | 33670 (SDK P2P: 43670)  | 33677       | 40001 / 40002 / 40004     |
| signet       | 38333                    | 48487       | (per signet)              |
| regtest      | 18444                    | 48486       | n/a                       |
| blsctregtest | 18444                    | 48484       | n/a                       |

## P2P wire magic

| Network      | Magic bytes (hex) |
| ------------ | ----------------- |
| mainnet      | `bd 5f c3 00`     |
| testnet      | `24 67 d2 c1`     |
| signet       | (per signet)      |
| regtest      | `fd bf 9f fb`     |
| blsctregtest | `fd bf 9f fb`     |

Override via `P2P_MESSAGE_MAGIC_HEX` in the [navio-blocks env](../explorer/self-host.md#environment-variables).

## Address HRPs (bech32m)

Core `naviod` chainparams currently expose these BLSCT HRPs:

| Network      | Core HRP | Example        | Notes |
| ------------ | -------- | -------------- | ----- |
| mainnet      | `nav`    | `nav1q9rh…`    | BLSCT active |
| testnet      | `tnv`    | `tnv1q9rh…`    | BLSCT active |
| signet       | `nav`    | n/a            | Plain signet is not a BLSCT chain |
| regtest      | `rnv`    | n/a            | Plain regtest is not a BLSCT chain |
| blsctregtest | `rnv`    | `rnv1q9rh…`    | BLSCT-active local dev chain |

Standalone `navio-blsct` exposes different Signet / Regtest HRPs (`snv`, `rnav`) in `src/blsct/key_io.h`; see [BLSCT lib → network configuration](../blsct-lib/network.md).

## Denomination

-   1 NAV = **10 ⁸** satoshis = `100_000_000` sats.
-   Amounts in RPC are typically NAV (floating), in SDK `bigint` satoshis.

## Mainnet genesis (v0.1.0)

| Parameter            | Value |
| -------------------- | ----- |
| Genesis client       | `0.1.0` (first release; activated mainnet) |
| Latest release       | `0.2.2` (2026-09-27) |
| Genesis hash         | `0af3c23ae1ac4910693b7187ac61641d16d1cf49cba7acf8649d48e831d86b13` |
| Merkle root          | `96f8dfcc3c433012bc9d4b42e85fe543936609f87fce2cc9d5484383ee2f9aaf` |
| Genesis time         | `1782910800` (2026-07-01 13:00 UTC) |
| `nBits`              | `0x207fffff` |
| `nVersion`           | `0x40000000` |
| `nMinimumChainWork`  | `0` |
| `defaultAssumeValid` | `0` |

The genesis coinbase is a plain unspendable `OP_RETURN` (the genesis block is never connected).

## Consensus parameters

Source: `src/kernel/chainparams.cpp`, `src/consensus/params.h`.

### Mainnet

| Parameter                         | Value |
| --------------------------------- | ----- |
| Consensus                         | BLSCT + PoPS |
| `nLastPOWHeight`                  | 110 |
| `fOnlyFirstPoWBlockHasReward`     | `true` |
| `nBLSCTFirstBlockReward`          | 81,743,678 NAV |
| PoW subsidy at heights `2..110`   | 0 NAV |
| `nBLSCTBlockReward`               | 8 NAV |
| `nPosTargetSpacing`               | 120 s |
| `nPosTargetTimespan`              | 3600 s |
| `nPePoSMinStakeAmount`            | 10,000 NAV |
| `posLimit`                        | `0x0000ffffffffffff…` |
| Max block size                    | 4 MB |
| BLSCT                             | Mandatory for transactions on this chain |

Mainnet block reward is **8 NAV** — `2 * COIN * (nPosTargetSpacing / 30)` with a 120 s target spacing. (`blsctregtest`, with 60 s spacing, yields 4 NAV.)

Since navio-core **0.1.3** ([PR #303](https://github.com/nav-io/navio-core/pull/303)) mainnet ships a populated `chainTxData` (`nTime = 1783350480`, `nTxCount = 4018`, `dTxRate ≈ 0.0083`, sampled at height 3845) so the node can estimate sync progress.

### Testnet

| Parameter                         | Value |
| --------------------------------- | ----- |
| Consensus                         | BLSCT + PoPS |
| `nLastPOWHeight`                  | 1000 |
| `nBLSCTFirstBlockReward`          | 75,000,000 NAV |
| `nBLSCTBlockReward`               | 8 NAV (`2 * COIN * (nPosTargetSpacing / 30)`) |
| `nPosTargetSpacing`               | 120 s |
| `nPosTargetTimespan`              | 1800 s |
| `nPePoSMinStakeAmount`            | 10,000 NAV |
| `fPoPSHardened`                   | `true` |
| `nPoPSKernelV2Height`             | 22000 (mainnet / `blsctregtest`: 0) |
| `posLimit`                        | `0x0000ffffffffffff…` |

### Signet / Regtest / BLSCT Regtest

| Network      | Consensus        | Notes |
| ------------ | ---------------- | ----- |
| signet       | non-BLSCT signet | `fBLSCT = false`; `nDefaultPort = 38333` |
| regtest      | plain regtest    | `fBLSCT = false`; instant local mining |
| blsctregtest | BLSCT + PoPS     | `nPePoSMinStakeAmount = 100 NAV`, `nLastPOWHeight = 25000`, `nBLSCTBlockReward = 4 NAV`, `nPosTargetSpacing = 60 s` |

## BIP-like constants

| Constant                    | Value |
| --------------------------- | ----- |
| `MAX_BLOCK_SERIALIZED_SIZE` | 4,000,000 bytes |
| `MAX_BLOCK_WEIGHT`          | 4,000,000 |
| `COIN`                      | 100,000,000 sats / NAV |
| `COINBASE_MATURITY`         | 100 blocks |

## Staking (PoPS)

Applies to the BLSCT / PoPS chains only: mainnet, testnet, and `blsctregtest`.

| Parameter                         | Value |
| --------------------------------- | ----- |
| Minimum stake (mainnet/testnet)   | 10,000 NAV |
| Minimum stake (`blsctregtest`)    | 100 NAV |
| Stake commitment set cap          | $N = 1024$ (`SetMemProofSetup::N`, padded to next power of two) |
| Sampled ring size                 | 16 (`nStakedCommitmentLimit`, all BLSCT chains) |
| Minimum set size                  | 2 (smaller rejected by consensus to avoid de-anonymisation) |
| PoPS proof                        | set-membership (modified RingCT 3.0) + Bulletproofs++ range proof |
| Entropy bindings                  | $\eta_{\text{FS}} = H(\text{prevHash} \Vert \text{prevStakeModifier})$; $\eta_\varphi = H(\text{prevHeight} \Vert \text{prevStakeModifier} \Vert \text{TX\_NO\_WITNESS(vtx)})$ |
| `MODIFIER_INTERVAL_RATIO`         | 3 |
| Kernel hash                       | $H(\text{prevTime} \Vert \text{stakeModifier} \Vert \text{time})$ |
| Minimum-value threshold           | $v_{\min} = \lfloor \text{KH} / T_{\text{pos}} \rfloor$ |

## Curve & cryptographic

| Parameter                 | Value                                        |
| ------------------------- | -------------------------------------------- |
| Curve                     | BLS12-381                                    |
| Scalar field prime $r$    | ~255 bits                                    |
| Base field prime $p$      | ~381 bits                                    |
| Embedding degree          | 12                                           |
| `G_1` point (compressed)  | 48 bytes                                     |
| `G_2` point (compressed)  | 96 bytes                                     |
| Scalar serialisation       | 32 bytes, little-endian                      |
| Range proof width         | 64 bits (amounts in $[0, 2^{64})$)            |
| Audit key length          | 80 bytes (160 hex chars)                     |
| Double public key length  | 96 bytes                                     |

## Encryption

| Parameter                           | Value                       |
| ----------------------------------- | --------------------------- |
| KDF                                 | Argon2id                    |
| Argon2id memory                     | 64 MiB                      |
| Argon2id iterations                 | 3                           |
| Argon2id parallelism                | 4                           |
| Salt                                | 16 bytes                    |
| Encryption                          | AES-256-GCM                 |
| IV                                  | 12 bytes, random per encryption |

## Seeds

| Network | Seed hostnames                                    |
| ------- | ------------------------------------------------- |
| testnet | none built in; connect with `addnode=testnet.nav.io` / `testnet2.nav.io` |
| signet  | none (custom signets: `-signetseednode`)           |
| mainnet | DNS seed `seed.nav.io`; fixed bootstrap seed `blocks.nav.io` (`168.119.249.67:48470`) |

## Default datadir paths

| OS      | Path                                                  |
| ------- | ----------------------------------------------------- |
| Linux   | `~/.navio/`                                           |
| macOS   | `~/Library/Application Support/Navio/`                |
| Windows | `%APPDATA%\Navio\`                                    |

Testnet under `testnet7/`, signet under `signet/`, regtest under `regtest/`, and BLSCT regtest under `blsctregtest/`.

## P2P service bits

Navio-specific bits use the experiment range (24–31). See [P2P protocol → Service bits](../concepts/p2p-protocol.md#service-bits).

| Bit | Flag                  | Enabled by |
| --- | --------------------- | ---------- |
| 11  | `NODE_P2P_V2`         | `-v2transport=1` (default off) |
| 24  | `NODE_P2PMSG`         | not advertised (envelope v1) |
| 25  | `NODE_P2PMSG_LEAF`    | light clients |
| 26  | `NODE_P2PMSG_ARCHIVE` | `-p2pmsgarchive=1` |
| 27  | `NODE_P2PMSG_V2`      | `-p2pmsg=1` (default on) |
| 28  | `NODE_OUTKEYS`        | `-peeroutkeys=1` |
| 30  | `NODE_P2P_WS`         | usable `-p2pwsbind` listener |

## P2P protocol constants

| Constant | Value |
| -------- | ----- |
| `MSG_OUTPUT_HASH` inventory type | 8 |
| `MSG_DTX` / `MSG_DWTX` (Dandelion++) | 6 / 7 |
| Compact blocks for aggregated blocks | `sendcmpct` version 3 (`CMPCTBLOCKS_AGGREGATE_VERSION`); BIP152 stays version 2 |
| Remembered aggregate component lists | 16 blocks |
| `getoutkeys` max range (`MAX_GETOUTKEYS_SIZE`) | 1000 blocks |
| `outkeys` reply cap (`-outkeysmaxbytes`) | 4,000,000 bytes (first block always sent) |
| `wsendpoint` URL max | 256 bytes |
| WebSocket upgrade request / frame payload max | 8 KiB / 4 MiB |

## p2pmsg constants

| Constant | Value |
| -------- | ----- |
| Envelope version | 2 |
| Default PoW (`DEFAULT_POW_BITS`) | 23 leading zero bits |
| PoW timestamp window | ±120 s |
| Detection flag size | 83 bytes (FMD2, γ = 24; clue key 1152 bytes) |
| Max user message (topic + body, `MAX_USER_MSG_BYTES`) | 3584 bytes |
| User store default / split | 64 MiB; inbox 40 % / session 40 % / broadcast 20 % |
| User store expiry | 30 days |
| Archive default size / expiry | 4096 MiB / 14 days |
| Archive response caps | 500 entries, 50,000 scanned, 2 MiB |
| Cover pool target / max / max per aggregate | 20 / 512 / 16 candidates |
| Cover ratio (`COVER_INPUT_RATIO`) | 1 cover per 4 own inputs |
| Candidate pull interval | 60 s |
