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
| Client version       | `0.1.0` (release) |
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
| `posLimit`                        | `0x00000000ffffffff…` |
| Max block size                    | 4 MB |
| BLSCT                             | Mandatory for transactions on this chain |

### Testnet

| Parameter                         | Value |
| --------------------------------- | ----- |
| Consensus                         | BLSCT + PoPS |
| `nLastPOWHeight`                  | 1000 |
| `nBLSCTFirstBlockReward`          | 75,000,000 NAV |
| `nBLSCTBlockReward`               | 4 NAV |
| `nPosTargetSpacing`               | 60 s |
| `nPosTargetTimespan`              | 1800 s |
| `nPePoSMinStakeAmount`            | 10,000 NAV |
| `fPoPSHardened`                   | `false` |
| `posLimit`                        | `0x0000ffffffffffff…` (easier) |

### Signet / Regtest / BLSCT Regtest

| Network      | Consensus        | Notes |
| ------------ | ---------------- | ----- |
| signet       | non-BLSCT signet | `fBLSCT = false`; `nDefaultPort = 38333` |
| regtest      | plain regtest    | `fBLSCT = false`; instant local mining |
| blsctregtest | BLSCT + PoPS     | `nPePoSMinStakeAmount = 100 NAV`, `nLastPOWHeight = 25000`, `nBLSCTBlockReward = 4 NAV`, `nPosTargetSpacing = 60 s` |

## BIP-like constants

| Constant                    | Value |
| --------------------------- | ----- |
| `MAX_BLOCK_SIZE` (BLSCT chains) | 4,000,000 bytes |
| `MAX_BLOCK_WEIGHT`          | 16,000,000 (after post-SegWit weighting) |
| `COIN`                      | 100,000,000 sats / NAV |
| `COINBASE_MATURITY`         | 100 blocks |

## Staking (PoPS)

Applies to the BLSCT / PoPS chains only: mainnet, testnet, and `blsctregtest`.

| Parameter                         | Value |
| --------------------------------- | ----- |
| Minimum stake (mainnet/testnet)   | 10,000 NAV |
| Minimum stake (`blsctregtest`)    | 100 NAV |
| Stake commitment set cap          | $N = 1024$ (`SetMemProofSetup::N`, padded to next power of two) |
| Minimum set size                  | 2 (smaller rejected by consensus to avoid de-anonymisation) |
| Coinstake marker                  | `vtx[1].vout[0]` is zero-value nonstandard |
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

## DNS seeds

| Network | Seed hostnames                                    |
| ------- | ------------------------------------------------- |
| testnet | `testnet.nav.io`, `testnet2.nav.io`                |
| mainnet | DNS seed `seed.nav.io`; fixed bootstrap seed `blocks.nav.io` (`168.119.249.67:48470`) |

## Default datadir paths

| OS      | Path                                                  |
| ------- | ----------------------------------------------------- |
| Linux   | `~/.navio/`                                           |
| macOS   | `~/Library/Application Support/Navio/`                |
| Windows | `%APPDATA%\Navio\`                                    |

Testnet under `testnet7/`, signet under `signet/`, regtest under `regtest/`, and BLSCT regtest under `blsctregtest/`.
