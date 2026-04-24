# Network constants

Cross-reference table. Authoritative values live in [`src/chainparams.cpp`](https://github.com/nav-io/navio-core/blob/master/src/chainparams.cpp) and [`src/consensus/params.h`](https://github.com/nav-io/navio-core/blob/master/src/consensus/params.h) in navio-core — consult them for the release you target.

## Ports

| Network | P2P default | RPC default | ElectrumX TCP / SSL / WSS            |
| ------- | ----------- | ----------- | ------------------------------------ |
| mainnet | 48470       | 48471       | 50001 / 50002 / 50004                |
| testnet | 33670 (SDK P2P: 43670) | 33677 | 40001 / 40002 / 40004            |
| signet  | 33671       | 33678       | (per signet)                         |
| regtest | 18444       | 18443       | n/a                                  |

## P2P wire magic

| Network | Magic bytes (hex)  |
| ------- | ------------------ |
| mainnet | `bd 5f c3 00`      |
| testnet | `1c 03 bb 83`      |
| signet  | (per signet)       |
| regtest | `fa bf b5 da`      |

Override via `P2P_MESSAGE_MAGIC_HEX` in the [navio-blocks env](../explorer/self-host.md#environment-variables).

## Address HRPs (bech32m)

| Network | HRP      | Example                        |
| ------- | -------- | ------------------------------ |
| mainnet | `nav`    | `nav1q9rh…`                    |
| testnet | `tnav`   | `tnav1q9rh…`                   |
| signet  | `tnav`   | same as testnet                 |
| regtest | `tnavrt` | `tnavrt1q9rh…`                 |

## Denomination

-   1 NAV = **10 ⁸** satoshis = `100_000_000` sats.
-   Amounts in RPC are typically NAV (floating), in SDK `bigint` satoshis.

## Consensus parameters

Source: `src/kernel/chainparams.cpp`, `src/consensus/params.h`.

### Mainnet

| Parameter                         | Value                                                          |
| --------------------------------- | -------------------------------------------------------------- |
| Activation                        | Navcoin block height 10,500,000 (estimated end of June 2026)   |
| Initial supply                    | 81,743,678 NAV (migrated from Navcoin)                         |
| Max supply                        | **Uncapped** — no fixed ceiling                                 |
| Consensus                         | **PoPS** (Proof-of-Private-Stake)                              |
| `nBLSCTBlockReward`               | **8 NAV** (`2 * COIN * (nPosTargetSpacing / 30)`)              |
| `nPosTargetSpacing`               | **120 s** (1-minute blocks)                                     |
| `nPosTargetTimespan`              | 1800 s (retarget every 30 blocks)                              |
| `nPePoSMinStakeAmount`            | 10,000 NAV                                                     |
| `posLimit`                        | `0x00000000ffffffff…`                                           |
| Max block size                    | 4 MB                                                            |
| BLSCT                             | Mandatory for all transactions                                  |
| Community fund                    | Removed (legacy balance burned at genesis)                      |

### Testnet

| Parameter                         | Value                                  |
| --------------------------------- | -------------------------------------- |
| Consensus                         | PoPS from genesis                      |
| `nBLSCTBlockReward`               | 4 NAV                                  |
| `nPosTargetSpacing`               | 60 s                                   |
| `nPosTargetTimespan`              | 1800 s                                 |
| `nPePoSMinStakeAmount`            | 10,000 NAV                             |
| `posLimit`                        | `0x0000ffffffffffff…` (easier)         |
| Max supply                        | Uncapped                                |

### Signet / Regtest

| Parameter                         | Value                                  |
| --------------------------------- | -------------------------------------- |
| Consensus                         | PoPS                                   |
| `nPePoSMinStakeAmount` (regtest)  | **100 NAV**                            |
| `nPePoSMinStakeAmount` (signet)   | 10,000 NAV                             |
| Other params                      | Match testnet defaults                  |

## BIP-like constants

| Constant                    | Value                           |
| --------------------------- | ------------------------------- |
| `MAX_BLOCK_SIZE` (mainnet)  | 4,000,000 bytes                 |
| `MAX_BLOCK_WEIGHT`          | 16,000,000 (after post-SegWit weighting) |
| `COIN`                      | 100,000,000 sats / NAV          |
| `COINBASE_MATURITY`         | 100 blocks                      |
| `DEFAULT_RPC_PORT`          | 33677                           |
| `DEFAULT_P2P_PORT`          | 33670                           |

## Staking (PoPS)

| Parameter                         | Value                                                                  |
| --------------------------------- | ---------------------------------------------------------------------- |
| Minimum stake (mainnet/testnet/signet) | 10,000 NAV                                                       |
| Minimum stake (regtest)           | 100 NAV                                                                |
| Stake commitment set cap          | $N = 1024$ (`SetMemProofSetup::N`, padded to next power of two)         |
| Minimum set size                  | 2 (smaller rejected by consensus to avoid de-anonymisation)             |
| Coinstake marker                  | `vtx[1].vout[0]` is zero-value nonstandard                              |
| PoPS proof                        | set-membership (modified RingCT 3.0) + Bulletproofs++ range proof       |
| Entropy bindings                  | $\eta_{\text{FS}} = H(\text{prevHash} \Vert \text{prevStakeModifier})$; $\eta_\varphi = H(\text{prevHeight} \Vert \text{prevStakeModifier} \Vert \text{TX\_NO\_WITNESS(vtx)})$ |
| `MODIFIER_INTERVAL_RATIO`         | 3                                                                      |
| Kernel hash                       | $H(\text{prevTime} \Vert \text{stakeModifier} \Vert \text{time})$        |
| Minimum-value threshold           | $v_{\min} = \lfloor \text{KH} / T_{\text{pos}} \rfloor$                  |

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

## DNS seeds

| Network | Seed hostnames                                    |
| ------- | ------------------------------------------------- |
| testnet | `testnet.nav.io`, `testnet2.nav.io`                |
| mainnet | (defined in `chainparams.cpp`)                     |

## Default datadir paths

| OS      | Path                                                  |
| ------- | ----------------------------------------------------- |
| Linux   | `~/.navio/`                                           |
| macOS   | `~/Library/Application Support/Navio/`                |
| Windows | `%APPDATA%\Navio\`                                    |

Testnet under `testnet5/`, signet under `signet/`, regtest under `regtest/`.
